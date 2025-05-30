test_df = data.frame(
  "col_int" = 1L:10L,
  "col_dbl" = (1:10) / 10,
  "col_chr" = letters[1:10],
  "col_lgl" = rep_len(c(TRUE, FALSE, NA), 10)
)


make_as_polars_df_cases = function() {
  skip_if_not_installed("arrow")
  skip_if_not_installed("nanoarrow")

  tibble::tribble(
    ~.test_name, ~x,
    "data.frame", test_df,
    "polars_lf", as_polars_lf(test_df),
    "polars_group_by", as_polars_df(test_df)$group_by("col_int"),
    "polars_lazy_group_by", as_polars_lf(test_df)$group_by("col_int"),
    "polars_rolling_group_by", as_polars_df(test_df)$rolling("col_int", period = "1i"),
    "polars_lazy_rolling_group_by", as_polars_lf(test_df)$rolling("col_int", period = "1i"),
    "polars_group_by_dynamic", as_polars_df(test_df)$group_by_dynamic("col_int", every = "1i"),
    "polars_lazy_group_by_dynamic", as_polars_lf(test_df)$group_by_dynamic("col_int", every = "1i"),
    "arrow Table", arrow::as_arrow_table(test_df),
    "arrow RecordBatch", arrow::as_record_batch(test_df),
    "arrow RecordBatchReader", arrow::as_record_batch_reader(test_df),
    "nanoarrow_array", nanoarrow::as_nanoarrow_array(test_df),
    "nanoarrow_array_stream", nanoarrow::as_nanoarrow_array_stream(test_df),
  )
}

patrick::with_parameters_test_that(
  "as_polars_df S3 methods",
  {
    pl_df = as_polars_df(x)
    expect_s3_class(pl_df, "RPolarsDataFrame")

    if (inherits(x, "nanoarrow_array_stream")) {
      # The stream should be released after conversion
      expect_grepl_error(x$get_next(), "already been released")
    }

    expect_equal(as.data.frame(pl_df), as.data.frame(as_polars_df(test_df)))
  },
  .cases = make_as_polars_df_cases()
)


test_that("as_polars_lf S3 method", {
  skip_if_not_installed("arrow")
  at = arrow::as_arrow_table(test_df)
  expect_s3_class(as_polars_lf(at), "RPolarsLazyFrame")
})


make_rownames_cases = function() {
  tibble::tribble(
    ~.test_name, ~x, ~rownames,
    "mtcars - NULL", mtcars, NULL,
    "mtcars - foo", mtcars, "foo",
    "trees - foo", trees, "foo",
    "matrix - NULL", matrix(1:4, nrow = 2), NULL,
    "matrix - foo", matrix(1:4, nrow = 2), "foo",
  )
}


patrick::with_parameters_test_that("rownames option of as_polars_df",
  {
    pl_df = as_polars_df(x, rownames = rownames)
    expect_s3_class(pl_df, "RPolarsDataFrame")

    actual = as.data.frame(pl_df)
    expected = as.data.frame(x) |>
      tibble::as_tibble(rownames = rownames) |>
      as.data.frame()

    expect_equal(actual, expected)
  },
  .cases = make_rownames_cases()
)


test_that("as_polars_df throws error when rownames is not a single string or already used", {
  expect_grepl_error(as_polars_df(mtcars, rownames = "cyl"), "already used")
  expect_grepl_error(as_polars_df(mtcars, rownames = c("cyl", "disp")), "must be a single string")
  expect_grepl_error(as_polars_df(mtcars, rownames = 1), "must be a single string")
  expect_grepl_error(as_polars_df(mtcars, rownames = NA_character_), "must be a single string")
  expect_grepl_error(
    as_polars_df(data.frame(a = 1, a = 2, check.names = FALSE), rownames = "a_1"),
    "already used"
  )
})


test_that("as_polars_df throws error when make_names_unique = FALSE and there are duplicated column names", {
  expect_grepl_error(
    as_polars_df(data.frame(a = 1, a = 2, check.names = FALSE), make_names_unique = FALSE),
    "not allowed"
  )
})


