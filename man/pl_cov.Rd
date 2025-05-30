% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/functions__lazy.R
\name{pl_cov}
\alias{pl_cov}
\title{Covariance}
\usage{
pl_cov(a, b, ddof = 1)
}
\arguments{
\item{a}{One column name or Expr or anything convertible Into\if{html}{\out{<Expr>}} via \code{pl$col()}.}

\item{b}{Another column name or Expr or anything convertible Into\if{html}{\out{<Expr>}} via \code{pl$col()}.}

\item{ddof}{integer Delta Degrees of Freedom: the divisor used in the calculation is N - ddof, where N represents the number of elements. By default ddof is 1.}
}
\value{
Expr for the computed covariance
}
\description{
Calculates the covariance between two columns / expressions.
}
\examples{
lf = as_polars_lf(data.frame(a = c(1, 8, 3), b = c(4, 5, 2)))
lf$select(pl$cov("a", "b"))$collect()
pl$cov(c(1, 8, 3), c(4, 5, 2))$to_r()
}
