### group_by ------------------------------------------------

df = pl$DataFrame(
  foo = c("one", "two", "two", "one", "two"),
  bar = c(5, 3, 2, 4, 1)
)

gb = df$group_by("foo", maintain_order = TRUE)

test_that("$group_by() with list literal", {
  expect_identical(
    gb$agg(x = list(c(1, 2, 3)))$to_list(),
    list(
      foo = c("one", "two"),
      x = rep(list(c(1, 2, 3)), 2)
    )
  )
})

test_that("groupby", {
  df2 = gb$agg(
    pl$col("bar")$sum()$alias("bar_sum"),
    pl$col("bar")$mean()$alias("bar_tail_sum")
  )$to_data_frame()

  expect_equal(
    df2,
    data.frame(foo = c("one", "two"), bar_sum = c(9, 6), bar_tail_sum = c(4.5, 2))
  )
})


patrick::with_parameters_test_that("groupby print",
  {
    .env_var = .value
    names(.env_var) = .name
    withr::with_envvar(.env_var, expect_snapshot(gb))
  },
  .cases = make_print_cases()
)

test_that("groupby print when several groups", {
  df = as_polars_df(mtcars[1:3, 1:4])$group_by("mpg", "cyl", "disp", maintain_order = TRUE)
  expect_snapshot(df)
})

make_cases = function() {
  tibble::tribble(
    ~.test_name, ~pola, ~base,
    "max", "max", max,
    "mean", "mean", mean,
    "median", "median", median,
    "max", "max", max,
    "min", "min", min,
    "std", "std", sd,
    "sum", "sum", sum,
    "var", "var", var,
    "first", "first", function(x) head(x, 1),
    "last", "last", function(x) tail(x, 1)
  )
}

patrick::with_parameters_test_that(
  "simple translations: eager",
  {
    a = as_polars_df(mtcars)$group_by(pl$col("cyl"))$first()$to_data_frame()
    b = as.data.frame(do.call(rbind, by(mtcars, mtcars$cyl, \(x) apply(x, 2, head, 1))))
    b = b[order(b$cyl), colnames(b) != "cyl"]
    expect_equal(a[order(a$cyl), 2:ncol(a)], b, ignore_attr = TRUE)
  },
  .cases = make_cases()
)

test_that("quantile", {
  a = as_polars_df(mtcars)$group_by("cyl", maintain_order = FALSE)$quantile(0, "midpoint")$to_data_frame()
  b = as_polars_df(mtcars)$group_by("cyl", maintain_order = FALSE)$min()$to_data_frame()
  expect_equal(a[order(a$cyl), ], b[order(b$cyl), ], ignore_attr = TRUE)

  a = as_polars_df(mtcars)$group_by("cyl", maintain_order = FALSE)$quantile(1, "midpoint")$to_data_frame()
  b = as_polars_df(mtcars)$group_by("cyl", maintain_order = FALSE)$max()$to_data_frame()
  expect_equal(a[order(a$cyl), ], b[order(b$cyl), ], ignore_attr = TRUE)

  a = as_polars_df(mtcars)$group_by("cyl", maintain_order = FALSE)$quantile(0.5, "midpoint")$to_data_frame()
  b = as_polars_df(mtcars)$group_by("cyl", maintain_order = FALSE)$median()$to_data_frame()
  expect_equal(a[order(a$cyl), ], b[order(b$cyl), ], ignore_attr = TRUE)
})

test_that("shift", {
  a = as_polars_df(mtcars)$group_by("cyl")$shift(2)$to_data_frame()
  expect_equal(a[["mpg"]][[1]][1:2], c(NA_real_, NA_real_))
  a = as_polars_df(mtcars)$group_by("cyl")$shift(2, 99)$to_data_frame()
  expect_equal(a[["mpg"]][[1]][1:2], c(99, 99))
})


test_that("groupby, lazygroupby unpack + charvec same as list of strings", {
  skip_if_not_installed("withr")
  withr::with_options(
    list(polars.maintain_order = TRUE),
    {
      df = as_polars_df(mtcars)
      to_l = \(x) (if (inherits(x, "RPolarsDataFrame")) x else x$collect())$to_list()
      for (x in list(df, df$lazy())) {
        df1 = x$group_by(list("cyl", "gear"))$agg(pl$mean("hp")) # args wrapped in list
        df2 = x$group_by("cyl", "gear")$agg(pl$mean("hp")) # same as free args
        df3 = x$group_by(c("cyl", "gear"))$agg(pl$mean("hp")) # same as charvec of column names
        expect_identical(df1 |> to_l(), df2 |> to_l())
        expect_identical(df1 |> to_l(), df3 |> to_l())
      }
    }
  )
})