test_that("schema option and schema_overrides for as_polars_df.data.frame", {
  df = data.frame(a = 1:3, b = 4:6)
  pl_df_1 = as_polars_df(df, schema = list(b = pl$String, y = pl$Int32))
  pl_df_2 = as_polars_df(df, schema = c("x", "y"))
  pl_df_3 = as_polars_df(df, schema_overrides = list(a = pl$String))

  expect_equal(
    pl_df_1$to_data_frame(),
    data.frame(b = as.character(1:3), y = 4L:6L)
  )
  expect_equal(
    pl_df_2$to_data_frame(),
    data.frame(x = 1:3, y = 4:6)
  )
  expect_equal(
    pl_df_3$to_data_frame(),
    data.frame(a = as.character(1:3), b = 4:6)
  )

  expect_grepl_error(as_polars_df(mtcars, schema = "cyl"), "schema length does not match")
})


make_as_polars_series_cases = function() {
  skip_if_not_installed("arrow")
  skip_if_not_installed("nanoarrow")

  tibble::tribble(
    ~.test_name, ~x, ~expected_name,
    "vector", 1, "",
    "Series", as_polars_series(1, "foo"), "foo",
    "Expr", pl$lit(1)$alias("foo"), "foo",
    "Then", pl$when(TRUE)$then(1), "literal",
    "ChainedThen", pl$when(FALSE)$then(0)$when(TRUE)$then(1), "literal",
    "list", list(1:4), "",
    "data.frame", data.frame(x = 1, y = letters[1]), "",
    "POSIXlt", as.POSIXlt("1900-01-01"), "",
    "arrow Array", arrow::arrow_array(1), "",
    "arrow ChunkedArray", arrow::chunked_array(1), "",
    "nanoarrow_array", nanoarrow::as_nanoarrow_array(1), "",
    "nanoarrow_array_stream", nanoarrow::as_nanoarrow_array_stream(data.frame(x = 1)), "",
  )
}

patrick::with_parameters_test_that(
  "as_polars_series S3 methods",
  {
    pl_series = as_polars_series(x)
    expect_s3_class(pl_series, "RPolarsSeries")

    expect_length(pl_series, 1L)
    expect_equal(pl_series$name, expected_name)

    if (inherits(x, "nanoarrow_array_stream")) {
      # The stream should be released after conversion
      expect_grepl_error(x$get_next(), "already been released")

      # Re-create the stream for the next test
      x = nanoarrow::as_nanoarrow_array_stream(data.frame(x = 1))
    }

    pl_series = as_polars_series(x, name = "bar")
    expect_equal(pl_series$name, "bar")
  },
  .cases = make_as_polars_series_cases()
)


test_that("tests for vctrs_rcrd", {
  skip_if_not_installed("vctrs")
  skip_if_not_installed("tibble")

  latlon = function(lat, lon) {
    vctrs::new_rcrd(list(lat = lat, lon = lon), class = "earth_latlon")
  }

  format.earth_latlon = function(x, ..., formatter = deg_min) {
    x_valid = which(!is.na(x))

    lat = vctrs::field(x, "lat")[x_valid]
    lon = vctrs::field(x, "lon")[x_valid]

    ret = rep(NA_character_, vec_size(x))
    ret[x_valid] = paste0(formatter(lat, "lat"), " ", formatter(lon, "lon"))

    ret
  }

  deg_min = function(x, direction) {
    pm = if (direction == "lat") c("N", "S") else c("E", "W")

    sign = sign(x)
    x = abs(x)
    deg = trunc(x)
    x = x - deg
    min = round(x * 60)

    # Ensure the columns are always the same width so they line up nicely
    ret = sprintf("%d°%.2d'%s", deg, min, ifelse(sign >= 0, pm[[1]], pm[[2]]))
    format(ret, justify = "right")
  }

  vec = latlon(c(32.71, 2.95), c(-117.17, 1.67))

  expect_length(as_polars_series(vec), 2L)

  expect_snapshot(pl$DataFrame(foo = vec)$dtypes, cran = TRUE)

  expect_identical(
    dim(as_polars_df(tibble::tibble(foo = vec))),
    c(2L, 1L)
  )
})


