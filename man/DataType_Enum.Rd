% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/datatype.R
\name{DataType_Enum}
\alias{DataType_Enum}
\title{Create Enum DataType}
\usage{
DataType_Enum(categories)
}
\arguments{
\item{categories}{A character vector specifying the categories of the variable.}
}
\value{
An Enum DataType
}
\description{
An \code{Enum} is a fixed set categorical encoding of a set of strings. It is
similar to the \code{\link[=DataType_Categorical]{Categorical}} data type, but the
categories are explicitly provided by the user and cannot be modified.
}
\details{
This functionality is \strong{unstable}. It is a work-in-progress feature and may
not always work as expected. It may be changed at any point without it being
considered a breaking change.
}
\examples{
pl$DataFrame(
  x = c("Polar", "Panda", "Brown", "Brown", "Polar"),
  schema = list(x = pl$Enum(c("Polar", "Panda", "Brown")))
)

# All values of the variable have to be in the categories
dtype = pl$Enum(c("Polar", "Panda", "Brown"))
tryCatch(
  pl$DataFrame(
    x = c("Polar", "Panda", "Brown", "Brown", "Polar", "Black"),
    schema = list(x = dtype)
  ),
  error = function(e) e
)

# Comparing two Enum is only valid if they have the same categories
df = pl$DataFrame(
  x = c("Polar", "Panda", "Brown", "Brown", "Polar"),
  y = c("Polar", "Polar", "Polar", "Brown", "Brown"),
  z = c("Polar", "Polar", "Polar", "Brown", "Brown"),
  schema = list(
    x = pl$Enum(c("Polar", "Panda", "Brown")),
    y = pl$Enum(c("Polar", "Panda", "Brown")),
    z = pl$Enum(c("Polar", "Black", "Brown"))
  )
)

# Same categories
df$with_columns(x_eq_y = pl$col("x") == pl$col("y"))

# Different categories
tryCatch(
  df$with_columns(x_eq_z = pl$col("x") == pl$col("z")),
  error = function(e) e
)
}
