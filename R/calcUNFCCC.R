#' Calculate REMIND emission variables from historical UNFCCC values
#'
#' @md
#' @return A [`magpie`][magclass::magclass] object.
#'
#' @author Falk Benke, Pascal Weigmann
#' @importFrom dplyr select mutate left_join
#' @export
calcUNFCCC <- function() {

  data <- readSource("UNFCCC")

  mapping <- toolGetMapping("Mapping_UNFCCC.csv", type = "reportingVariables", where = "mrremind") %>%
    mutate("conversion" = as.numeric(.data$Factor) * .data$Weight) %>%
    select("variable" = "UNFCCC", "REMIND", "conversion", "unit" = "Unit_UNFCCC", "Unit_REMIND")

  mapping$variable <- gsub(pattern = "\\.", replacement = "_", mapping$variable) %>% trimws()
  mapping$REMIND <- trimws(mapping$REMIND)

  x <- left_join(
    data %>%
      mselect(variable = unique(mapping$variable)) %>%
      as.data.frame() %>%
      as_tibble() %>%
      select(
        "region" = "Region", "variable" = "Data1", "unit" = "Data2",
        "year" = "Year", "value" = "Value"
      ),
    mapping,
    by = "variable",
    relationship = "many-to-many"
  ) %>%
    filter(.data$REMIND != "") %>%
    mutate(
      "value" = .data$value * .data$conversion,
      "REMIND" = paste0(.data$REMIND, " (", .data$Unit_REMIND, ")")
    ) %>%
    select("variable" = "REMIND", "region", "year", "value")

  x <- stats::aggregate(value ~ variable + region + year, x, sum) %>%
    as.magpie() %>%
    toolCountryFill(fill = NA, verbosity = 2)

  # aggregate pollutants ----

  x <- add_columns(x, "Emi|CH4 (Mt CH4/yr)", dim = 3.1)
  x[, , "Emi|CH4 (Mt CH4/yr)"] <- dimSums(
    x[, , c(
      "Emi|CH4|Agriculture (Mt CH4/yr)",
      "Emi|CH4|Energy (Mt CH4/yr)",
      "Emi|CH4|Industrial Processes (Mt CH4/yr)",
      "Emi|CH4|Land-Use Change (Mt CH4/yr)",
      "Emi|CH4|Waste (Mt CH4/yr)"
    )],
    dim = 3, na.rm = TRUE
  )

  x <- add_columns(x, "Emi|CO2 (Mt CO2/yr)", dim = 3.1)
  x[, , "Emi|CO2 (Mt CO2/yr)"] <- dimSums(
    x[, , c(
      "Emi|CO2|Agriculture (Mt CO2/yr)",
      "Emi|CO2|Energy (Mt CO2/yr)",
      "Emi|CO2|Industrial Processes (Mt CO2/yr)",
      "Emi|CO2|Land-Use Change (Mt CO2/yr)",
      "Emi|CO2|Waste (Mt CO2/yr)"
    )],
    dim = 3, na.rm = TRUE
  )

  x <- add_columns(x, "Emi|N2O (kt N2O/yr)", dim = 3.1)
  x[, , "Emi|N2O (kt N2O/yr)"] <- dimSums(
    x[, , c(
      "Emi|N2O|Agriculture (kt N2O/yr)",
      "Emi|N2O|Energy (kt N2O/yr)",
      "Emi|N2O|Industrial Processes (kt N2O/yr)",
      "Emi|N2O|Land-Use Change (kt N2O/yr)",
      "Emi|N2O|Waste (kt N2O/yr)"
    )],
    dim = 3, na.rm = TRUE
  )

  # add total GHG as CO2 equivalents for sectors ----

  x <- add_columns(x, "Emi|GHG|Energy (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Energy (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2|Energy (Mt CO2/yr)"] +
    x[, , "Emi|CH4|Energy (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O|Energy (kt N2O/yr)"] / 1000 * 265

  x <- add_columns(x, "Emi|GHG|Industrial Processes (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Industrial Processes (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2|Industrial Processes (Mt CO2/yr)"] +
    x[, , "Emi|CH4|Industrial Processes (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O|Industrial Processes (kt N2O/yr)"] / 1000 * 265

  x <- add_columns(x, "Emi|GHG|Agriculture (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Agriculture (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2|Agriculture (Mt CO2/yr)"] +
    x[, , "Emi|CH4|Agriculture (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O|Agriculture (kt N2O/yr)"] / 1000 * 265

  x <- add_columns(x, "Emi|GHG|Land-Use Change (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Land-Use Change (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2|Land-Use Change (Mt CO2/yr)"] +
    x[, , "Emi|CH4|Land-Use Change (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O|Land-Use Change (kt N2O/yr)"] / 1000 * 265

  x <- add_columns(x, "Emi|GHG|Waste (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Waste (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2|Waste (Mt CO2/yr)"] +
    x[, , "Emi|CH4|Waste (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O|Waste (kt N2O/yr)"] / 1000 * 265

  # GHG total
  x <- add_columns(x, "Emi|GHG (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2 (Mt CO2/yr)"] +
    x[, , "Emi|CH4 (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O (kt N2O/yr)"] / 1000 * 265

  # additional CO2 variables ----

  x <- add_columns(x, "Emi|CO2|w/ Bunkers (Mt CO2/yr)", dim = 3.1)
  x[, , "Emi|CO2|w/ Bunkers (Mt CO2/yr)"] <-
    x[, , "Emi|CO2 (Mt CO2/yr)"] +
    x[, , "Emi|CO2|Energy|Demand|Transport|International Bunkers (Mt CO2/yr)"]

  x <- add_columns(x, "Emi|CO2|w/ Bunkers|Energy (Mt CO2/yr)", dim = 3.1)
  x[, , "Emi|CO2|w/ Bunkers|Energy (Mt CO2/yr)"] <-
    x[, , "Emi|CO2|Energy (Mt CO2/yr)"] +
    x[, , "Emi|CO2|Energy|Demand|Transport|International Bunkers (Mt CO2/yr)"]

  x <- add_columns(x, "Emi|CO2|Energy and Industrial Processes (Mt CO2/yr)", dim = 3.1)
  x[, , "Emi|CO2|Energy and Industrial Processes (Mt CO2/yr)"] <-
    x[, , "Emi|CO2|Energy (Mt CO2/yr)"] +
    x[, , "Emi|CO2|Industrial Processes (Mt CO2/yr)"]

  x <- add_columns(x, "Emi|CO2|w/ Bunkers|Energy and Industrial Processes (Mt CO2/yr)", dim = 3.1)
  x[, , "Emi|CO2|w/ Bunkers|Energy and Industrial Processes (Mt CO2/yr)"] <-
    x[, , "Emi|CO2|Energy and Industrial Processes (Mt CO2/yr)"] +
    x[, , "Emi|CO2|Energy|Demand|Transport|International Bunkers (Mt CO2/yr)"]

  x <- add_columns(x, "Emi|CO2|Energy|Demand (Mt CO2/yr)", dim = 3.1)
  x[, , "Emi|CO2|Energy|Demand (Mt CO2/yr)"] <-
    x[, , "Emi|CO2|Energy|Demand|Industry (Mt CO2/yr)"] +
    x[, , "Emi|CO2|Energy|Demand|Transport (Mt CO2/yr)"] +
    x[, , "Emi|CO2|Energy|Demand|Buildings (Mt CO2/yr)"]

  x <- add_columns(x, "Emi|CO2|w/ Bunkers|Energy|Demand (Mt CO2/yr)", dim = 3.1)
  x[, , "Emi|CO2|w/ Bunkers|Energy|Demand (Mt CO2/yr)"] <-
    x[, , "Emi|CO2|Energy|Demand (Mt CO2/yr)"] +
    x[, , "Emi|CO2|Energy|Demand|Transport|International Bunkers (Mt CO2/yr)"]

  x <- add_columns(x, "Emi|CO2|w/ Bunkers|Energy|Demand|Transport (Mt CO2/yr)", dim = 3.1)
  x[, , "Emi|CO2|w/ Bunkers|Energy|Demand|Transport (Mt CO2/yr)"] <-
    x[, , "Emi|CO2|Energy|Demand|Transport (Mt CO2/yr)"] +
    x[, , "Emi|CO2|Energy|Demand|Transport|International Bunkers (Mt CO2/yr)"]

  # additional GHG variables ----

  x <- add_columns(x, "Emi|GHG|Energy|Demand|Transport|International Bunkers (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Energy|Demand|Transport|International Bunkers (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2|Energy|Demand|Transport|International Bunkers (Mt CO2/yr)"] +
    x[, , "Emi|CH4|Energy|Demand|Transport|International Bunkers (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O|Energy|Demand|Transport|International Bunkers (kt N2O/yr)"] / 1000 * 265


  x <- add_columns(x, "Emi|GHG|w/ Bunkers (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|w/ Bunkers (Mt CO2eq/yr)"] <-
    x[, , "Emi|GHG (Mt CO2eq/yr)"] +
    x[, , "Emi|GHG|Energy|Demand|Transport|International Bunkers (Mt CO2eq/yr)"]


  x <- add_columns(x, "Emi|GHG|w/ Bunkers|Energy (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|w/ Bunkers|Energy (Mt CO2eq/yr)"] <-
    x[, , "Emi|GHG|Energy (Mt CO2eq/yr)"] +
    x[, , "Emi|GHG|Energy|Demand|Transport|International Bunkers (Mt CO2eq/yr)"]

  x <- add_columns(x, "Emi|GHG|Energy and Industrial Processes (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Energy and Industrial Processes (Mt CO2eq/yr)"] <-
    x[, , "Emi|GHG|Energy (Mt CO2eq/yr)"] +
    x[, , "Emi|GHG|Industrial Processes (Mt CO2eq/yr)"]

  x <- add_columns(x, "Emi|GHG|w/ Bunkers|Energy and Industrial Processes (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|w/ Bunkers|Energy and Industrial Processes (Mt CO2eq/yr)"] <-
    x[, , "Emi|GHG|Energy and Industrial Processes (Mt CO2eq/yr)"] +
    x[, , "Emi|GHG|Energy|Demand|Transport|International Bunkers (Mt CO2eq/yr)"]

  x <- add_columns(x, "Emi|GHG|Energy|Demand|Industry (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Energy|Demand|Industry (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2|Energy|Demand|Industry (Mt CO2/yr)"] +
    x[, , "Emi|CH4|Energy|Demand|Industry (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O|Energy|Demand|Industry (kt N2O/yr)"] / 1000 * 265


  x <- add_columns(x, "Emi|GHG|Energy|Demand|Transport (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Energy|Demand|Transport (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2|Energy|Demand|Transport (Mt CO2/yr)"] +
    x[, , "Emi|CH4|Energy|Demand|Transport (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O|Energy|Demand|Transport (kt N2O/yr)"] / 1000 * 265

  x <- add_columns(x, "Emi|GHG|Energy|Demand|Buildings (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Energy|Demand|Buildings (Mt CO2eq/yr)"] <-
    x[, , "Emi|CO2|Energy|Demand|Buildings (Mt CO2/yr)"] +
    x[, , "Emi|CH4|Energy|Demand|Buildings (Mt CH4/yr)"] * 28 +
    x[, , "Emi|N2O|Energy|Demand|Buildings (kt N2O/yr)"] / 1000 * 265

  x <- add_columns(x, "Emi|GHG|Energy|Demand (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Energy|Demand (Mt CO2eq/yr)"] <-
    x[, , "Emi|GHG|Energy|Demand|Industry (Mt CO2eq/yr)"] +
    x[, , "Emi|GHG|Energy|Demand|Transport (Mt CO2eq/yr)"] +
    x[, , "Emi|GHG|Energy|Demand|Buildings (Mt CO2eq/yr)"]

  x <- add_columns(x, "Emi|GHG|w/ Bunkers|Energy|Demand (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|w/ Bunkers|Energy|Demand (Mt CO2eq/yr)"] <-
    x[, , "Emi|GHG|Energy|Demand (Mt CO2eq/yr)"] +
    x[, , "Emi|GHG|Energy|Demand|Transport|International Bunkers (Mt CO2eq/yr)"]

  x <- add_columns(x, "Emi|GHG|w/ Bunkers|Energy|Demand|Transport (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|w/ Bunkers|Energy|Demand|Transport (Mt CO2eq/yr)"] <-
    x[, , "Emi|GHG|Energy|Demand|Transport (Mt CO2eq/yr)"] +
    x[, , "Emi|GHG|Energy|Demand|Transport|International Bunkers (Mt CO2eq/yr)"]

  x <- add_columns(x, "Emi|CO2|Industry (Mt CO2/yr)", dim = 3.1)
  x[, , "Emi|CO2|Industry (Mt CO2/yr)"] <-
    x[, , "Emi|CO2|Industrial Processes (Mt CO2/yr)"] +
    x[, , "Emi|CO2|Energy|Demand|Industry (Mt CO2/yr)"]

  x <- add_columns(x, "Emi|GHG|Industry (Mt CO2eq/yr)", dim = 3.1)
  x[, , "Emi|GHG|Industry (Mt CO2eq/yr)"] <-
    x[, , "Emi|GHG|Industrial Processes (Mt CO2eq/yr)"] +
    x[, , "Emi|GHG|Energy|Demand|Industry (Mt CO2eq/yr)"]

  # return results ----

  # fill countries of selected regions with 0 to allow for regional aggregation
  regions.fill <- c("EUR", "REF", "NEU", "CAZ")
  mapping <- toolGetMapping("regionmappingH12.csv", type = "regional", where = "mappingfolder") %>%
    filter(.data$RegionCode %in% regions.fill)

  tmp <- x[unique(mapping$CountryCode), , ]
  tmp[is.na(tmp)] <- 0
  x[unique(mapping$CountryCode), , ] <- tmp

  # remove years before 1990 due to incomplete data
  x <- x[, seq(1986, 1989, 1), , invert = TRUE]
  x <- add_dimension(x, dim = 3.1, add = "model", nm = "UNFCCC")

  return(list(
    x = x, weight = NULL,
    unit = c("Mt CO2", "Mt CH4", "kt N2O", "Mt CO2eq"),
    description = "Historical UNFCCC values as REMIND variables"
  ))
}