test_that("from arrow Table and ChunkedArray", {
  skip_if_not_installed("arrow")

  # support plain chunked Table
  l = list(
    df1 = data.frame(val = c(1, 2, 3), blop = c("a", "b", "c")),
    df2 = data.frame(val = c(4, 5, 6), blop = c("a", "b", "c"))
  )
  at = lapply(l, arrow::as_arrow_table) |> do.call(what = rbind)

  # chunked conversion
  expect_identical(
    as_polars_df.ArrowTabular(at)$to_list(),
    as.list(at)
  )
  expect_identical(
    lapply(at$columns, \(x) as_polars_series.ChunkedArray(x)$to_r()),
    unname(as.list(at))
  )

  expect_identical(
    lapply(at$columns, \(x) length(as_polars_series.ChunkedArray(x, rechunk = FALSE)$chunk_lengths())),
    lapply(at$columns, \(x) x$num_chunks)
  )
  expect_grepl_error(expect_identical(
    lapply(at$columns, \(x) length(as_polars_series.ChunkedArray(x, rechunk = TRUE)$chunk_lengths())),
    lapply(at$columns, \(x) x$num_chunks)
  ))
  expect_identical(
    as_polars_df.ArrowTabular(at, rechunk = FALSE)$
      select(pl$all()$map_batches(\(s) s$chunk_lengths()))$
      to_list() |>
      lapply(length) |>
      unname(),
    lapply(at$columns, \(x) x$num_chunks)
  )

  # not supported yet
  # #chunked data with factors
  l = list(
    df1 = data.frame(factor = factor(c("apple", "apple", "banana"))),
    df2 = data.frame(factor = factor(c("apple", "apple", "clementine")))
  )
  at = lapply(l, arrow::arrow_table) |> do.call(what = rbind)
  df = as_polars_df.ArrowTabular(at)
  expect_identical(as.data.frame(at), as.data.frame(df))

  # chunked data with factors and regular integer32
  at2 = lapply(l, \(df) {
    df$value = 1:3
    df
  }) |>
    lapply(arrow::arrow_table) |>
    do.call(what = rbind)
  df2 = as_polars_df.ArrowTabular(at2)
  expect_identical(as.data.frame(at2), as.data.frame(df2))


  # use schema override
  df = as_polars_df.ArrowTabular(
    arrow::arrow_table(iris),
    schema_overrides = list(Sepal.Length = pl$Float32, Species = pl$String)
  )
  iris_str = iris
  iris_str$Species = as.character(iris_str$Species)
  expect_grepl_error(expect_equal(df$to_list(), as.list(iris_str)))
  expect_equal(df$to_list(), as.list(iris_str), tolerance = 0.0001)

  # change column name via char schema
  char_schema = names(iris)
  char_schema[1] = "Alice"
  expect_identical(
    as_polars_df.ArrowTabular(
      arrow::arrow_table(iris),
      schema = char_schema
    )$columns,
    char_schema
  )
})


test_that("can convert an arrow Table contains dictionary<large_string, uint32> type, issue #725", {
  skip_if_not_installed("arrow")

  da_string = arrow::Array$create(
    factor(c("x", "y", "z"))
  )

  da_large_string = da_string$cast(
    arrow::dictionary(
      index_type = arrow::uint32(),
      value_type = arrow::large_utf8()
    )
  )

  at = arrow::arrow_table(foo = da_string, bar = da_large_string)
  ps = as_polars_series.Array(da_large_string)
  pdf = as_polars_df.ArrowTabular(at)

  expect_s3_class(ps, "RPolarsSeries")
  expect_equal(ps$to_r(), factor(c("x", "y", "z")))
  expect_s3_class(pdf, "RPolarsDataFrame")
  expect_equal(
    pdf$to_data_frame(),
    data.frame(
      foo = factor(c("x", "y", "z")),
      bar = factor(c("x", "y", "z"))
    )
  )
})