test_that("agg, lazygroupby unpack + charvec same as list of strings", {
  skip_if_not_installed("withr")
  withr::with_options(
    list(polars.maintain_order = TRUE),
    {
      df = as_polars_df(mtcars)
      to_l = \(x) (if (inherits(x, "RPolarsDataFrame")) x else x$collect())$to_list()
      for (x in list(df, df$lazy())) {
        df1 = x$group_by("cyl")$agg(pl$col("hp")$mean(), pl$col("gear")$mean()) # args wrapped in list
        df2 = x$group_by("cyl")$agg(list(pl$col("hp")$mean(), pl$col("gear")$mean()))
        df3 = x$group_by("cyl")$agg(pl$mean(c("hp", "gear"))) # same as charvec like this
        expect_identical(df1 |> to_l(), df2 |> to_l())
        expect_identical(df1 |> to_l(), df3 |> to_l())
      }
    }
  )
})


test_that("LazyGroupBy ungroup", {
  lf = as_polars_lf(mtcars)
  lgb = lf$group_by("cyl")

  # tests $ungroup() only changed the class of output, not input (lgb).
  lgb_ug = lgb$ungroup()
  expect_identical(class(lgb_ug), "RPolarsLazyFrame")
  expect_identical(class(lgb), "RPolarsLazyGroupBy")

  expect_equal(
    lgb$ungroup()$collect()$to_data_frame(),
    lf$collect()$to_data_frame()
  )

  expect_identical(
    attributes(lgb$ungroup()),
    attributes(lf)
  )
})

test_that("GroupBy ungroup", {
  df = as_polars_df(mtcars)
  gb = df$group_by("cyl")

  # tests $ungroup() only changed the class of output, not input (lgb).
  gb_ug = gb$ungroup()
  expect_identical(class(gb_ug), "RPolarsDataFrame")
  expect_identical(class(gb), "RPolarsGroupBy")

  expect_equal(
    gb$ungroup()$to_data_frame(),
    df$to_data_frame()
  )

  expect_identical(
    attributes(gb$ungroup()),
    attributes(df)
  )
})

test_that("LazyGroupBy clone", {
  lgb = pl$LazyFrame(a = 1:3)$group_by("a")
  lgb_copy = lgb
  lgb_clone = .pr$LazyGroupBy$clone_in_rust(lgb)
  expect_identical(class(lgb_clone), class(lgb))
  expect_true(mem_address(lgb) != mem_address(lgb_clone))
  expect_true(mem_address(lgb) == mem_address(lgb_copy))
})






### group_by_dynamic ------------------------------------------------

test_that("group_by_dynamic for DataFrame calls the LazyFrame method", {
  df = pl$DataFrame(
    dt = as.Date(as.Date("2021-12-16"):as.Date("2021-12-22"), origin = "1970-01-01"),
    n = 0:6
  )

  actual = df$group_by_dynamic(index_column = "dt", every = "2d")$agg(
    pl$col("n")$mean()
  )$to_data_frame()

  expect_equal(
    actual[, "n"],
    c(0, 1.5, 3.5, 5.5)
  )
})

test_that("group_by_dynamic for LazyFrame: date variable", {
  df = pl$LazyFrame(
    dt = as.Date(as.Date("2021-12-16"):as.Date("2021-12-22"), origin = "1970-01-01"),
    n = 0:6
  )

  actual = df$group_by_dynamic(index_column = "dt", every = "2d")$agg(
    pl$col("n")$mean()
  )$collect()$to_data_frame()

  expect_equal(
    actual[, "n"],
    c(0, 1.5, 3.5, 5.5)
  )
})

test_that("group_by_dynamic for LazyFrame: datetime variable", {
  df = pl$LazyFrame(
    dt = c(
      "2021-12-16 00:00:00", "2021-12-16 00:30:00", "2021-12-16 01:00:00",
      "2021-12-16 01:30:00", "2021-12-16 02:00:00", "2021-12-16 02:30:00",
      "2021-12-16 03:00:00"
    ),
    n = 0:6
  )$with_columns(
    pl$col("dt")$str$strptime(pl$Datetime("ms"), format = NULL)
  )

  actual = df$group_by_dynamic(index_column = "dt", every = "1h")$agg(
    pl$col("n")$mean()
  )$collect()$to_data_frame()

  expect_equal(
    actual[, "n"],
    c(0.5, 2.5, 4.5, 6)
  )
})

