#' To polars DataFrame
#'
#' [as_polars_df()] is a generic function that converts an R object to a
#' [polars DataFrame][DataFrame_class].
#'
#' For [LazyFrame][LazyFrame_class] objects, this function is a shortcut for
#' [$collect()][LazyFrame_collect] or [$fetch()][LazyFrame_fetch], depending on
#' whether the number of rows to fetch is infinite or not.
#' @rdname as_polars_df
#' @inheritParams as_polars_series
#' @param x Object to convert to a polars DataFrame.
#' @param ... Additional arguments passed to methods.
#' @return a [DataFrame][DataFrame_class]
#' @examplesIf requireNamespace("arrow", quietly = TRUE)
#' # Convert the row names of a data frame to a column
#' as_polars_df(mtcars, rownames = "car")
#'
#' # Convert a data frame, with renaming all columns
#' as_polars_df(
#'   data.frame(x = 1, y = 2),
#'   schema = c("a", "b")
#' )
#'
#' # Convert a data frame, with renaming and casting all columns
#' as_polars_df(
#'   data.frame(x = 1, y = 2),
#'   schema = list(b = pl$Int64, a = pl$String)
#' )
#'
#' # Convert a data frame, with casting some columns
#' as_polars_df(
#'   data.frame(x = 1, y = 2),
#'   schema_overrides = list(y = pl$String) # cast some columns
#' )
#'
#' # Convert an arrow Table to a polars DataFrame
#' at = arrow::arrow_table(x = 1:5, y = 6:10)
#' as_polars_df(at)
#'
#' # Create a polars DataFrame from a data.frame
#' lf = as_polars_df(mtcars)$lazy()
#'
#' # Collect all rows from the LazyFrame
#' as_polars_df(lf)
#'
#' # Fetch 5 rows from the LazyFrame
#' as_polars_df(lf, 5)
#' @export
as_polars_df = function(x, ...) {
  UseMethod("as_polars_df")
}


#' @rdname as_polars_df
#' @export
as_polars_df.default = function(x, ...) {
  as_polars_df(as.data.frame(x, stringsAsFactors = FALSE), ...)
}


#' @rdname as_polars_df
#' @param rownames How to treat existing row names of a data frame:
#'  - `NULL`: Remove row names. This is the default.
#'  - A string: The name of a new column, which will contain the row names.
#'    If `x` already has a column with that name, an error is thrown.
#' @param make_names_unique A logical flag to replace duplicated column names
#' with unique names. If `FALSE` and there are duplicated column names, an
#' error is thrown.
#' @inheritParams as_polars_df.ArrowTabular
#' @export
as_polars_df.data.frame = function(
    x,
    ...,
    rownames = NULL,
    make_names_unique = TRUE,
    schema = NULL,
    schema_overrides = NULL) {
  uw = \(res) unwrap(res, "in as_polars_df():")

  if (anyDuplicated(names(x)) > 0) {
    col_names_orig = names(x)
    if (make_names_unique) {
      names(x) = make.unique(col_names_orig, sep = "_")
    } else {
      Err_plain(
        paste(
          "conflicting column names not allowed:",
          paste(unique(col_names_orig[duplicated(col_names_orig)]), collapse = ", ")
        )
      ) |>
        uw()
    }
  }

  if (is.null(rownames)) {
    df_to_rpldf(x, schema = schema, schema_overrides = schema_overrides)
  } else {
    if (length(rownames) != 1L || !is.character(rownames) || is.na(rownames)) {
      Err_plain("`rownames` must be a single string, or `NULL`") |>
        uw()
    }

    if (rownames %in% names(x)) {
      Err_plain(
        sprintf(
          "The column name '%s' is already used. Please choose a different name for the `rownames` argument.",
          rownames
        )
      ) |>
        uw()
    }

    old_rownames = raw_rownames(x)
    if (length(old_rownames) > 0 && is.na(old_rownames[1L])) {
      # if implicit rownames
      old_rownames = seq_len(abs(old_rownames[2L]))
    }
    old_rownames = as.character(old_rownames)

    pl$concat(
      as_polars_series(old_rownames, name = rownames),
      df_to_rpldf(x, schema = schema, schema_overrides = schema_overrides),
      how = "horizontal"
    )
  }
}


#' @rdname as_polars_df
#' @export
as_polars_df.RPolarsDataFrame = function(x, ...) {
  x
}


#' @rdname as_polars_df
#' @export
as_polars_df.RPolarsGroupBy = function(x, ...) {
  x$ungroup()
}

#' @rdname as_polars_df
#' @export
as_polars_df.RPolarsRollingGroupBy = as_polars_df.RPolarsGroupBy

