% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/s3-methods.R
\name{as.data.frame.RPolarsDataFrame}
\alias{as.data.frame.RPolarsDataFrame}
\alias{as.data.frame.RPolarsLazyFrame}
\title{Convert to a data.frame}
\usage{
\method{as.data.frame}{RPolarsDataFrame}(x, ..., int64_conversion = polars_options()$int64_conversion)

\method{as.data.frame}{RPolarsLazyFrame}(
  x,
  ...,
  n_rows = Inf,
  type_coercion = TRUE,
  predicate_pushdown = TRUE,
  projection_pushdown = TRUE,
  simplify_expression = TRUE,
  slice_pushdown = TRUE,
  comm_subplan_elim = TRUE,
  comm_subexpr_elim = TRUE,
  cluster_with_columns = TRUE,
  streaming = FALSE,
  no_optimization = FALSE,
  collect_in_background = FALSE
)
}
\arguments{
\item{x}{An object to convert to a \link{data.frame}.}

\item{...}{Additional arguments passed to methods.}

\item{int64_conversion}{How should Int64 values be handled when converting a
polars object to R?
\itemize{
\item \code{"double"} (default) converts the integer values to double.
\item \code{"bit64"} uses \code{bit64::as.integer64()} to do the conversion (requires
the package \code{bit64} to be attached).
\item \code{"string"} converts Int64 values to character.
}}

\item{n_rows}{Number of rows to fetch. Defaults to \code{Inf}, meaning all rows.}

\item{type_coercion}{Logical. Coerce types such that operations succeed and
run on minimal required memory.}

\item{predicate_pushdown}{Logical. Applies filters as early as possible at
scan level.}

\item{projection_pushdown}{Logical. Select only the columns that are needed
at the scan level.}

\item{simplify_expression}{Logical. Various optimizations, such as constant
folding and replacing expensive operations with faster alternatives.}

\item{slice_pushdown}{Logical. Only load the required slice from the scan
level. Don't materialize sliced outputs (e.g. \code{join$head(10)}).}

\item{comm_subplan_elim}{Logical. Will try to cache branching subplans that
occur on self-joins or unions.}

\item{comm_subexpr_elim}{Logical. Common subexpressions will be cached and
reused.}

\item{cluster_with_columns}{Combine sequential independent calls to
\code{\link[=DataFrame_with_columns]{with_columns()}}.}

\item{streaming}{Logical. Run parts of the query in a streaming fashion
(this is in an alpha state).}

\item{no_optimization}{Logical. Sets the following parameters to \code{FALSE}:
\code{predicate_pushdown}, \code{projection_pushdown}, \code{slice_pushdown},
\code{comm_subplan_elim}, \code{comm_subexpr_elim}, \code{cluster_with_columns}.}

\item{collect_in_background}{Logical. Detach this query from R session.
Computation will start in background. Get a handle which later can be converted
into the resulting DataFrame. Useful in interactive mode to not lock R session.}
}
\description{
Equivalent to \code{as_polars_df(x, ...)$to_data_frame(...)}.
}
\section{Conversion to R data types considerations}{

When converting Polars objects, such as \link[=DataFrame_class]{DataFrames}
to R objects, for example via the \code{\link[=as.data.frame.RPolarsDataFrame]{as.data.frame()}} generic function,
each type in the Polars object is converted to an R type.
In some cases, an error may occur because the conversion is not appropriate.
In particular, there is a high possibility of an error when converting
a \link[=DataType_Datetime]{Datetime} type without a time zone.
A \link[=DataType_Datetime]{Datetime} type without a time zone in Polars is converted
to the \link{POSIXct} type in R, which takes into account the time zone in which
the R session is running (which can be checked with the \code{\link[=Sys.timezone]{Sys.timezone()}}
function). In this case, if ambiguous times are included, a conversion error
will occur. In such cases, change the session time zone using
\code{\link[base:Sys.setenv]{Sys.setenv(TZ = "UTC")}} and then perform the conversion, or use the
\code{\link[=ExprDT_replace_time_zone]{$dt$replace_time_zone()}} method on the Datetime type column to
explicitly specify the time zone before conversion.

\if{html}{\out{<div class="sourceCode r">}}\preformatted{# Due to daylight savings, clocks were turned forward 1 hour on Sunday, March 8, 2020, 2:00:00 am
# so this particular date-time doesn't exist
non_existent_time = as_polars_series("2020-03-08 02:00:00")$str$strptime(pl$Datetime(), "\%F \%T")

withr::with_timezone(
  "America/New_York",
  \{
    tryCatch(
      # This causes an error due to the time zone (the `TZ` env var is affected).
      as.vector(non_existent_time),
      error = function(e) e
    )
  \}
)
#> <error: in $to_vector(): in to_r: ComputeError(ErrString("datetime '2020-03-08 02:00:00' is non-existent in time zone 'America/New_York'. You may be able to use `non_existent='null'` to return `null` in this case.")) When calling: devtools::document()>

withr::with_timezone(
  "America/New_York",
  \{
    # This is safe.
    as.vector(non_existent_time$dt$replace_time_zone("UTC"))
  \}
)
#> [1] "2020-03-08 02:00:00 UTC"
}\if{html}{\out{</div>}}
}

\seealso{
\itemize{
\item \code{\link[=as_polars_df]{as_polars_df()}}
\item \code{\link[=DataFrame_to_data_frame]{<DataFrame>$to_data_frame()}}
}
}
