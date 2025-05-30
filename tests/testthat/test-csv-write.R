dat = head(mtcars, n = 15)
dat[c(1, 3, 9, 12), c(3, 4, 5)] = NA
dat_pl = as_polars_df(dat)
temp_noext = tempfile()
temp_out = tempfile(fileext = ".csv")

test_that("write_csv: path works", {
  dat_pl$write_csv(temp_out)
  expect_identical(
    pl$read_csv(temp_out)$to_data_frame(),
    dat,
    ignore_attr = TRUE # rownames are lost when writing / reading from CSV
  )
})

test_that("write_csv returns the input data", {
  x = dat_pl$write_csv(temp_out)
  expect_identical(x$to_list(), dat_pl$to_list())
})

test_that("write_csv: null_values works", {
  expect_grepl_error(
    dat_pl$write_csv(temp_out, null_values = NULL)
  )
  dat_pl$write_csv(temp_out, null_values = "hello")
  expect_snapshot_file(temp_out)
})


test_that("write_csv: separator works", {
  dat_pl$write_csv(temp_out, separator = "|")
  expect_snapshot_file(temp_out)
})

test_that("write_csv: quote_style and quote works", {
  dat_pl2 = as_polars_df(head(iris))

  # wrong quote_style
  ctx = dat_pl2$write_csv(temp_out, quote_style = "foo") |> get_err_ctx()
  expect_identical(ctx$BadArgument, "quote_style")
  expect_identical(ctx$Plain, "`quote_style` should be one of 'always', 'necessary', 'non_numeric', or 'never'.")

  # wrong quote_style type
  ctx = dat_pl2$write_csv(temp_out, quote_style = 42) |> get_err_ctx()
  expect_identical(ctx$TypeMismatch, "&str")

  # zero byte quote
  ctx = dat_pl2$write_csv(temp_out, quote_char = "") |> get_err_ctx()
  expect_identical(ctx$Plain, "cannot extract single byte from empty string")

  # multi byte quote not allowed
  ctx = dat_pl2$write_csv(temp_out, quote_char = "£") |> get_err_ctx()
  expect_identical(ctx$Plain, "multi byte-string not allowed")

  # multi string not allowed
  ctx = dat_pl2$write_csv(temp_out, quote_char = c("a", "b")) |> get_err_ctx()
  expect_identical(ctx$TypeMismatch, "&str")
})

patrick::with_parameters_test_that(
  "write_csv: quote_style",
  {
    df = pl$DataFrame(
      a = c(r"("foo")", "bar"),
      b = 1:2,
      c = letters[1:2]
    )$write_csv(temp_out, quote_style = quote_style)
    expect_snapshot_file(temp_out)
  },
  quote_style = c("necessary", "always", "non_numeric", "never")
)

test_that("write_csv: date_format works", {
  dat = pl$DataFrame(
    date = pl$date_range(
      as.Date("2020-01-01"),
      as.Date("2023-01-02"),
      interval = "1y"
    )
  )
  dat$write_csv(temp_out, date_format = "%Y")
  expect_snapshot_file(temp_out)
  dat$write_csv(temp_out, date_format = "%d/%m/%Y")
  expect_snapshot_file(temp_out)
})

test_that("write_csv: datetime_format works", {
  dat = pl$DataFrame(
    date = pl$datetime_range(
      as.Date("2020-01-01"),
      as.Date("2020-01-02"),
      interval = "6h"
    )
  )
  dat$write_csv(temp_out, datetime_format = "%Hh%Mm - %d/%m/%Y")
  expect_snapshot_file(temp_out)
})

test_that("write_csv: time_format works", {
  dat = pl$DataFrame(
    date = pl$datetime_range(
      as.Date("2020-10-17"),
      as.Date("2020-10-18"),
      "8h"
    )
  )$with_columns(pl$col("date")$dt$time())
  dat$write_csv(temp_out, time_format = "%Hh%Mm%Ss")
  expect_snapshot_file(temp_out)
})


test_that("write_csv: float_precision works", {
  dat = pl$DataFrame(x = c(1.234, 5.6))
  dat$write_csv(temp_out, float_precision = 1)
  expect_snapshot_file(temp_out)

  dat$write_csv(temp_out, float_precision = 3)
  expect_snapshot_file(temp_out)
})