#' @rdname as_polars_df
#' @export
as_polars_df.RPolarsDynamicGroupBy = as_polars_df.RPolarsGroupBy

#' @rdname as_polars_df
#' @export
as_polars_df.RPolarsSeries = function(x, ...) {
  pl$select(x)
}


#' @rdname as_polars_df
#' @param n_rows Number of rows to fetch. Defaults to `Inf`, meaning all rows.
#' @inheritParams LazyFrame_collect
#' @export
as_polars_df.RPolarsLazyFrame = function(
    x,
    n_rows = Inf,
    ...,
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
    collect_in_background = FALSE) {
  # capture all args and modify some to match lower level function
  args = as.list(environment())
  args$... = list(...)

  if (is.infinite(args$n_rows)) {
    args$n_rows = NULL
    .fn = x$collect
  } else {
    args$collect_in_background = NULL
    .fn = x$fetch
  }

  args$x = NULL
  check_no_missing_args(.fn, args)
  do.call(.fn, args)
}


#' @rdname as_polars_df
#' @export
as_polars_df.RPolarsLazyGroupBy = function(x, ...) {
  as_polars_df.RPolarsLazyFrame(x$ungroup(), ...)
}


#' @rdname as_polars_df
#' @param rechunk A logical flag (default `TRUE`).
#' Make sure that all data of each column is in contiguous memory.
#' @param schema named list of DataTypes, or character vector of column names.
#' Should match the number of columns in `x` and correspond to each column in `x` by position.
#' If a column in `x` does not match the name or type at the same position, it will be renamed/recast.
#' If `NULL` (default), convert columns as is.
#' @param schema_overrides named list of DataTypes. Cast some columns to the DataType.
#' @export
as_polars_df.ArrowTabular = function(
    x,
    ...,
    rechunk = TRUE,
    schema = NULL,
    schema_overrides = NULL,
    experimental = FALSE) {
  arrow_to_rpldf(
    x,
    rechunk = rechunk,
    schema = schema,
    schema_overrides = schema_overrides,
    experimental = experimental
  ) |>
    result() |>
    unwrap("in as_polars_df():")
}


#' @rdname as_polars_df
#' @export
as_polars_df.RecordBatchReader = function(x, ..., experimental = FALSE) {
  uw = \(res) unwrap(res, "in as_polars_df(<RecordBatchReader>):")

  if (isTRUE(experimental)) {
    as_polars_series(x, name = "")$to_frame()$unnest("") |>
      result() |>
      uw()
  } else {
    .pr$DataFrame$from_arrow_record_batches(x$batches()) |>
      uw()
  }
}


#' @rdname as_polars_df
#' @export
as_polars_df.nanoarrow_array = function(x, ...) {
  array_type = nanoarrow::infer_nanoarrow_schema(x) |>
    nanoarrow::nanoarrow_schema_parse() |>
    (\(x) x$type)()

  if (array_type != "struct") {
    Err_plain("Can't convert non-struct array to RPolarsDataFrame") |>
      unwrap("in as_polars_df(<nanoarrow_array>):")
  }

  series = as_polars_series.nanoarrow_array(x, name = NULL)
  series$to_frame()$unnest("")
}


#' @rdname as_polars_df
#' @export
as_polars_df.nanoarrow_array_stream = function(x, ..., experimental = FALSE) {
  if (!identical(nanoarrow::nanoarrow_schema_parse(x$get_schema())$type, "struct")) {
    Err_plain("Can't convert non-struct array stream to RPolarsDataFrame") |>
      unwrap("in as_polars_df(<nanoarrow_array_stream>):")
  }

  as_polars_series.nanoarrow_array_stream(
    x,
    name = "", experimental = experimental
  )$to_frame()$unnest("")
}


#' To polars LazyFrame
#'
#' [as_polars_lf()] is a generic function that converts an R object to a
#' polars LazyFrame. It is basically a shortcut for [as_polars_df(x, ...)][as_polars_df] with the
#' [$lazy()][DataFrame_lazy] method.
#' @rdname as_polars_lf
#' @inheritParams as_polars_df
#' @return a [LazyFrame][LazyFrame_class]
#' @examples
#' as_polars_lf(mtcars)
#' @export
as_polars_lf = function(x, ...) {
  UseMethod("as_polars_lf")
}


#' @rdname as_polars_lf
#' @export
as_polars_lf.default = function(x, ...) {
  as_polars_df(x, ...)$lazy()
}


#' @rdname as_polars_lf
#' @export
as_polars_lf.RPolarsLazyFrame = function(x, ...) {
  x
}


