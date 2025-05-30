test_that("plain scan read parquet", {
  tmpf = tempfile()
  on.exit(unlink(tmpf))
  lf_exp = as_polars_lf(mtcars)
  lf_exp$sink_parquet(tmpf, compression = "snappy")
  df_exp = lf_exp$collect()$to_data_frame()

  # simple scan
  expect_identical(
    pl$scan_parquet(tmpf)$collect()$to_data_frame(),
    df_exp
  )

  # simple read
  expect_identical(
    pl$read_parquet(tmpf)$to_data_frame(),
    df_exp
  )
})


test_that("scan read parquet - test arg row_index", {
  tmpf = tempfile()
  on.exit(unlink(tmpf))
  lf_exp = as_polars_lf(mtcars)
  lf_exp$sink_parquet(tmpf, compression = "snappy")
  df_exp = lf_exp$collect()$to_data_frame()

  expect_identical(
    pl$scan_parquet(tmpf, row_index_name = "rc", row_index_offset = 5)$collect()$to_data_frame(),
    data.frame(rc = as.numeric(5:36), df_exp)
  )

  expect_identical(
    pl$read_parquet(tmpf, row_index_name = "rc", row_index_offset = 5)$to_data_frame(),
    data.frame(rc = as.numeric(5:36), df_exp)
  )
})


test_that("scan read parquet - parallel strategies", {
  tmpf = tempfile()
  on.exit(unlink(tmpf))
  lf_exp = as_polars_lf(mtcars)
  lf_exp$sink_parquet(tmpf, compression = "snappy")
  df_exp = lf_exp$collect()$to_data_frame()

  # check all parallel strategies produce same result
  for (choice in c("auto", "columns", "none", "row_groups", "prefiltered")) {
    expect_identical(
      pl$read_parquet(tmpf, parallel = choice)$to_data_frame(),
      df_exp
    )
  }

  # bad parallel args
  expect_grepl_error(
    pl$read_parquet(tmpf, parallel = "34"),
    "must be one of 'auto', 'columns', 'row_groups', 'prefiltered', 'none'"
  )
  expect_grepl_error(
    pl$read_parquet(tmpf, parallel = 42),
    "input is not a character vector"
  )
})

test_that("scanning from hive partition works", {
  skip_if_not_installed("withr")
  temp_dir = withr::local_tempdir()
  as_polars_df(mtcars)$write_parquet(temp_dir, partition_by = c("cyl", "gear"))

  # Passing a directory automatically enables hive partitioning reading
  # i.e. "cyl" and "gear" are in the data and the data is sorted by the
  # partitioning columns
  expect_identical(
    pl$scan_parquet(temp_dir)$select("mpg", "gear")$collect() |> as.data.frame(),
    mtcars[order(mtcars$cyl, mtcars$gear), c("mpg", "gear")],
    ignore_attr = TRUE
  )

  # TODO: uncomment when https://github.com/pola-rs/polars/issues/18293 is resolved

  # hive_partitioning controls whether partitioning columns are included
  # expect_identical(
  #   pl$scan_parquet(temp_dir, hive_partitioning = FALSE)$collect() |> dim(),
  #   c(32L, 9L)
  # )

  # TODO: uncomment when https://github.com/pola-rs/polars/issues/18294 is resolved

  # can use hive_schema for more fine grained control on partitioning columns
  # sch = pl$scan_parquet(temp_dir, hive_schema = list(cyl = pl$String, gear = pl$Int32))$
  #   collect()$schema
  # expect_true(sch$gear$is_integer())
  # expect_true(sch$cyl$is_string())
  expect_grepl_error(
    pl$scan_parquet(temp_dir, hive_schema = list(cyl = "a"))
  )

  # cannot get a subset of partitioning columns
  expect_grepl_error(
    pl$scan_parquet(temp_dir, hive_schema = list(cyl = pl$String))$collect(),
    r"(path contains column not present in the given Hive schema: "gear")"
  )
})

test_that("try_parse_hive_dates works", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")
  temp_dir = withr::local_tempdir()
  test = data.frame(dt = as.Date(c("2020-01-01", "2020-01-01", "2020-01-02")), y = 1:3)
  arrow::write_dataset(
    test,
    temp_dir,
    partitioning = "dt",
    format = "parquet",
    hive_style = TRUE
  )

  # default is to parse dates
  expect_identical(
    pl$scan_parquet(temp_dir)$select("dt")$collect()$to_list(),
    list(dt = as.Date(c("2020-01-01", "2020-01-01", "2020-01-02")))
  )

  expect_identical(
    pl$scan_parquet(temp_dir, try_parse_hive_dates = FALSE)$select("dt")$collect()$to_list(),
    list(dt = c("2020-01-01", "2020-01-01", "2020-01-02"))
  )
})

test_that("scan_parquet can include file path", {
  skip_if_not_installed("withr")
  temp_dir = withr::local_tempdir()
  as_polars_df(mtcars)$write_parquet(temp_dir, partition_by = c("cyl", "gear"))

  # There are 8 partitions so 8 file paths
  expect_identical(
    pl$scan_parquet(temp_dir, include_file_paths = "file_paths")$collect()$unique("file_paths") |>
      dim(),
    c(8L, 12L)
  )
})


