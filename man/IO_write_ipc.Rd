% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dataframe__frame.R
\name{DataFrame_write_ipc}
\alias{DataFrame_write_ipc}
\title{Write to Arrow IPC file (a.k.a Feather file)}
\usage{
DataFrame_write_ipc(
  file,
  compression = c("uncompressed", "zstd", "lz4"),
  ...,
  compat_level = TRUE
)
}
\arguments{
\item{file}{File path to which the result should be written.}

\item{compression}{\code{NULL} or a character of the compression method,
\code{"uncompressed"} or "lz4" or "zstd". \code{NULL} is equivalent to \code{"uncompressed"}.
Choose "zstd" for good compression performance. Choose "lz4"
for fast compression/decompression.}

\item{...}{Ignored.}

\item{compat_level}{Use a specific compatibility level when exporting Polars’
internal data structures. This can be:
\itemize{
\item an integer indicating the compatibility version (currently only 0 for oldest
and 1 for newest);
\item a logical value with \code{TRUE} for the newest version and \code{FALSE} for the oldest
version.
}}
}
\value{
Invisibly returns the input DataFrame.
}
\description{
Write to Arrow IPC file (a.k.a Feather file)
}
\examples{
dat = as_polars_df(mtcars)

destination = tempfile(fileext = ".arrow")
dat$write_ipc(destination)

if (require("arrow", quietly = TRUE)) {
  arrow::read_ipc_file(destination, as_data_frame = FALSE)
}
}
\seealso{
\itemize{
\item \code{\link[=DataFrame_to_raw_ipc]{<DataFrame>$to_raw_ipc()}}
}
}
