#' @export
#' @noRd
.DollarNames.RPolarsErr = function(x, pattern = "") {
  get_method_usages(RPolarsErr, pattern = pattern)
}

#' @export
#' @noRd
as.character.RPolarsErr = function(x, ...) x$pretty_msg()


#' @export
#' @noRd
print.RPolarsErr = function(x, ...) cat(x$pretty_msg())


## RPolarsErr IPLEMENTS IPLEMENTS R-POLARS error_trait.R
#' @exportS3Method
when_calling.RPolarsErr = function(err, call) {
  err$rcall(call_to_string(call))
}

#' @exportS3Method
where_in.RPolarsErr = function(err, context) {
  err$rinfo(context)
}

#' @exportS3Method
to_condition.RPolarsErr = function(err) {
  errorCondition(
    err$pretty_msg(),
    class = c("RPolarsErr_error"),
    value = err,
    call = NULL
  )
}

#' @exportS3Method
plain.RPolarsErr = function(err, msg) {
  err$plain(msg)
}

#' @exportS3Method
upgrade_err.RPolarsErr = function(err) { # already RPolarsErr pass through
  err
}




#### ---- rpolarserr utils

# short hand  for starting new error with a bad robj input
bad_robj = function(r) {
  .pr$Err$new()$bad_robj(r)
}

Err_plain = function(...) {
  Err(.pr$Err$new()$plain(paste(..., collapse = " ")))
}

# short hand for extracting an error context in unit testing, will raise error if not an RPolarsErr
get_err_ctx = \(x, select = NULL) {
  ctx = unwrap_err(result(x))$contexts()
  if (is.null(select)) {
    ctx
  } else {
    ctx[[match.arg(select, names(ctx))]]
  }
}


# wrapper to return Result
err_on_named_args = function(...) {
  l = list2(...)
  if (is.null(names(l)) || all(names(l) == "")) {
    Ok(l)
  } else {
    bad_names = names(l)[names(l) != ""]
    .pr$Err$
      new()$
      bad_arg(paste(bad_names, collapse = ", "))$
      plain("... args not allowed to be named here")$
      hint("named ... arg was passed, or a non ... arg was misspelled") |>
      Err()
  }
}
