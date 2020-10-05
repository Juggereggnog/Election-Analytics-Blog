# Reading in necessary libraries
library(tidyverse) # For bread-and-butter functions
library(lubridate) # For date-time functions


# Reading in necessary data files
popvote <- read_csv("data/incumbency/popvote_1948-2016.csv")
econ <- read_csv("data/incumbency/econ.csv")
incumb_app <- read_csv("data/incumbency/approval_gallup_1941-2020.csv")
pollavg <- read_csv("data/incumbency/pollavg_1968-2016.csv")


# Making a dummy table for the two election years that didn't have June polls
missed_elxns <- popvote %>% 
  filter(incumbent_party == TRUE) %>% 
  select(year, candidate, party, pv, pv2p, incumbent) %>% 
  inner_join(incumb_app %>% 
               filter(month(poll_startdate) == 7) %>% 
               group_by(year, president) %>% 
               slice(1) %>% 
               mutate(net_approve = approve - disapprove) %>% 
               select(year, incumbent_pres = president, net_approve, poll_enddate),
             by = "year") %>% 
  inner_join(econ %>% 
               filter(quarter == 2) %>% 
               select(GDP_growth_qt, year),
             by = "year") %>% 
  filter(year %in% c(1952, 1988))


# I slightly modified the lab version of tfc to make the approval polls
# referenced the ones in June, as per the model specifications
time_chg <- popvote %>% 
  filter(incumbent_party == TRUE) %>% 
  select(year, candidate, party, pv, pv2p, incumbent) %>% 
  inner_join(incumb_app %>% 
               filter(month(poll_startdate) == 6) %>% 
               group_by(year, president) %>% 
               slice(1) %>% 
               mutate(net_approve = approve - disapprove) %>% 
               select(year, incumbent_pres = president, net_approve, poll_enddate),
             by = "year") %>% 
  inner_join(econ %>% 
               filter(quarter == 2) %>% 
               select(GDP_growth_qt, year),
             by = "year") %>% 
  full_join(missed_elxns) %>% 
  arrange(year)



########################### PREDICTION WORKFLOW ################################

# Joining poll data to popular vote data (I'm justifying rounding down to 4
# weeks due to the massive increase in mail-in voting)
omega <- popvote %>% 
  full_join(pollavg %>% 
              filter(weeks_left == 4) %>% 
              group_by(year, party) %>% 
              summarize(avg_support = mean(avg_support))) %>% 
  filter(year >= 1972)



### Step 1: Create adjusted polls-only model
omega_poll <- omega[!is.na(omega$avg_support),]
omega_poll_inc <- omega_poll[omega_poll$incumbent_party,]
omega_poll_chl <- omega_poll[!omega_poll$incumbent_party,]
mod_poll_inc <- lm(pv ~ avg_support, data = omega_poll_inc)
mod_poll_chl <- lm(pv ~ avg_support, data = omega_poll_chl)
mod_tfc_inc <- lm(pv2p ~ GDP_growth_qt + net_approve + incumbent, data = time_chg)



### Step 2: Summarize key statistics and interpret them
summary(mod_poll_inc)
summary(mod_poll_chl)
summary(mod_tfc_inc)



### Step 3: In-sample testing (Mean Standard Error (MSE))
mean(abs(mod_poll_inc$residuals))

## Plotting (Incumbent) Poll Predicted vs. True
ggplot(mapping = aes(x = mod_poll_inc$fitted.values, y = omega_poll_inc$pv, label = omega_poll_inc$year)) + 
  geom_text() +
  geom_abline(slope = 1, lty = 2) +
  geom_vline(xintercept = 50, alpha = 0.2) + 
  geom_hline(yintercept = 50, alpha = 0.2) +
  xlab("Predicted Two-Party Vote Share") +
  ylab("Actual Two-Party Vote Share") +
  theme_bw()

ggsave("poll_inc_pvt.png", path = "figures/incumbency", height = 4, width = 6)



mean(abs(mod_poll_chl$residuals))