make_nanoarrow_array_stream_cases = function() {
  skip_if_not_installed("nanoarrow")

  tibble::tribble(
    ~.test_name, ~x,
    "two chunks", nanoarrow::basic_array_stream(list(data.frame(a = 1, b = 2), data.frame(a = NA, b = 1))),
    "nested", nanoarrow::as_nanoarrow_array_stream(tibble::tibble(a = 1, b = tibble::tibble(c = 3:4, d = 5:6))),
  )
}

patrick::with_parameters_test_that("as_polars_df for nanoarrow_array_stream",
  {
    pl_df = as_polars_df(x)
    expect_s3_class(pl_df, "RPolarsDataFrame")
    expect_grepl_error(x$get_next(), "already been released")

    expect_identical(dim(pl_df), c(2L, 2L))
  },
  .cases = make_nanoarrow_array_stream_cases()
)

patrick::with_parameters_test_that("as_polars_series for nanoarrow_array_stream",
  {
    pl_series = as_polars_series(x)
    expect_s3_class(pl_series, "RPolarsSeries")
    expect_grepl_error(x$get_next(), "already been released")

    expect_length(pl_series, 2L)
  },
  .cases = make_nanoarrow_array_stream_cases()
)


patrick::with_parameters_test_that("clock package class support",
  {
    skip_if_not_installed("clock")

    naive_time_chr = c(
      "1900-01-01T12:34:56.123456789",
      "2012-01-01T12:34:56.123456789",
      "2212-01-01T12:34:56.123456789"
    )

    clock_naive_time = clock::naive_time_parse(naive_time_chr, precision = precision)
    clock_sys_time = clock::sys_time_parse(naive_time_chr, precision = precision)
    clock_zoned_time_1 = clock::as_zoned_time(clock_naive_time, "America/New_York")

    pl_naive_time = as_polars_series(clock_naive_time)
    pl_sys_time = as_polars_series(clock_sys_time)
    pl_zoned_time_1 = as_polars_series(clock_zoned_time_1)

    expect_s3_class(pl_naive_time, "RPolarsSeries")
    expect_s3_class(pl_sys_time, "RPolarsSeries")
    expect_s3_class(pl_zoned_time_1, "RPolarsSeries")

    expect_equal(as.POSIXct(as.vector(pl_naive_time)), as.POSIXct(clock_naive_time))
    expect_equal(as.POSIXct(as.vector(pl_zoned_time_1)), as.POSIXct(clock_zoned_time_1))

    skip_if(getRversion() < "4.3.0") # The bug of `as.POSIXct(<POSIXct>)` in R 4.2
    expect_equal(as.POSIXct(as.vector(pl_sys_time)), as.POSIXct(clock_sys_time, tz = "UTC"))
    expect_equal(
      as.POSIXct(as.vector(pl_sys_time), tz = "Asia/Kolkata"),
      as.POSIXct(clock_sys_time, tz = "Asia/Kolkata")
    )

    # Test on other time zone
    withr::with_timezone(
      "Europe/Paris",
      {
        expect_equal(as.POSIXct(as.vector(pl_naive_time)), as.POSIXct(clock_naive_time))
        expect_equal(as.POSIXct(as.vector(pl_zoned_time_1)), as.POSIXct(clock_zoned_time_1))
        expect_equal(as.POSIXct(as.vector(pl_sys_time)), as.POSIXct(clock_sys_time, tz = "UTC"))
        expect_equal(
          as.POSIXct(as.vector(pl_sys_time), tz = "Asia/Kolkata"),
          as.POSIXct(clock_sys_time, tz = "Asia/Kolkata")
        )
      }
    )
  },
  precision = c("nanosecond", "microsecond", "millisecond", "second", "minute", "hour", "day"),
  .test_name = precision
)


test_that("clock_zoned_time may returns empty time zone", {
  skip_if_not_installed("clock")

  expect_s3_class(as_polars_series(clock::zoned_time_now(zone = "")), "RPolarsSeries")
})