test_that("group_by_dynamic for LazyFrame: integer variable", {
  df = pl$LazyFrame(
    idx = 0:5,
    n = 0:5
  )

  actual = df$group_by_dynamic(
    "idx",
    every = "2i"
  )$agg(pl$col("n")$mean())$collect()$to_data_frame()

  expect_equal(
    actual[, "n"],
    c(0.5, 2.5, 4.5)
  )
})

test_that("group_by_dynamic for LazyFrame: error if every is negative", {
  df = pl$LazyFrame(
    idx = 0:5,
    n = 0:5
  )

  expect_grepl_error(
    df$group_by_dynamic("idx", every = "-2i")$agg(pl$col("n")$mean())$collect(),
    "'every' argument must be positive"
  )
})

test_that("group_by_dynamic for LazyFrame: arg 'closed' works", {
  df = pl$LazyFrame(
    dt = c(
      "2021-12-16 00:00:00", "2021-12-16 00:30:00", "2021-12-16 01:00:00",
      "2021-12-16 01:30:00", "2021-12-16 02:00:00", "2021-12-16 02:30:00",
      "2021-12-16 03:00:00"
    ),
    n = 0:6
  )$with_columns(
    pl$col("dt")$str$strptime(pl$Datetime("ms"), format = NULL)
  )

  actual = df$group_by_dynamic(index_column = "dt", closed = "right", every = "1h")$agg(
    pl$col("n")$mean()
  )$collect()$to_data_frame()

  expect_equal(
    actual[, "n"],
    c(0, 1.5, 3.5, 5.5)
  )

  expect_grepl_error(
    df$group_by_dynamic(index_column = "dt", closed = "foobar", every = "1h")$agg(
      pl$col("n")$mean()
    )$collect(),
    "must be one of"
  )
})

test_that("group_by_dynamic for LazyFrame: arg 'label' works", {
  df = pl$LazyFrame(
    dt = c(
      "2021-12-16 00:00:00", "2021-12-16 00:30:00", "2021-12-16 01:00:00",
      "2021-12-16 01:30:00", "2021-12-16 02:00:00", "2021-12-16 02:30:00",
      "2021-12-16 03:00:00"
    ),
    n = 0:6
  )$with_columns(
    pl$col("dt")$str$strptime(pl$Datetime("ms"), format = NULL)$dt$replace_time_zone("UTC")
  )

  actual = df$group_by_dynamic(index_column = "dt", label = "right", every = "1h")$agg(
    pl$col("n")$mean()
  )$collect()$to_data_frame()

  expect_equal(
    actual[, "dt"],
    as.POSIXct(
      c("2021-12-16 01:00:00", "2021-12-16 02:00:00", "2021-12-16 03:00:00", "2021-12-16 04:00:00"),
      tz = "UTC"
    )
  )

  expect_grepl_error(
    df$group_by_dynamic(index_column = "dt", label = "foobar", every = "1h")$agg(
      pl$col("n")$mean()
    )$collect(),
    "must be one of"
  )
})

test_that("group_by_dynamic for LazyFrame: arg 'start_by' works", {
  df = pl$LazyFrame(
    dt = c(
      "2021-12-16 00:00:00", "2021-12-16 00:30:00", "2021-12-16 01:00:00",
      "2021-12-16 01:30:00", "2021-12-16 02:00:00", "2021-12-16 02:30:00",
      "2021-12-16 03:00:00"
    ),
    n = 0:6
  )$with_columns(
    pl$col("dt")$str$strptime(pl$Datetime("ms", "UTC"), format = NULL)
  )

  for (i in c("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")) {
    actual = df$group_by_dynamic(index_column = "dt", start_by = i, every = "1h")$agg(
      pl$col("n")$mean()
    )$collect()$to_list()$dt

    expect_equal(
      actual,
      as.POSIXct(
        c("2021-12-16 00:00:00 UTC", "2021-12-16 01:00:00 UTC", "2021-12-16 02:00:00 UTC", "2021-12-16 03:00:00 UTC"),
        tz = "UTC"
      )
    )
  }

  expect_grepl_error(
    df$group_by_dynamic(index_column = "dt", start_by = "foobar", every = "1h")$agg(
      pl$col("n")$mean()
    )$collect(),
    "must be one of"
  )
})

