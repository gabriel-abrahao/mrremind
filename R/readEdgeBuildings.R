#' Load an EDGE Buildings file as magclass object.
#'
#' @param subtype One of the possible subtypes, see default argument.
#' @param subset A string (or vector of strings) designating the scenario(s)
#' to be returned (needed in 'convertEdgeBuildings').
#' @return magclass object
#'
#' @author Antoine Levesque, Robin Hasse
readEdgeBuildings <- function(subtype = c("FE", "Floorspace"), subset) {

  subtype <- match.arg(subtype)

  # input data version
  ver <- "2.5"
  data <- read.csv(file.path(ver, "EDGE_buildings.csv"), comment.char = "*")
  data <- as.magpie(data)

  if (subtype == "FE") {
    data <- mselect(data, variable = grep("(ue|fe)$", getItems(data, dim = "variable"), value = TRUE))

    # Add RCP column initialized with "none"
    rcpScens <- unique(gsub(".*_(rcp\\d_*\\d*)$", "\\1",
                            grep("_(rcp\\d_*\\d*)$", getItems(data, dim = "scenario"), value = TRUE)))
    data <- add_dimension(data, dim = 3.2, add = "rcp", nm = "none")

    # Extract RCP scenarios from the scenario column if any are present
    if (length(rcpScens) >= 1) {
      dataRcp <- do.call(mbind, lapply(rcpScens, function(rcp) {
        tmp <- mselect(data, scenario = grep(rcp, getItems(data, dim = "scenario"), value = TRUE))
        getNames(tmp, dim = "rcp") <- if (grepl("rcp\\d$", rcp)) paste0(rcp, "0") else gsub("_", "", rcp)
        getNames(tmp, dim = "scenario") <- gsub("_rcp\\d_*\\d*", "", getNames(tmp, dim = "scenario"))
        return(tmp)
      }))
      if (!all(grepl("_rcp\\d_*\\d*", getItems(data, dim = "scenario")))) {
        dataNoRcp <- mselect(data, scenario = grep("_rcp\\d_*\\d*", getItems(data, dim = "scenario"),
                                                   value = TRUE, invert = TRUE))
        data <- mbind(dataRcp, dataNoRcp)
      } else {
        data <- dataRcp
      }
    }
    getSets(data) <- c("region", "year", "scenario", "rcp", "item")
  }

  if (subtype == "Floorspace") {
    data <- mselect(data, variable = grep("^floorspace", getItems(data, dim = "variable"), value = TRUE))
    getNames(data, dim = "scenario") <- gsub("_rcp.*$", "", getNames(data, dim = "scenario"))
    getNames(data, dim = "variable") <- gsub("^floorspace_(\\w+)$", "\\1", getNames(data, dim = "variable"))
    getNames(data, dim = "variable") <- gsub("^floorspace$", "buildings", getNames(data, dim = "variable"))
    data <- collapseNames(data)
    getSets(data) <- c("region", "year", "scenario", "variable")
  }

  data
}
