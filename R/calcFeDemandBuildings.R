#' Returns the EDGE-Buildings data as REMIND variables
#'
#' @param subtype either "FE", "FE_buildings", or "UE_buildings"
#' @param scenario A string (or vector of strings) designating the scenario(s) to be returned.
#'
#' @author Robin Hasse
#'
#' @importFrom dplyr filter mutate distinct select

calcFeDemandBuildings <- function(subtype, scenario) {

  # end of history
  eoh <- 2025

  if (!subtype %in% c("FE", "FE_buildings", "UE_buildings")) {
    stop(paste0("Unsupported subtype: ", subtype))
  }

  ## Replace any calls to scenario groups such as "SSPs" and "SSP2IndiaDEAs", to calls of the individual scenarios.
  scenario <- mrdrivers::toolReplaceShortcuts(scenario) %>% unique()

  # Data Processing ----
  ononspec <- calcOutput("FeDemandONONSPEC", scenario = scenario, eoh = eoh,
                         aggregate = FALSE)
  buildings  <- readSource("EdgeBuildings", subtype = "FE", subset = scenario)

  # Aggregate to 5-year averages to suppress volatility
  buildings <- toolAggregateTimeSteps(buildings)
  ononspec <- toolAggregateTimeSteps(ononspec)

  if (subtype == "FE") {
    # Drop RCP dimension (use fixed RCP)
    buildings <- mselect(buildings, rcp = "none") %>% collapseDim(dim = "rcp")

  } else {
    # For each scenario add the rcp scenarios present in buildings to stationary
    ononspec <- do.call(mbind, lapply(scenario, function(scen) {
      rcps <- getItems(mselect(buildings, scenario = scen), dim = "rcp")
      toolAddDimensions(mselect(ononspec, scenario = scen), dimVals = rcps, dimName = "rcp", dimCode = 3.2)
    }))
  }

  # Extrapolate years missing in buildings, but existing in stationary
  buildings <- time_interpolate(buildings,
                                interpolated_year = getYears(ononspec),
                                extrapolation_type = "constant")

  data <- mbind(ononspec, buildings)

  # Prepare Mapping
  mapping <- toolGetMapping(type = "sectoral", name = "structuremappingIO_outputs.csv", where = "mrcommons")

  # TODO: remove once this is in the mapping
  ## Add total buildings electricity demand: feelb = feelcb + feelhpb + feelrhb
  mapping <- rbind(
    mapping,
    mapping %>%
      filter(.data$REMINDitems_out %in% c("feelcb", "feelhpb", "feelrhb")) %>%
      mutate(REMINDitems_out = "feelb")
  )

  mapping <- mapping %>%
    select("EDGEitems", "REMINDitems_out", "weight_Fedemand") %>%
    stats::na.omit() %>%
    filter(.data$EDGEitems %in% getNames(data, dim = "item")) %>%
    distinct()

  if (length(setdiff(getNames(data, dim = "item"), mapping$EDGEitems) > 0)) {
    stop("Not all EDGE items are in the mapping")
  }

  if (subtype == "FE") {

    # REMIND variables in focus: those ending with b and stationary items not in industry focus
    mapping <- mapping %>%
      filter(grepl("b$", .data$REMINDitems_out) |
               (grepl("s$", .data$REMINDitems_out)) & !grepl("fe(..i$|ind)", .data$EDGEitems))
    remindVars <- unique(mapping$REMINDitems_out)
    remindDims <- quitte::cartesian(getNames(data, dim = "scenario"), remindVars)

  } else {

    remindVars <- filter(mapping, grepl("^fe..b$|^feel..b$|^feelcb$", .data$REMINDitems_out))
    remindVars <- unique(remindVars$REMINDitems_out)

    # Extend mapping for Useful Energy
    if (subtype == "UE_buildings") {
      mapping <- mapping %>%
        mutate(EDGEitems = gsub("_fe$", "_ue", .data[["EDGEitems"]]),
               REMINDitems_out = gsub("^fe", "ue", .data[["REMINDitems_out"]])) %>%
        rbind(mapping)
      remindVars <- gsub("^fe", "ue", remindVars)
    }

    scenarioRcp <- unique(gsub("^(.*\\..*)\\..*$", "\\1", getItems(data, dim = 3)))
    remindDims <- quitte::cartesian(scenarioRcp, remindVars)
  }

  # Apply Mapping
  remind <- new.magpie(cells_and_regions = getItems(data, dim = 1),
                       years = getYears(data),
                       names = remindDims,
                       sets = getSets(data))

  for (v in remindVars) {
    w <- mapping %>%
      filter(.data$REMINDitems_out == v) %>%
      select(-"REMINDitems_out") %>%
      as.magpie()

    tmp <- mselect(data, item = getNames(w)) * w

    tmp <- dimSums(tmp, dim = "item", na.rm = TRUE) %>%
      add_dimension(dim = 3.3, add = "item", nm = v)

    remind[, , getNames(tmp)] <- tmp
  }

  # Prepare Output
  ## Change item names back from UE to FE
  if (subtype == "UE_buildings") {
    getItems(remind, "item") <- gsub("^ue", "fe", getItems(remind, "item"))
  }

  description <- switch(subtype,
    FE = "final energy demand in buildings and industry (stationary)",
    FE_buildings = "final energy demand in buildings",
    UE_buildings = "useful energy demand in buildings"
  )

  outputStructure <- switch(subtype,
    FE = "^(SSP[1-5].*|SDP.*)\\.(fe|ue)",
    FE_buildings = "^(SSP[1-5]|SDP).*\\..*\\.fe.*b$",
    UE_buildings = "^(SSP[1-5]|SDP).*\\..*\\.fe.*b$"
  )

  list(x = remind,
       weight = NULL,
       unit = "EJ",
       description = description,
       structure.data = outputStructure)
}
