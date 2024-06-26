% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sql.R
\name{SQLContext_register_globals}
\alias{SQLContext_register_globals}
\title{Register all polars DataFrames/LazyFrames found in the environment}
\usage{
SQLContext_register_globals(..., envir = parent.frame())
}
\arguments{
\item{...}{Ignored.}

\item{envir}{The environment to search for polars DataFrames/LazyFrames.}
}
\value{
Returns the \link[=SQLContext_class]{SQLContext} object invisibly.
}
\description{
Automatically maps variable names to table names.
}
\details{
If a table with the same name is already registered, it will be overwritten.
}
\examples{
\dontshow{if (polars_info()$features$sql) (if (getRversion() >= "3.4") withAutoprint else force)(\{ # examplesIf}
df1 = pl$DataFrame(a = 1:3, b = c("x", NA, "z"))
df2 = pl$LazyFrame(a = 2:4, c = c("t", "w", "v"))

# Register frames directly from variables found in the current environment.
ctx = pl$SQLContext()$register_globals()
ctx$tables()

ctx$execute(
  "SELECT a, b, c FROM df1 LEFT JOIN df2 USING (a) ORDER BY a DESC"
)$collect()
\dontshow{\}) # examplesIf}
}
\seealso{
\itemize{
\item \code{\link[=SQLContext_register]{<SQLContext>$register()}}
\item \code{\link[=SQLContext_register_many]{<SQLContext>$register_many()}}
\item \code{\link[=SQLContext_unregister]{<SQLContext>$unregister()}}
}
}
