// b_Kn_oipcpi_eu_km.stan

data {
  // Metabolism distributions
  real GPP_daily_mu;
  real GPP_daily_sigma;
  real ER_daily_mu;
  real ER_daily_sigma;
  
  // Hierarchical constraints on K600_daily (normal model)
  real K600_daily_mu_mu;
  real K600_daily_mu_sigma;
  real K600_daily_sigma_shape;
  real K600_daily_sigma_rate;
  
  // Error distributions
  real err_obs_iid_sigma_shape;
  real err_obs_iid_sigma_rate;
  real err_proc_acor_phi_shape;
  real err_proc_acor_phi_rate;
  real err_proc_acor_sigma_shape;
  real err_proc_acor_sigma_rate;
  real err_proc_iid_sigma_shape;
  real err_proc_iid_sigma_rate;
  
  // Data dimensions
  int<lower=1> d; # number of dates
  int<lower=1> n; # number of observations per date
  
  // Daily data
  vector[d] DO_obs_1;
  
  // Data
  vector[d] DO_obs[n];
  vector[d] DO_sat[n];
  vector[d] frac_GPP[n];
  vector[d] frac_ER[n];
  vector[d] frac_D[n];
  vector[d] depth[n];
  vector[d] KO2_conv[n];
}

transformed data {
  vector[d] coef_GPP[n-1];
  vector[d] coef_ER[n-1];
  vector[d] coef_K600_part[n-1];
  
  for(i in 1:(n-1)) {
    // Coefficients by lag (e.g., frac_GPP[i] applies to the DO step from i to i+1)
    coef_GPP[i]  <- frac_GPP[i] ./ depth[i];
    coef_ER[i]   <- frac_ER[i] ./ depth[i];
    coef_K600_part[i] <- KO2_conv[i] .* frac_D[i];
  }
}

parameters {
  vector[d] GPP_daily;
  vector[d] ER_daily;
  vector[d] K600_daily;
  
  real K600_daily_mu;
  real K600_daily_sigma;
  
  vector[d] err_proc_iid[n-1];
  vector[d] err_proc_acor_inc[n-1];
  
  real err_obs_iid_sigma;
  real err_proc_acor_phi;
  real err_proc_acor_sigma;
  real err_proc_iid_sigma;
}

transformed parameters {
  vector[d] DO_mod[n];
  vector[d] err_proc_acor[n-1];
  
  // Model DO time series
  // * Euler version
  // * observation error
  // * IID and autocorrelated process error
  // * reaeration depends on DO_mod
  
  err_proc_acor[1] <- err_proc_acor_inc[1];
  for(i in 1:(n-2)) {
    err_proc_acor[i+1] <- err_proc_acor_phi * err_proc_acor[i] + err_proc_acor_inc[i+1];
  }
  
  // DO model
  DO_mod[1] <- DO_obs_1;
  for(i in 1:(n-1)) {
    DO_mod[i+1] <- (
      DO_mod[i] +
      err_proc_iid[i] +
      err_proc_acor[i] +
      GPP_daily .* coef_GPP[i] +
      ER_daily .* coef_ER[i] +
      K600_daily .* coef_K600_part[i] .* (DO_sat[i] - DO_mod[i])
    );
  }
}

model {
  // Independent, identically distributed process error
  for(i in 1:(n-1)) {
    err_proc_iid[i] ~ normal(0, err_proc_iid_sigma);
  }
  // SD (sigma) of the IID process errors
  err_proc_iid_sigma ~ gamma(err_proc_iid_sigma_shape, err_proc_iid_sigma_rate);
  
  // Autocorrelated process error
  for(i in 1:(n-1)) {
    err_proc_acor_inc[i] ~ normal(0, err_proc_acor_sigma);
  }
  // Autocorrelation (phi) & SD (sigma) of the process errors
  err_proc_acor_phi ~ gamma(err_proc_acor_phi_shape, err_proc_acor_phi_rate);
  err_proc_acor_sigma ~ gamma(err_proc_acor_sigma_shape, err_proc_acor_sigma_rate);
  
  // Independent, identically distributed observation error
  for(i in 1:n) {
    DO_obs[i] ~ normal(DO_mod[i], err_obs_iid_sigma);
  }
  // SD (sigma) of the observation errors
  err_obs_iid_sigma ~ gamma(err_obs_iid_sigma_shape, err_obs_iid_sigma_rate);
  
  // Daily metabolism values
  GPP_daily ~ normal(GPP_daily_mu, GPP_daily_sigma);
  ER_daily ~ normal(ER_daily_mu, ER_daily_sigma);
  K600_daily ~ normal(K600_daily_mu, K600_daily_sigma);

  // Hierarchical constraints on K600_daily (normal model)
  K600_daily_mu ~ normal(K600_daily_mu_mu, K600_daily_mu_sigma);
  K600_daily_sigma ~ gamma(K600_daily_sigma_shape, K600_daily_sigma_rate);
}