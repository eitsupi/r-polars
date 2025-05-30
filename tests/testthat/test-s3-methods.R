make_cases = function() {
  tibble::tribble(
    ~.test_name, ~pola, ~base,
    "mean", "mean", mean,
    "median", "median", stats::median,
    "min", "min", min,
    "max", "max", max,
    "sum", "sum", sum,
  )
}
patrick::with_parameters_test_that("aggregations",
  {
    d = as_polars_df(mtcars)
    w = d[[pola]]()$to_data_frame()
    x = base(d)$to_data_frame()
    y = base(d$lazy())$collect()$to_data_frame()
    z = data.frame(t(sapply(mtcars, base)))
    expect_equal(w, x, ignore_attr = TRUE)
    expect_equal(w, y, ignore_attr = TRUE)
    expect_equal(w, z, ignore_attr = TRUE)
  },
  .cases = make_cases()
)


make_cases = function() {
  tibble::tribble(
    ~.test_name, ~FUN,
    "head", head,
    "tail", tail,
    "nrow", nrow,
    "ncol", ncol,
    "length", length,
    "as.matrix", as.matrix,
    "names", names,
  )
}
patrick::with_parameters_test_that("inspection",
  {
    d = as_polars_df(mtcars)
    x = FUN(mtcars)
    y = FUN(d)
    if (inherits(y, "RPolarsDataFrame")) y = y$to_data_frame()
    expect_equal(x, y, ignore_attr = TRUE)
    if (.test_name == "as.matrix") {
      z = FUN(d$lazy())
      expect_equal(x, z, ignore_attr = TRUE)
    } else if (!.test_name %in% c("length", "nrow", "ncol", "names")) {
      z = FUN(d$lazy())$collect()$to_data_frame()
      expect_equal(x, z, ignore_attr = TRUE)
    }
  },
  .cases = make_cases()
)

patrick::with_parameters_test_that("dimnames",
  {
    df_r = mtcars |>
      `rownames<-`(NULL) # Drop row names
    df_pl = as_polars_df(mtcars)

    expect_equal(.fn(df_r), .fn(df_pl))
  },
  .fn = c(dimnames, colnames, rownames, row.names, names),
  .interpret_glue = FALSE
)

make_cases = function() {
  tibble::tribble(
    ~.test_name, ~pola, ~base,
    "length", "len", length,
    "min", "min", min,
    "max", "max", max,
    "sum", "sum", sum,
  )
}
patrick::with_parameters_test_that("RPolarsSeries",
  {
    d = as_polars_series(mtcars$mpg)
    x = base(mtcars$mpg)
    y = base(d)
    z = d[[pola]]()
    if (inherits(y, "RPolarsSeries")) y = y$to_vector()
    if (inherits(z, "RPolarsSeries")) z = z$to_vector()
    expect_equal(x, y, ignore_attr = TRUE)
    expect_equal(x, z, ignore_attr = TRUE)
  },
  .cases = make_cases()
)

vecs_to_test = list(
  letters,
  1:10,
  as.double(1:10),
  c("foo" = "bar"),
  c(TRUE, FALSE),
  as.factor(letters),
  c("foooo", "barrrrr")
)

patrick::with_parameters_test_that("Series as.vector",
  {
    expect_equal(as.vector(as_polars_series(v)), v, ignore_attr = TRUE)
  },
  v = vecs_to_test
)

patrick::with_parameters_test_that("Series as.character",
  {
    expect_equal(as.character(as_polars_series(v)), as.character(v), ignore_attr = TRUE)
    expect_snapshot(as.character(as_polars_series(v)), cran = TRUE)
    expect_snapshot(as.character(as_polars_series(v), str_length = 15), cran = TRUE)
    expect_snapshot(as.character(as_polars_series(v), str_length = 2), cran = TRUE)
  },
  v = vecs_to_test
)

test_that("drop_nulls", {
  tmp = mtcars
  tmp[1:3, "mpg"] = NA
  tmp[4, "hp"] = NA
  d = as_polars_df(tmp)
  dl = as_polars_df(tmp)$lazy()
  expect_equal(nrow(na.omit(d)), 28)
  expect_equal(nrow(na.omit(d, subset = "hp")), 31)
  expect_equal(nrow(na.omit(d, subset = c("mpg", "hp"))), 28)
  expect_grepl_error(
    na.omit(d, "bad")$collect(),
    "not found: unable to find column \"bad\""
  )
  expect_equal(nrow(na.omit(dl)$collect()), 28)
  expect_equal(nrow(na.omit(dl, subset = "hp")$collect()), 31)
  expect_equal(nrow(na.omit(dl, subset = c("mpg", "hp"))$collect()), 28)
  expect_grepl_error(
    na.omit(dl, "bad")$collect(),
    "not found: unable to find column \"bad\""
  )
})


test_that("unique", {
  df = pl$DataFrame(
    x = as.numeric(c(1, 1:5)),
    y = as.numeric(c(1, 1:5)),
    z = as.numeric(c(1, 1, 1:4))
  )
  expect_equal(unique(df)$height, 5)
  expect_equal(unique(df, subset = "z")$height, 4)
  df = pl$DataFrame(
    x = as.numeric(c(1, 1:5)),
    y = as.numeric(c(1, 1:5)),
    z = as.numeric(c(1, 1, 1:4))
  )$lazy()
  expect_equal(unique(df)$collect()$height, 5)
  expect_equal(unique(df, subset = "z")$collect()$height, 4)
})

