
library(testthat)
source("scripts/helpers.R")

test_that("starts_with_any funciona", {
  expect_true(starts_with_any("ABC", c("A","Z")))
  expect_false(starts_with_any("XYZ", c("A","B")))
})

test_that("derive_ano cria coluna ano quando existe DT_INTER", {
  df <- data.frame(DT_INTER = "2020-05-01")
  out <- derive_ano(df)
  expect_equal(out$ano, 2020)
})