## Plotting (Challenger) Poll Predicted vs. True
ggplot(mapping = aes(x = mod_poll_chl$fitted.values, y = omega_poll_chl$pv, label = omega_poll_inc$year)) + 
  geom_text() +
  geom_abline(slope = 1, lty = 2) +
  geom_vline(xintercept = 50, alpha = 0.2) + 
  geom_hline(yintercept = 50, alpha = 0.2) +
  xlab("Predicted Two-Party Vote Share") +
  ylab("Actual Two-Party Vote Share") +
  theme_bw()

ggsave("poll_chl_pvt.png", path = "figures/incumbency", height = 4, width = 6)



mean(abs(mod_tfc_inc$residuals))

## Plotting Time for Change Predicted vs. True
ggplot(mapping = aes(x = mod_tfc_inc$fitted.values, y = time_chg$pv2p, label = time_chg$year)) + 
  geom_text() +
  geom_abline(slope = 1, lty = 2) +
  geom_vline(xintercept = 50, alpha = 0.2) + 
  geom_hline(yintercept = 50, alpha = 0.2) +
  xlab("Predicted Two-Party Vote Share") +
  ylab("Actual Two-Party Vote Share") +
  theme_bw()

ggsave("tfc_pvt.png", path = "figures/incumbency", height = 4, width = 6)



### Step 4: Out-of-sample testing
all_years <- seq(from = 1992, to = 2016, by = 4)
outsamp_dflist <- lapply(all_years, function(year){
  
  true_inc <- unique(omega$pv[omega$year == year & omega$incumbent_party])
  true_chl <- unique(omega$pv[omega$year == year & !omega$incumbent_party])
  true_tfc_inc <- unique(time_chg$pv2p[time_chg$year == year])
  
  ## Poll model out-of-sample prediction
  mod_poll_inc_ <- lm(pv ~ avg_support, data = omega_poll_inc[omega_poll_inc$year != year,])
  mod_poll_chl_ <- lm(pv ~ avg_support, data = omega_poll_chl[omega_poll_chl$year != year,])
  pred_poll_inc <- predict(mod_poll_inc_, omega_poll_inc[omega_poll_inc$year == year,])
  pred_poll_chl <- predict(mod_poll_chl_, omega_poll_chl[omega_poll_chl$year == year,])
  
  ## "Time for Change" model out-of-sample prediction
  mod_tfc_inc_ <- lm(pv2p ~ GDP_growth_qt + net_approve + incumbent, data = time_chg[time_chg$year != year,])
  pred_tfc_inc <- predict(mod_tfc_inc_, time_chg[time_chg$year == year,])
  
  cbind.data.frame(year,
                   poll_margin_error = (pred_poll_inc - pred_poll_chl) - (true_inc - true_chl),
                   tfc_margin_error = (pred_tfc_inc - (100 - pred_tfc_inc)) - (true_tfc_inc - (100 - true_tfc_inc)),
                   poll_winner_correct = (pred_poll_inc > pred_poll_chl) == (true_inc > true_chl),
                   tfc_winner_correct = (pred_tfc_inc > 50) == (true_tfc_inc > 50)
  )
})


outsamp_df <- do.call(rbind, outsamp_dflist)
colMeans(abs(outsamp_df[2:3]), na.rm = TRUE)
colMeans(outsamp_df[4:5], na.rm = TRUE) ### classification accuracy
outsamp_df[,c("year", "poll_winner_correct", "tfc_winner_correct")]



### Step 5: Supply 2020 data
omega_2020_inc <- data.frame(GDP_growth_qt = -0.0949, avg_support = 43.5)
omega_2020_chl <- data.frame(GDP_growth_qt = -0.0949, avg_support = 50.5)

tfc_2020_inc <- data.frame(GDP_growth_qt = -0.0949, net_approve = -19, incumbent = TRUE)



### Step 6: Predict
(pred_poll_inc <- predict(mod_poll_inc, omega_2020_inc, 
                          interval = "prediction", level = 0.95))
(pred_poll_chl <- predict(mod_poll_chl, omega_2020_chl, 
                          interval = "prediction", level = 0.95))

(pred_tfc_2020_inc <- predict(mod_tfc_inc, tfc_2020_inc, 
                              interval = "prediction", level = 0.95))