#' @rdname as_polars_lf
#' @export
as_polars_lf.RPolarsLazyGroupBy = function(x, ...) {
  x$ungroup()
}


#' To polars Series
#'
#' [as_polars_series()] is a generic function that converts an R object to
#' [a polars Series][Series_class].
#' @param x Object to convert into [a polars Series][Series_class].
#' @param name A character to use as the name of the [Series][Series_class].
#' If `NULL` (default), the name of `x` is used or an empty character `""`
#' will be used if `x` has no name.
#' @inheritParams as_polars_df
#' @return a [Series][Series_class]
#' @export
#' @examples
#' as_polars_series(1:4)
#'
#' as_polars_series(list(1:4))
#'
#' as_polars_series(data.frame(a = 1:4))
#'
#' as_polars_series(as_polars_series(1:4, name = "foo"))
#'
#' as_polars_series(pl$lit(1:4))
#'
#' # Nested type support
#' as_polars_series(list(data.frame(a = I(list(1:4)))))
as_polars_series = function(x, name = NULL, ...) {
  UseMethod("as_polars_series")
}


#' @rdname as_polars_series
#' @export
as_polars_series.default = function(x, name = NULL, ...) {
  .pr$Series$new(name %||% "", x) |>
    unwrap("in as_polars_series():")
}


#' @rdname as_polars_series
#' @export
as_polars_series.RPolarsSeries = function(x, name = NULL, ...) {
  x$alias(name %||% x$name)
}


#' @rdname as_polars_series
#' @export
as_polars_series.RPolarsExpr = function(x, name = NULL, ...) {
  as_polars_series(pl$select(x)$to_series(0), name = name)
}


#' @rdname as_polars_series
#' @export
as_polars_series.RPolarsThen = as_polars_series.RPolarsExpr


#' @rdname as_polars_series
#' @export
as_polars_series.RPolarsChainedThen = as_polars_series.RPolarsExpr


#' @rdname as_polars_series
#' @export
as_polars_series.POSIXlt = function(x, name = NULL, ...) {
  as_polars_series(as.POSIXct(x), name = name)
}


#' @rdname as_polars_series
#' @export
as_polars_series.data.frame = function(x, name = NULL, ...) {
  as_polars_df(x)$to_struct(name = name %||% "")
}


#' @rdname as_polars_series
#' @export
as_polars_series.vctrs_rcrd = function(x, name = NULL, ...) {
  pl$select(unclass(x))$to_struct(name = name %||% "")
}


#' @rdname as_polars_series
#' @param rechunk A logical flag (default `TRUE`). Make sure that all data is in contiguous memory.
#' @export
as_polars_series.Array = function(x, name = NULL, ..., rechunk = TRUE) {
  arrow_to_rseries_result(name = name %||% "", values = x, rechunk = rechunk) |>
    unwrap()
}


#' @rdname as_polars_series
#' @export
as_polars_series.ChunkedArray = as_polars_series.Array


#' @rdname as_polars_series
#' @export
as_polars_series.RecordBatchReader = function(x, name = NULL, ...) {
  stream_out = polars_allocate_array_stream()
  x$export_to_c(stream_out)

  out = .pr$Series$import_stream(
    stream_out
  ) |>
    unwrap("in as_polars_series(<RecordBatchReader>):")

  if (!is.null(name)) {
    out$rename(name)
  } else {
    out
  }
}


#' @rdname as_polars_series
#' @export
as_polars_series.nanoarrow_array = function(x, name = NULL, ...) {
  # TODO: support 0-length array
  .pr$Series$from_arrow_array_robj(name %||% "", x) |>
    unwrap()
}


#' @param experimental If `TRUE`, use experimental Arrow C stream interface inside the function.
#' This argument is experimental and may be removed in the future.
#' @rdname as_polars_series
#' @export
as_polars_series.nanoarrow_array_stream = function(x, name = NULL, ..., experimental = FALSE) {
  on.exit(x$release())

  if (isTRUE(experimental)) {
    stream_out = polars_allocate_array_stream()
    nanoarrow::nanoarrow_pointer_export(x, stream_out)

    out = .pr$Series$import_stream(
      stream_out
    ) |>
      unwrap("in as_polars_series(<nanoarrow_array_stream>):")

    if (!is.null(name)) {
      out$rename(name)
    } else {
      out
    }
  } else {
    list_of_arrays = nanoarrow::collect_array_stream(x, validate = FALSE)

    if (length(list_of_arrays) < 1L) {
      # TODO: support 0-length array stream
      out = pl$Series(name = name)
    } else {
      name_of_array = nanoarrow::infer_nanoarrow_schema(list_of_arrays[[1L]])$name
      out = as_polars_series.nanoarrow_array(list_of_arrays[[1L]], name = name %||% name_of_array)
      lapply(
        list_of_arrays[-1L],
        \(array) .pr$Series$append_mut(out, as_polars_series.nanoarrow_array(array))
      ) |>
        invisible()
    }

    out
  }
}


