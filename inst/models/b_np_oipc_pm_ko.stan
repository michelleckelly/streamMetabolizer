// b_np_oipc_pm_ko.stan

data {
  // Metabolism distributions
  real GPP_daily_mu;
  real GPP_daily_sigma;
  real ER_daily_mu;
  real ER_daily_sigma;
  real K600_daily_mu;
  real K600_daily_sigma;
  
  // Error distributions
  real err_obs_iid_sigma_min;
  real err_obs_iid_sigma_max;
  real err_proc_acor_phi_min;
  real err_proc_acor_phi_max;
  real err_proc_acor_sigma_min;
  real err_proc_acor_sigma_max;
  
  // Overall data
  int <lower=0> d; # number of dates
  
  // Daily data
  int <lower=0> n; # number of observations per date
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
  vector[d] coef_K600_full[n-1];
  
  for(i in 1:(n-1)) {
    // Coefficients by pairmeans (e.g., mean(frac_GPP[i:(i+1)]) applies to the DO step from i to i+1)
    coef_GPP[i]  <- (frac_GPP[i] + frac_GPP[i+1])/2.0 ./ ((depth[i] + depth[i+1])/2.0);
    coef_ER[i]   <- (frac_ER[ i] + frac_ER[ i+1])/2.0 ./ ((depth[i] + depth[i+1])/2.0);
    coef_K600_full[i] <- (KO2_conv[i] + KO2_conv[i+1])/2.0 .* (frac_D[i] + frac_D[i+1])/2.0 .*
      (DO_sat[i] + DO_sat[i+1] - DO_obs[i] - DO_obs[i+1])/2.0;
  }
}

parameters {
  vector[d] GPP_daily;
  vector[d] ER_daily;
  vector[d] K600_daily;
  
  vector[d] err_proc_acor_inc[n-1];
  
  real err_obs_iid_sigma;
  real err_proc_acor_phi;
  real err_proc_acor_sigma;
}

transformed parameters {
  vector[d] DO_mod[n];
  vector[d] dDO_mod[n-1];
  vector[d] err_proc_acor[n-1];
  
  // Model DO time series
  // * pairmeans version
  // * observation error
  // * autocorrelated process error
  // * reaeration depends on DO_obs
  
  err_proc_acor[1] <- err_proc_acor_inc[1];
  for(i in 1:(n-2)) {
    err_proc_acor[i+1] <- err_proc_acor_phi * err_proc_acor[i] + err_proc_acor_inc[i+1];
  }
  
  // dDO model
  dDO_mod <- 
    err_proc_acor +
    rep_matrix(GPP_daily', n-1)  .* coef_GPP +
    rep_matrix(ER_daily', n-1)   .* coef_ER +
    rep_matrix(K600_daily', n-1) .* coef_K600_full;
  
  // DO model
  DO_mod[1] <- DO_obs_1;
  for(i in 1:(n-1)) {
    DO_mod[i+1] <- (
      DO_mod[i] +
      dDO_mod[i]);
  }
}

model {
  // Autocorrelated process error
  for(i in 1:(n-1)) {
    err_proc_acor_inc[i] ~ normal(0, err_proc_acor_sigma);
  }
  // Autocorrelation (phi) & SD (sigma) of the process errors
  err_proc_acor_phi ~ uniform(err_proc_acor_phi_min, err_proc_acor_phi_max);
  err_proc_acor_sigma ~ uniform(err_proc_acor_sigma_min, err_proc_acor_sigma_max);
  
  // Independent, identically distributed observation error
  for(i in 1:n) {
    DO_obs[i] ~ normal(DO_mod[i], err_obs_iid_sigma);
  }
  // SD (sigma) of the observation errors
  err_obs_iid_sigma ~ uniform(err_obs_iid_sigma_min, err_obs_iid_sigma_max);
  
  // Daily metabolism values
  GPP_daily ~ normal(GPP_daily_mu, GPP_daily_sigma);
  ER_daily ~ normal(ER_daily_mu, ER_daily_sigma);
  K600_daily ~ normal(K600_daily_mu, K600_daily_sigma);
}