test_that("as_polars_series for nested type", {
  expect_true(
    as_polars_series(list(list(data.frame(a = 1))))$dtype == pl$List(pl$List(pl$Struct(a = pl$Float64)))
  )
  expect_true(
    as_polars_series(
      list(data.frame(a = I(list(data.frame(b = 1L)))))
    )$dtype == pl$List(pl$Struct(a = pl$List(pl$Struct(b = pl$Int32))))
  )
  expect_true(
    as_polars_series(list(as_polars_series(NULL), as_polars_series(1L)))$dtype == pl$List(pl$Int32)
  )
  expect_true(
    as_polars_series(list(NULL, list(1, 2)))$equals(
      as_polars_series(list(list(), list(1, 2)))
    )
  )
  expect_true(
    as_polars_series(list(as_polars_series(NULL), list(1, 2)))$equals(
      as_polars_series(list(list(), list(1, 2)))
    )
  )
})


test_that("as_polars_df and pl$DataFrame for data.frame has list column", {
  data = data.frame(a = I(list(data.frame(b = 1L))))
  expect_true(
    as_polars_df(data)$equals(
      suppressWarnings(pl$DataFrame(data))
    )
  )
  expect_true(
    as_polars_df(data)$dtypes[[1]] == pl$List(pl$Struct(b = pl$Int32))
  )
})


# TODO: This behavior is bug or intended? (upstream)
# If this is a bug, this behavior may be changed in the future.
test_that("automatically rechunked for struct array stream from C stream interface", {
  skip_if_not_installed("nanoarrow")

  s_int_exp = nanoarrow::basic_array_stream(
    list(
      nanoarrow::as_nanoarrow_array(1:5),
      nanoarrow::as_nanoarrow_array(6:10)
    )
  ) |>
    as_polars_series(experimental = TRUE)

  s_struct_exp = nanoarrow::basic_array_stream(
    list(
      nanoarrow::as_nanoarrow_array(mtcars[1:5, ]),
      nanoarrow::as_nanoarrow_array(mtcars[6:10, ])
    )
  ) |>
    as_polars_series(experimental = TRUE)

  s_struct_stable = nanoarrow::basic_array_stream(
    list(
      nanoarrow::as_nanoarrow_array(mtcars[1:5, ]),
      nanoarrow::as_nanoarrow_array(mtcars[6:10, ])
    )
  ) |>
    as_polars_series()

  expect_identical(s_int_exp$n_chunks(), 2)
  expect_identical(s_struct_exp$n_chunks(), 2)
  expect_identical(s_struct_stable$n_chunks(), 2)
})


make_as_polars_df_experimental_cases = function() {
  skip_if_not_installed("arrow")
  skip_if_not_installed("nanoarrow")

  tibble::tribble(
    ~.test_name, ~x,
    "arrow Table", arrow::as_arrow_table(test_df),
    "arrow RecordBatch", arrow::as_record_batch(test_df),
    "arrow RecordBatchReader", arrow::as_record_batch_reader(test_df),
    "nanoarrow_array_stream", nanoarrow::as_nanoarrow_array_stream(test_df),
  )
}

patrick::with_parameters_test_that(
  "as_polars_df S3 methods with experimental option",
  {
    pl_df = as_polars_df(x, experimental = TRUE)
    expect_s3_class(pl_df, "RPolarsDataFrame")

    expect_equal(as.data.frame(pl_df), as.data.frame(as_polars_df(test_df)))
  },
  .cases = make_as_polars_df_experimental_cases()
)


test_that("as_polars_df works for nanoarrow_array with zero rows", {
  skip_if_not_installed("nanoarrow")
  orig = data.frame(col1 = character(0), col2 = numeric(0))
  out = nanoarrow::as_nanoarrow_array(orig) |>
    as_polars_df() |>
    as.data.frame()
  expect_identical(out, orig)
  expect_identical(lapply(out, class), list(col1 = "character", col2 = "numeric"))
})
