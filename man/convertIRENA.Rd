% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/convertIRENA.R
\name{convertIRENA}
\alias{convertIRENA}
\title{Converts IRENA Regional data}
\usage{
convertIRENA(x, subtype)
}
\arguments{
\item{x}{MAgPIE object to be converted}

\item{subtype}{data subtype. Either "Capacity" or "Generation"}
}
\value{
A MAgPIE object containing IRENA country disaggregated data  with
historical electricity renewable capacities (MW) or generation levels (GWh)
}
\description{
Converts IRENA Regional data
}
\examples{
\dontrun{
a <- convertIRENA(x, subtype = "Capacity")
}

}
\author{
Renato Rodrigues, Pascal Weigmann
}