test_that("group_by_dynamic for LazyFrame: argument 'by' works", {
  df = pl$LazyFrame(
    dt = c(
      "2021-12-16 00:00:00", "2021-12-16 00:30:00", "2021-12-16 01:00:00",
      "2021-12-16 01:30:00", "2021-12-16 02:00:00", "2021-12-16 02:30:00",
      "2021-12-16 03:00:00"
    ),
    n = 0:6,
    grp = c("a", "a", "a", "b", "b", "a", "a")
  )$with_columns(
    pl$col("dt")$str$strptime(pl$Datetime("ms"), format = NULL)
  )

  actual = df$group_by_dynamic(index_column = "dt", every = "2h", group_by = pl$col("grp"))$agg(
    pl$col("n")$mean()
  )$collect()$to_data_frame()

  expect_equal(
    actual[, "n"],
    c(1, 5.5, 3, 4)
  )

  # string is parsed as column name in "by"
  expect_equal(
    df$group_by_dynamic(index_column = "dt", every = "2h", group_by = pl$col("grp"))$agg(
      pl$col("n")$mean()
    )$collect()$to_data_frame(),
    df$group_by_dynamic(index_column = "dt", every = "2h", group_by = "grp")$agg(
      pl$col("n")$mean()
    )$collect()$to_data_frame()
  )
})

test_that("group_by_dynamic for LazyFrame: error if index not int or date/time", {
  df = pl$LazyFrame(
    index = c(1:5, 6.0),
    a = c(3, 7, 5, 9, 2, 1)
  )

  expect_grepl_error(
    df$group_by_dynamic(index_column = "index", every = "2i")$agg(
      pl$sum("a")$alias("sum_a")
    )$collect()
  )
})

test_that("group_by_dynamic for LazyFrame: arg 'offset' works", {
  df = pl$LazyFrame(
    dt = c(
      "2020-01-01", "2020-01-01", "2020-01-01",
      "2020-01-02", "2020-01-03", "2020-01-08"
    ),
    n = c(3, 10, 5, 9, 2, 1)
  )$with_columns(
    pl$col("dt")$str$strptime(pl$Date, format = NULL)
  )

  # checked with python-polars but unclear on how "offset" works
  actual = df$group_by_dynamic(index_column = "dt", every = "2d", offset = "1d")$agg(
    pl$col("n")$mean()
  )$collect()$to_data_frame()

  expect_equal(
    actual[, "n"],
    c(6, 5.5, 1)
  )
})

test_that("group_by_dynamic for LazyFrame: arg 'include_boundaries' works", {
  df = pl$LazyFrame(
    dt = c(
      "2020-01-01", "2020-01-01", "2020-01-01",
      "2020-01-02", "2020-01-03", "2020-01-08"
    ),
    n = c(3, 7, 5, 9, 2, 1)
  )$with_columns(
    pl$col("dt")$str$strptime(pl$Date, format = NULL)
  )

  actual = df$group_by_dynamic(
    index_column = "dt", every = "2d", offset = "1d",
    include_boundaries = TRUE
  )$
    agg(
    pl$col("n")
  )

  expect_named(actual, c("_lower_boundary", "_upper_boundary", "dt", "n"))
})

test_that("group_by_dynamic for LazyFrame: can be ungrouped", {
  df = pl$LazyFrame(
    index = c(1:5, 6.0),
    a = c(3, 7, 5, 9, 2, 1)
  )

  actual = df$group_by_dynamic(index_column = "dt", every = "2i")$
    ungroup()$
    collect()$
    to_data_frame()
  expect_equal(actual, df$collect()$to_data_frame())
})

test_that("group_by with named expr", {
  df = pl$DataFrame(a = c(rep(1, 3), rep(2, 3)), b = 1:6)

  expect_equal(
    df$group_by(group = "a")$agg(
      b = pl$col("b")$sum()
    )$sort("group") |>
      as.data.frame(),
    data.frame(group = c(1, 2), b = c(6, 15))
  )
  expect_equal(
    df$lazy()$group_by(group = "a")$agg(
      b = pl$col("b")$sum()
    )$sort("group") |>
      as.data.frame(),
    data.frame(group = c(1, 2), b = c(6, 15))
  )
})
