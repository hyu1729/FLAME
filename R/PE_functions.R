# Some hard-coded parameter values to cross-validate XGBoost over
# If the user cares about this they'll just input their own PE function.
cv_xgboost <- function(X, Y, obj) {
  # Return the best XGBoost fit for Y ~ X across various parameter configurations
  eta <- c(0.01, 0.05, 0.1, 0.2, 0.3, 0.5)
  max_depth <- c(2, 3, 4, 6, 8)
  alpha <- c(0.01, 0.1, 0.5, 1, 5)
  nrounds <- c(5, 10, 50, 200, 500)
  subsample <- c(0.1, 0.3, 0.5, 0.75, 1)

  param_combs <-
    expand.grid(eta, max_depth, alpha, nrounds, subsample)

  colnames(param_combs) <-
    c('eta', 'max_depth', 'alpha', 'nrounds', 'subsample')

  error <- vector(mode = 'numeric', length = length(param_combs))

  for (i in 1:length(param_combs)) {
    params <- list(objective = obj,
                   eta = param_combs$eta[i],
                   max_depth = param_combs$max_depth[i],
                   alpha = param_combs$alpha[i],
                   subsample = param_combs$subsample[i])
    if (obj == 'multi:softmax') {
      params <- c(params, list(num_class = length(unique(Y))))
    }
    cv <-
      xgboost::xgb.cv(data = X,
                      label = Y,
                      params = params,
                      nrounds = param_combs$nrounds[i],
                      nfold = 5, verbose = 0)

    error[i] <- cv$evaluation_log[param_combs$nrounds[i], 4]
  }

  best_params <- param_combs[which.min(error), ]
  params <- c(best_params, list(objective = obj))
  if (obj == 'multi:softmax') {
    params <- c(params, list(num_class = length(unique(Y))))
  }
  fit <- xgboost::xgboost(data = X,
                  label = Y,
                  params = params,
                  nround = best_params$nrounds,
                  verbose = 0)

  return(fit)
}

setup_preds <- function(holdout, covs, cov_to_drop) {
  # Split the data into treat, control
  # The model.matrix function binarizes categorical covariates
  n_cols <- ncol(holdout)
  covs_to_test <- setdiff(covs, cov_to_drop)

  Y_treat <- holdout$outcome[holdout$treated == 1]
  Y_control <- holdout$outcome[holdout$treated == 0]

  covs_treat <- holdout[holdout$treated == 1, c(covs_to_test, n_cols - 1)]

  X_treat <- model.matrix(outcome ~ ., covs_treat)

  covs_control <- holdout[holdout$treated == 0, c(covs_to_test, n_cols - 1)]

  X_control <- model.matrix(outcome ~ ., covs_control)

  return(list(X_treat = X_treat,
              X_control = X_control,
              Y_treat = Y_treat,
              Y_control = Y_control))
}

get_error <- function(X, Y, fit_fun, predict_fun, fit_params, predict_params) {

  if (length(unique(Y)) == 2) {
    outcome_type <- 'binary'
  }
  else if (is.factor(Y)) {
    outcome_type <- 'multiclass'
  }
  else {
    outcome_type <- 'continuous'
  }
#####  should compute obj and family here so as not to do it in get_PE
  # actually don't think you can because the arg names are dif. for xgboost
  # could get around this by introducing nfolds argument in xgboost and calling
  # obj family, but will think / leave for later
  if (is.factor(Y)) {
    Y <- as.numeric(Y) - 1
  }

  fit <- do.call(fit_fun, c(list(X, Y), fit_params))

  preds <- as.numeric(do.call(predict_fun, c(list(fit, X), predict_params)))

  if (outcome_type == 'binary') {
    preds <- preds > 0.5 # to take care of xgboost
  }

  if (outcome_type != 'continuous') {
    error <- mean(preds != Y)
  }
  else {
    error <- mean((preds - Y) ^ 2)
  }

  return(error)
}

predict_master <-
  function(holdout, covs, cov_to_drop,
           PE_fit, PE_predict, PE_fit_params, PE_predict_params) {

  n_imputations <- length(holdout) # List of dataframes

  PE <- vector(mode = 'numeric', length = n_imputations)

  for (i in 1:n_imputations) {
    setup_out <- setup_preds(holdout[[i]], covs, cov_to_drop)
    X_treat <- setup_out[[1]]
    X_control <- setup_out[[2]]
    Y_treat <- setup_out[[3]]
    Y_control <- setup_out[[4]]

    error_treat <-
      get_error(X_treat, Y_treat,
              PE_fit, PE_predict, PE_fit_params, PE_predict_params)

    error_control <-
      get_error(X_control, Y_control,
              PE_fit, PE_predict, PE_fit_params, PE_predict_params)

    PE[i] <- error_treat + error_control
  }
  return(mean(PE))
}