test_that("brackets", {
  # informative errors
  df = as_polars_df(mtcars)

  expect_grepl_error(df[, "bad"], regexp = "not found")
  expect_grepl_error(df[c(1, 4, 3), ], regexp = "increasing order")
  expect_grepl_error(df[, rep(TRUE, 50)], regexp = "length 11")
  expect_grepl_error(df[, 1:32], regexp = "less than")
  expect_grepl_error(df[, mtcars], regexp = "atomic vector")

  # eager

  # Converted to Series automatically
  a = df[, "mpg"]$to_r()
  b = mtcars[, "mpg"]
  expect_equal(a, b)

  a = df[, c("mpg", "hp")]$to_data_frame()
  b = mtcars[, c("mpg", "hp")]
  expect_equal(a, b, ignore_attr = TRUE)

  a = df[, c("hp", "mpg")]$to_data_frame()
  b = mtcars[, c("hp", "mpg")]
  expect_equal(a, b, ignore_attr = TRUE)

  idx = rep(FALSE, ncol(mtcars))
  idx[c(1, 3, 6, 9)] = TRUE
  a = df[, idx]$to_data_frame()
  b = mtcars[, idx]
  expect_equal(a, b, ignore_attr = TRUE)

  a = df[, c(1, 4, 2)]$to_data_frame()
  b = mtcars[, c(1, 4, 2)]
  expect_equal(a, b, ignore_attr = TRUE)

  idx = rep(FALSE, nrow(mtcars))
  idx[c(1, 3, 6, 9)] = TRUE
  a = df[idx, 1:3]$to_data_frame()
  b = mtcars[idx, 1:3]
  expect_equal(a, b, ignore_attr = TRUE)

  a = df[3:7, 1:3]$to_data_frame()
  b = mtcars[3:7, 1:3]
  expect_equal(a, b, ignore_attr = TRUE)

  expect_equal(df[, "cyl"]$to_vector(), mtcars[, "cyl"])
  expect_equal(df[, 1]$to_vector(), mtcars[, 1])
  expect_equal(df[1:5, 1]$to_vector(), mtcars[1:5, 1])

  expect_equal(df[, "cyl", drop = FALSE]$to_data_frame(), mtcars[, "cyl", drop = FALSE], ignore_attr = TRUE)
  expect_equal(df["cyl"]$to_data_frame(), mtcars["cyl"], ignore_attr = TRUE)
  expect_equal(df[1:3]$to_data_frame(), mtcars[1:3], ignore_attr = TRUE)
  expect_equal(df[NULL, ]$to_data_frame(), mtcars[NULL, ], ignore_attr = TRUE)
  expect_equal(
    df[pl$col("cyl") >= 8, c("disp", "mpg")]$to_data_frame(),
    mtcars[mtcars$cyl >= 8, c("disp", "mpg")],
    ignore_attr = TRUE
  )

  df = as_polars_df(mtcars)
  a = mtcars[-(1:2), -c(1, 3, 6, 9)]
  b = df[-(1:2), -c(1, 3, 6, 9)]$to_data_frame()
  expect_equal(a, b, ignore_attr = TRUE)

  # lazy
  lf = as_polars_df(mtcars)$lazy()

  a = lf[, c("mpg", "hp")]$collect()$to_data_frame()
  b = mtcars[, c("mpg", "hp")]
  expect_equal(a, b, ignore_attr = TRUE)

  a = lf[, c("hp", "mpg")]$collect()$to_data_frame()
  b = mtcars[, c("hp", "mpg")]
  expect_equal(a, b, ignore_attr = TRUE)

  a = lf[c("hp", "mpg")]$collect()$to_data_frame()
  b = mtcars[c("hp", "mpg")]
  expect_equal(a, b, ignore_attr = TRUE)

  idx = rep(FALSE, ncol(mtcars))
  idx[c(1, 3, 6, 9)] = TRUE
  a = lf[, idx]$collect()$to_data_frame()
  b = mtcars[, idx]
  expect_equal(a, b, ignore_attr = TRUE)

  a = lf[, c(1, 4, 2)]$collect()$to_data_frame()
  b = mtcars[, c(1, 4, 2)]
  expect_equal(a, b, ignore_attr = TRUE)

  expect_equal(
    lf[pl$col("cyl") >= 8, c("disp", "mpg")]$collect()$to_data_frame(),
    mtcars[mtcars$cyl >= 8, c("disp", "mpg")],
    ignore_attr = TRUE
  )

  # Not supported for lazy
  expect_grepl_error(lf[1:3, ], "not supported")
  expect_grepl_error(lf[, "cyl"], "not supported")

  # Test for drop = FALSE
  expect_equal(
    lf[, "cyl", drop = FALSE]$collect()$to_data_frame(),
    mtcars[, "cyl", drop = FALSE],
    ignore_attr = TRUE
  )

  # Series
  expect_equal(as_polars_series(letters)[1:5]$to_vector(), letters[1:5])
  expect_equal(as_polars_series(letters)[-5]$to_vector(), letters[-5])
})


test_that("dim should integer", {
  d = dim(as_polars_df(mtcars))
  expect_identical(d, dim(mtcars))
  expect_true(is.integer(d))

  d = dim(as_polars_lf(mtcars))
  expect_identical(d, c(NA_integer_, ncol(mtcars)))
  expect_true(is.integer(d))
})