test_that("write_parquet works", {
  tmpf = tempfile()
  on.exit(unlink(tmpf))
  df_exp = as_polars_df(mtcars)
  df_exp$write_parquet(tmpf)

  expect_identical(
    pl$read_parquet(tmpf)$to_data_frame(),
    mtcars,
    ignore_attr = TRUE
  )
})

test_that("throw error if invalid compression is passed", {
  tmpf = tempfile()
  on.exit(unlink(tmpf))
  df_exp = as_polars_df(mtcars)
  expect_grepl_error(
    df_exp$write_parquet(tmpf, compression = "invalid"),
    "Failed to set parquet compression method"
  )
})

test_that("write_parquet returns the input data", {
  dat = as_polars_df(mtcars)
  tmpf = tempfile()
  x = dat$write_parquet(tmpf)
  expect_identical(x$to_list(), dat$to_list())
})

test_that("write_parquet: argument 'statistics'", {
  dat = as_polars_df(mtcars)
  tmpf = tempfile()
  on.exit(unlink(tmpf))

  expect_silent(dat$write_parquet(tmpf, statistics = TRUE))
  expect_silent(dat$write_parquet(tmpf, statistics = FALSE))
  expect_silent(dat$write_parquet(tmpf, statistics = "full"))
  expect_grepl_error(
    dat$write_parquet(tmpf, statistics = list(null_count = FALSE)),
    "File out of specification: null count of a page is required"
  )
  expect_grepl_error(
    dat$write_parquet(tmpf, statistics = list(foo = TRUE, foo2 = FALSE)),
    "In `statistics`, `foo`, `foo2` are not valid keys"
  )
  expect_grepl_error(
    dat$write_parquet(tmpf, statistics = "foo"),
    "`statistics` must be TRUE/FALSE, 'full', or a named list."
  )
  expect_grepl_error(
    dat$write_parquet(tmpf, statistics = c(max = TRUE, min = FALSE)),
    "`statistics` must be of length 1."
  )
})

test_that("write_parquet can create a hive partition", {
  skip_if_not_installed("withr")
  temp_dir = withr::local_tempdir()
  dat = as_polars_df(mtcars)
  on.exit(unlink(temp_dir))

  # basic
  dat$write_parquet(temp_dir, partition_by = c("gear", "cyl"))
  expect_equal(
    list.files(temp_dir, recursive = TRUE),
    c(
      "gear=3.0/cyl=4.0/00000000.parquet", "gear=3.0/cyl=6.0/00000000.parquet",
      "gear=3.0/cyl=8.0/00000000.parquet", "gear=4.0/cyl=4.0/00000000.parquet",
      "gear=4.0/cyl=6.0/00000000.parquet", "gear=5.0/cyl=4.0/00000000.parquet",
      "gear=5.0/cyl=6.0/00000000.parquet", "gear=5.0/cyl=8.0/00000000.parquet"
    )
  )

  # works fine with integers
  temp_dir = withr::local_tempdir()
  dat2 = dat$with_columns(pl$col("gear")$cast(pl$Int32), pl$col("cyl")$cast(pl$Int32))
  dat2$write_parquet(temp_dir, partition_by = c("gear", "cyl"))
  expect_equal(
    list.files(temp_dir, recursive = TRUE),
    c(
      "gear=3/cyl=4/00000000.parquet", "gear=3/cyl=6/00000000.parquet",
      "gear=3/cyl=8/00000000.parquet", "gear=4/cyl=4/00000000.parquet",
      "gear=4/cyl=6/00000000.parquet", "gear=5/cyl=4/00000000.parquet",
      "gear=5/cyl=6/00000000.parquet", "gear=5/cyl=8/00000000.parquet"
    )
  )

  # check inputs
  expect_grepl_error(
    dat$write_parquet(temp_dir, partition_by = "foo"),
    r"("foo" not found)"
  )
  expect_grepl_error(
    dat$write_parquet(temp_dir, partition_by = ""),
    r"("" not found)"
  )
  expect_grepl_error(dat$write_parquet(temp_dir, partition_by = 1))
})

test_that("polars and arrow create the same hive partition", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")

  # arrow
  temp_dir_arrow = withr::local_tempdir()
  dat = mtcars
  on.exit(unlink(temp_dir_arrow))
  arrow::write_dataset(
    dat,
    temp_dir_arrow,
    partitioning = c("cyl", "gear"),
    format = "parquet",
    hive_style = TRUE
  )

  # polars
  temp_dir_polars = withr::local_tempdir()
  dat2 = as_polars_df(mtcars)$
    with_columns(pl$col("gear")$cast(pl$Int32), pl$col("cyl")$cast(pl$Int32))
  on.exit(unlink(temp_dir_polars))
  dat2$write_parquet(temp_dir_polars, partition_by = c("cyl", "gear"))

  # check dirnames because filenames are different between the two
  expect_identical(
    dirname(list.files(temp_dir_arrow, recursive = TRUE)),
    dirname(list.files(temp_dir_polars, recursive = TRUE))
  )
})
