#' Calculate REMIND variables from European Energy Datasheets
#'
#' @md
#' @return A [`magpie`][magclass::magclass] object.
#' @param subtype data subtype. Either "EU28" (data from June 20 including GBR)
#' or "EU27" (latest data from August 23 without GBR)
#' @author Falk Benke
#'
#' @importFrom dplyr select mutate left_join
#'
calcEuropeanEnergyDatasheets <- function(subtype) {
  if (!subtype %in% c("EU27", "EU28")) {
    stop("Invalid subtype. Must be either EU27 or EU28")
  }

  if (subtype == "EU27") {
    data <- readSource("EuropeanEnergyDatasheets", subtype = "EU27")

    data <- as.data.frame(data) %>%
      as_tibble() %>%
      select(
        "region" = "Region", "variable" = "Data1",
        "year" = "Year", "value" = "Value"
      )

    mapping <- toolGetMapping("Mapping_EuropeanEnergyDatasheets.csv", type = "reportingVariables",
                              where = "mrremind") %>%
      filter(!is.na(!!sym("REMIND")), !!sym("REMIND") != "") %>%
      mutate("Conversion" = as.numeric(.data$Conversion)) %>%
      select("variable" = "EED", "REMIND", "Conversion")

    mapping$variable <- trimws(mapping$variable)
    mapping$REMIND <- trimws(mapping$REMIND)

    x <- left_join(data, mapping, by = "variable", relationship = "many-to-many") %>%
      filter(.data$REMIND != "") %>%
      mutate("value" = .data$value * .data$Conversion) %>%
      select("region", "year", "variable" = "REMIND", "value")

    x <- stats::aggregate(value ~ region + year + variable, x, sum, na.action = stats::na.exclude) %>%
      as.magpie() %>%
      toolCountryFill(fill = NA, verbosity = 2)

    # get GBR data from older versions of the source, as it is no longer updated
    eurostat.gbr <- readSource("EuropeanEnergyDatasheets", subtype = "EU28")["GBR", , ]
    commonVars <- intersect(getNames(eurostat.gbr), getNames(x))
    x["GBR", getItems(eurostat.gbr, dim = 2), commonVars] <- eurostat.gbr[, , commonVars]

    x <- add_columns(x, "Emi|CO2|Industry (Mt CO2/yr)", dim = 3.1)
    x[, , "Emi|CO2|Industry (Mt CO2/yr)"] <-
      x[, , "Emi|CO2|Industrial Processes (Mt CO2/yr)"] +
      x[, , "Emi|CO2|Energy|Demand|Industry (Mt CO2/yr)"]

    x <- add_columns(x, "Emi|GHG|Industry (Mt CO2eq/yr)", dim = 3.1)
    x[, , "Emi|GHG|Industry (Mt CO2eq/yr)"] <-
      x[, , "Emi|GHG|Industrial Processes (Mt CO2eq/yr)"] +
      x[, , "Emi|GHG|Energy|Demand|Industry (Mt CO2eq/yr)"]
  } else {
    x <- readSource("EuropeanEnergyDatasheets", subtype = "EU28")
  }
  return(list(
    x = x,
    weight = NULL,
    unit = c("EJ/yr", "Mt CO2/yr", "Mt CO2eq/yr", "GW", "million"),
    description = "European Energy Datasheets data in REMIND variables"
  ))
}