#' @rdname as_polars_series
#' @export
as_polars_series.clock_time_point = function(x, name = NULL, ...) {
  from_precision = clock::time_point_precision(x)

  # Polars' datetime type only include ns, us, ms
  if (
    !from_precision %in% c(
      "nanosecond", "microsecond", "millisecond", "second", "minute", "hour", "day"
    )
  ) {
    x = clock::time_point_cast(x, "millisecond")
    from_precision = clock::time_point_precision(x)
  }

  # https://github.com/r-lib/clock/blob/adc01b61670b18463cc3087f1e58acf59ddc3915/R/precision.R#L37-L51
  target_precision = pcase(
    from_precision == "nanosecond", "ns",
    from_precision == "microsecond", "us",
    from_precision == "millisecond", "ms",
    or_else = "ms" # second, minute, hour, day
  )

  n_multiply_to_ms = pcase(
    from_precision == "second", 1000L,
    from_precision == "minute", 1000L * 60L,
    from_precision == "hour", 1000L * 60L * 60L,
    from_precision == "day", 1000L * 60L * 60L * 24L,
    or_else = 1L # ns, us, ms
  )

  unclassed_x = unclass(x)
  df_in = pl$DataFrame(unclassed_x)

  pl_lit_half_of_u64 = pl$lit(2L)$cast(pl$UInt64)$pow(pl$lit(63L)$cast(pl$UInt8))

  # https://github.com/r-lib/clock/blob/adc01b61670b18463cc3087f1e58acf59ddc3915/src/duration.h#L174-L184
  df_in$select(
    pl$col("lower")$cast(pl$UInt64),
    pl$col("upper")$cast(pl$UInt64)
  )$select(
    pl$col("lower")$mul(pl$lit(4294967296)$cast(pl$UInt64))$or(
      pl$col("upper")
    )
  )$with_columns(
    diff_1 = pl$when(
      pl$col("lower")$gt(pl_lit_half_of_u64)
    )$then(
      pl$col("lower")$sub(pl_lit_half_of_u64)
    )$otherwise(NULL)
  )$with_columns(
    diff_2 = pl$when(
      pl$col("diff_1")$is_null()
    )$then(pl_lit_half_of_u64$sub(pl$col("lower")))$otherwise(NULL)
  )$select(
    out = pl$when(pl$col("diff_1")$is_null())$then(
      pl$lit(0L)$cast(pl$Int64)$sub(pl$col("diff_2")$cast(pl$Int64))
    )$otherwise(
      pl$col("diff_1")$cast(pl$Int64)
    )$mul(
      pl$lit(n_multiply_to_ms)$cast(pl$UInt32)
    )$cast(pl$Datetime(target_precision))
  )$get_column("out")$alias(name %||% "")
}


#' @rdname as_polars_series
#' @export
as_polars_series.clock_sys_time = function(x, name = NULL, ...) {
  as_polars_series.clock_time_point(x, name = name, ...)$dt$replace_time_zone("UTC")
}


#' @rdname as_polars_series
#' @export
as_polars_series.clock_zoned_time = function(x, name = NULL, ...) {
  time_zone = clock::zoned_time_zone(x)

  if (isTRUE(time_zone == "")) {
    # https://github.com/r-lib/clock/issues/366
    time_zone = Sys.timezone()
  }
  if (!isTRUE(time_zone %in% base::OlsonNames())) {
    sprintf(
      "The time zone '%s' is not supported in polars. See `base::OlsonNames()` for supported time zones.",
      time_zone
    ) |>
      Err_plain() |>
      unwrap("in as_polars_series(<clock_zoned_time>):")
  }

  as_polars_series.clock_time_point(
    clock::as_naive_time(x),
    name = name,
    ...
  )$dt$replace_time_zone(time_zone)
}


#' @rdname as_polars_series
#' @export
as_polars_series.list = function(x, name = NULL, ...) {
  lapply(x, \(child) {
    if (is.null(child)) {
      NULL # if `NULL`, the type will be resolved later
    } else {
      as_polars_series(child)
    }
  }) |>
    as_polars_series.default(name = name)
}


# TODO: reconsider `rpolars_raw_list`
#' @export
as_polars_series.rpolars_raw_list = function(x, name = NULL, ...) {
  as_polars_series.default(x, name = name)
}
