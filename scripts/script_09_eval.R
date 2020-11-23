library(tidyverse)
library(lubridate)
library(statebins)
library(geofacet)


popvote <- read_csv("data/eval/popvote_1948-2020.csv")

pvstate <- read_csv("data/eval/popvote_bystate_1948-2020.csv") %>% 
  arrange(state, year) %>% 
  mutate(win_margin = D_pv2p - R_pv2p,
         state_win = case_when(win_margin > 0 ~ "win",
                               win_margin < 0 ~ "lose",
                               TRUE ~ "tie")) %>% 
  select(state, year, everything())

pollavg <- read_csv("data/eval/pollavg_1948-2020.csv")

pollstate <- read_csv("data/final/pollavg_bystate_1968-2016.csv")

turnout <- read_csv("data/final/turnout_1980-2016.csv") %>% 
  mutate(turnout_pct = substr(turnout_pct, 1, nchar(turnout_pct) - 1),
         turnout_pct = as.double(turnout_pct),
         turnout_pct = ifelse(year == 2016, round(turnout_pct * 100, 1), turnout_pct)) %>% 
  filter(!is.na(turnout_pct),
         state != "District of Columbia",
         state != "United States")

vep <- read_csv("data/final/vep_1980-2016.csv")

error_538 <- read_csv("data/eval/error_538.csv")

error_econ <- read_csv("data/eval/error_economist.csv")


poll_pvstate_vep <- pvstate %>% 
  inner_join(pollstate %>% 
               filter(weeks_left <= 5, days_left >= 3, state != "District of Columbia") %>%
               group_by(state, year, candidate_name) %>%
               top_n(1, poll_date)) %>% 
  mutate(D_pv = (D / total) * 100,
         R_pv = (R / total) * 100) %>% 
  inner_join(vep)



######################### DESCRIPTIVE ANALYSIS #################################

#




######################## PREDICTIVE ANALYSIS ###################################

# Making (relevant) polls_2020 dataframe (polls 5 weeks out)
# Making (relevant) polls_2020 dataframe (polls 5 weeks out)
pollstate_2020 <- data.frame(ID = 1:100)
pollstate_2020$state <- state.name
pollstate_2020 <- pollstate_2020 %>% 
  arrange(state) %>% 
  select(-ID)
pollstate_2020$party <- c("democrat", "republican")
## Manually coded in FiveThirtyEight state poll avgs alphabetically (two per state)
pollstate_2020$avg_poll <- c(38.2, 57.0, 43.4, 51.0, 48.7, 45.3, 35.9, 59.1,
                             61.4, 33.4, 54.6, 40.6, 57.4, 32.5, 58.7, 34.9,
                             48.5, 46.6, 48.4, 46.8, 63.6, 30.7, 37.7, 57.5,
                             55.0, 40.9, 41.8, 51.1, 45.6, 47.3, 41.7, 51.7,
                             39.5, 55.6, 37.0, 57.4, 53.5, 39.9, 61.6, 31.9,
                             65.9, 29.2, 51.2, 42.8, 51.2, 42.3, 39.2, 55.6,
                             44.2, 50.9, 45.3, 50.2, 42.4, 52.4, 49.5, 44.4,
                             53.8, 42.8, 59.6, 37.2, 53.7, 42.2, 62.8, 32.1,
                             49.0, 46.7, 38.1, 56.6, 46.9, 47.1, 36.3, 58.9,
                             57.9, 38.0, 49.9, 45.0, 63.4, 32.3, 43.6, 51.4,
                             39.2, 53.8, 41.3, 54.4, 47.0, 48.4, 41.6, 52.2,
                             65.6, 28.7, 53.2, 41.9, 58.5, 35.5, 34.0, 61.3,
                             51.9, 43.7, 30.5, 62.6)

# DC (89.8, 6.7), Nebraska (42.4, 52.4), Rhode Island (63.4, 32.3),
# South Dakota (39.2, 53.8), Wyoming (30.5, 62.6)


pollstate_2020 <- pollstate_2020 %>% 
  pivot_wider(names_from = party, values_from = avg_poll) %>% 
  mutate(win_margin = democrat - republican,
         # Alternate reality where Trump had 2.5% uniform swing in poll averages
         shift_d = democrat - 2.5,
         shift_r = republican + 2.5)


s <- unique(poll_pvstate_vep$state)

pollR_sd <- sd(pollstate_2020$republican) / 100

pollD_sd <- sd(pollstate_2020$democrat) / 100


# Running binomial logit regression for each state
meow <- lapply(s, function(s){
  
  ### hpoll_s_R_2020 <- pollstate_2020$shift_r[pollstate_2020$state == s]
  ### hpoll_s_D_2020 <- pollstate_2020$shift_d[pollstate_2020$state == s]
  
  VEP_s_2020 <- as.integer(vep$VEP[vep$state == s & vep$year == 2016])
  
  poll_s_R_2020 <- pollstate_2020$republican[pollstate_2020$state == s]
  poll_s_D_2020 <- pollstate_2020$democrat[pollstate_2020$state == s]
  
  s_R <- poll_pvstate_vep %>% filter(state == s, party == "republican")
  s_D <- poll_pvstate_vep %>% filter(state == s, party == "democrat")
  
  ## Fit D and R models
  s_R_glm <- glm(cbind(R, VEP-R) ~ avg_poll, s_R, family = binomial)
  s_D_glm <- glm(cbind(D, VEP-D) ~ avg_poll, s_D, family = binomial)
  
  ## Get predicted draw probabilities for D and R
  prob_Rvote_s_2020 <- predict(s_R_glm, newdata = data.frame(avg_poll = poll_s_R_2020), type = "response")[[1]]
  prob_Dvote_s_2020 <- predict(s_D_glm, newdata = data.frame(avg_poll = poll_s_D_2020), type = "response")[[1]]
  
  ## Get predicted distribution of draws from the population
  avg_turnout_s <- turnout %>% 
    filter(state == s, !is.na(turnout_pct)) %>% 
    summarize(avg_turnout = mean(turnout_pct) / 100) %>% 
    pull(avg_turnout)
  
  sd_turnout_s <- turnout %>% 
    filter(state == s, !is.na(turnout_pct)) %>% 
    summarize(sd_turnout = sd(turnout_pct) / 100) %>% 
    pull(sd_turnout)
  
  ## Creating turnout distribution (LVP = Likely Voter Population)
  LVP_s_2020 <- rnorm(10000, mean = VEP_s_2020 * avg_turnout_s, sd = VEP_s_2020 * sd_turnout_s)
  
  normalR <- rnorm(10000, mean = prob_Rvote_s_2020, sd = pollR_sd)
  normalD <- rnorm(10000, mean = prob_Dvote_s_2020, sd = pollD_sd)
  
  sim_Rvotes_s_2020 <- rbinom(n = 10000, size = round(LVP_s_2020), prob = normalR)
  sim_Dvotes_s_2020 <- rbinom(n = 10000, size = round(LVP_s_2020), prob = normalD)
  
  ## Simulating a distribution of election results: Biden win margin
  sim_elxns_s_2020 <- ((sim_Dvotes_s_2020 - sim_Rvotes_s_2020) / (sim_Dvotes_s_2020 + sim_Rvotes_s_2020)) * 100

  
  cbind.data.frame(election_id = 1:10000,
                   state = s,
                   prob_Rvote_s_2020,
                   prob_Dvote_s_2020,
                   VEP_s_2020,
                   LVP_s_2020,
                   normalR,
                   normalD,
                   sim_Rvotes_s_2020,
                   sim_Dvotes_s_2020,
                   sim_elxns_s_2020)
})

dooby <- do.call(rbind, meow)

# DC not included, but auto-awarded to Biden (+3 EV)
dooby <- dooby %>% 
  filter(!is.na(sim_elxns_s_2020)) %>% 
  mutate(state_win = case_when(sim_elxns_s_2020 > 0 ~ "win",
                               sim_elxns_s_2020 < 0 ~ "lose",
                               TRUE ~ "tie"),
         state_abb = state.abb[match(state, state.name)],
         ev = case_when(state_abb == "AL" ~ 9,
                        state_abb == "AK" ~ 3,
                        state_abb == "AZ" ~ 11,
                        state_abb == "AR" ~ 6,
                        state_abb == "CA" ~ 55,
                        state_abb == "CO" ~ 9,
                        state_abb == "CT" ~ 7,
                        state_abb == "DE" ~ 3,
                        state_abb == "FL" ~ 29,
                        state_abb == "GA" ~ 16,
                        state_abb == "HI" ~ 4,
                        state_abb == "ID" ~ 4,
                        state_abb == "IL" ~ 20,
                        state_abb == "IN" ~ 11,
                        state_abb == "IA" ~ 6,
                        state_abb == "KS" ~ 6,
                        state_abb == "KY" ~ 8,
                        state_abb == "LA" ~ 8,
                        state_abb == "ME" ~ 4,
                        state_abb == "MD" ~ 10,
                        state_abb == "MA" ~ 11,
                        state_abb == "MI" ~ 16,
                        state_abb == "MN" ~ 10,
                        state_abb == "MS" ~ 6,
                        state_abb == "MO" ~ 10,
                        state_abb == "MT" ~ 3,
                        state_abb == "NE" ~ 5,
                        state_abb == "NV" ~ 6,
                        state_abb == "NH" ~ 4,
                        state_abb == "NJ" ~ 14,
                        state_abb == "NM" ~ 5,
                        state_abb == "NY" ~ 29,
                        state_abb == "NC" ~ 15,
                        state_abb == "ND" ~ 3,
                        state_abb == "OH" ~ 18,
                        state_abb == "OK" ~ 7,
                        state_abb == "OR" ~ 7,
                        state_abb == "PA" ~ 20,
                        state_abb == "RI" ~ 4,
                        state_abb == "SC" ~ 9,
                        state_abb == "SD" ~ 3,
                        state_abb == "TN" ~ 11,
                        state_abb == "TX" ~ 38,
                        state_abb == "UT" ~ 6,
                        state_abb == "VA" ~ 13,
                        state_abb == "VT" ~ 3,
                        state_abb == "WA" ~ 12,
                        state_abb == "WV" ~ 5,
                        state_abb == "WI" ~ 10,
                        state_abb == "WY" ~ 3,
                        TRUE ~ 999),
         ev_won = ifelse(state_win == "win", ev, 0),
         ev_lost = ifelse(state_win == "win", 0, ev))


dooby %>% 
  ggplot(aes(x = sim_elxns_s_2020, fill = state_win)) +
  facet_geo(~ state_abb, scales = "free") +
  geom_histogram(bins = 100) +
  labs(x = "Democratic Win Margin",
       y = "Number of Simulations",
       fill = "Dem Results") +
  theme_bw()

ggsave("better_binomial.png", path = "figures/eval", height = 6, width = 10)


# Gathering win statistics for each state
dooby_wins <- dooby %>% 
  group_by(state) %>% 
  count(state_win) %>% 
  pivot_wider(names_from = state_win,
              values_from = n) %>% 
  mutate(win_prob = win / (win + lose))


# Same process as dooby but with the average win margin for each state
dooby_avgs <- dooby %>% 
  group_by(state) %>% 
  summarize(avg_Rvotes = mean(sim_Rvotes_s_2020),
            avg_Dvotes = mean(sim_Dvotes_s_2020)) %>% 
  mutate(avg_total_votes = avg_Rvotes + avg_Dvotes,
         avg_D_pv2p = avg_Dvotes / avg_total_votes,
         avg_R_pv2p = avg_Rvotes / avg_total_votes,
         avg_win_margin = avg_D_pv2p - avg_R_pv2p,
         avg_state_win = case_when(avg_win_margin > 0 ~ "win",
                               avg_win_margin < 0 ~ "lose",
                               TRUE ~ "tie"),
         state_abb = state.abb[match(state, state.name)],
         ev = case_when(state_abb == "AL" ~ 9,
                        state_abb == "AK" ~ 3,
                        state_abb == "AZ" ~ 11,
                        state_abb == "AR" ~ 6,
                        state_abb == "CA" ~ 55,
                        state_abb == "CO" ~ 9,
                        state_abb == "CT" ~ 7,
                        state_abb == "DE" ~ 3,
                        state_abb == "FL" ~ 29,
                        state_abb == "GA" ~ 16,
                        state_abb == "HI" ~ 4,
                        state_abb == "ID" ~ 4,
                        state_abb == "IL" ~ 20,
                        state_abb == "IN" ~ 11,
                        state_abb == "IA" ~ 6,
                        state_abb == "KS" ~ 6,
                        state_abb == "KY" ~ 8,
                        state_abb == "LA" ~ 8,
                        state_abb == "ME" ~ 4,
                        state_abb == "MD" ~ 10,
                        state_abb == "MA" ~ 11,
                        state_abb == "MI" ~ 16,
                        state_abb == "MN" ~ 10,
                        state_abb == "MS" ~ 6,
                        state_abb == "MO" ~ 10,
                        state_abb == "MT" ~ 3,
                        state_abb == "NE" ~ 5,
                        state_abb == "NV" ~ 6,
                        state_abb == "NH" ~ 4,
                        state_abb == "NJ" ~ 14,
                        state_abb == "NM" ~ 5,
                        state_abb == "NY" ~ 29,
                        state_abb == "NC" ~ 15,
                        state_abb == "ND" ~ 3,
                        state_abb == "OH" ~ 18,
                        state_abb == "OK" ~ 7,
                        state_abb == "OR" ~ 7,
                        state_abb == "PA" ~ 20,
                        state_abb == "RI" ~ 4,
                        state_abb == "SC" ~ 9,
                        state_abb == "SD" ~ 3,
                        state_abb == "TN" ~ 11,
                        state_abb == "TX" ~ 38,
                        state_abb == "UT" ~ 6,
                        state_abb == "VA" ~ 13,
                        state_abb == "VT" ~ 3,
                        state_abb == "WA" ~ 12,
                        state_abb == "WV" ~ 5,
                        state_abb == "WI" ~ 10,
                        state_abb == "WY" ~ 3),
         ev_won = ifelse(avg_state_win == "win", ev, 0),
         ev_lost = ifelse(avg_state_win == "win", 0, ev)) %>% 
  full_join(pvstate %>% filter(year == 2020), by = "state") %>% 
  filter(state != "District of Columbia") %>% 
  full_join(dooby_wins, by = "state") %>% 
  select(state, state_abb, avg_total_votes, avg_Dvotes, avg_Rvotes,
         avg_D_pv2p, avg_R_pv2p, avg_win_margin, avg_state_win, ev:ev_lost, win,
         lose, win_prob, total:state_win) %>% 
  mutate(bin_avg_state_win = ifelse(avg_state_win == "win", 1, 0),
         bin_state_win = ifelse(state_win == "win", 1, 0))


dooby_avgs %>% 
  ggplot(aes(state = state, fill = avg_state_win)) +
  geom_statebins() +
  theme_statebins() +
  labs(fill = "Average Dem Result")

ggsave("avg_elxn.png", path = "figures/eval", height = 6, width = 8)


### Category Error: Turnout too low (R: 45.55%, D: 54.45%)
sum(dooby_avgs$avg_Rvotes)
sum(dooby_avgs$avg_Dvotes)
sum(dooby_avgs$avg_total_votes)

### R: 170, D: 365 (+3 from D.C. = 368)
sum(dooby_avgs$ev)
sum(dooby_avgs$ev_won)
sum(dooby_avgs$ev_lost)



################################## TESTING #####################################

# Calculating Electoral College votes for each simulated election
ev_dist <- dooby %>% 
  group_by(election_id) %>% 
  summarize(election_result = sum(ev_won),
            Rvotes = sum(sim_Rvotes_s_2020),
            Dvotes = sum(sim_Dvotes_s_2020)) %>% 
  mutate(total_votes = Rvotes + Dvotes,
         D_pv2p = Dvotes / total_votes,
         R_pv2p = Rvotes / total_votes)


# Plotting distribution of results
ev_dist %>% 
  ggplot(aes(x = election_result, fill = (election_result >= 267))) +
  geom_histogram(bins = 60) +
  theme_bw() +
  labs(x = "# Electoral College Votes",
       y = "# of Elections",
       fill = "Biden Wins")

ggsave("election_results.png", path = "figures/eval", height = 4, width = 8)


# Counting number of wins and losses (for intuition and proportion) (91.38% win chance)
ev_dist %>% 
  count(election_result >= 267)


# Plotting actual D_pv2p against predicted D_pv2p
ggplot(dooby_avgs, aes(x = avg_D_pv2p, y = D_pv2p, label = state_abb)) +
  geom_text() +
  geom_abline(slope = 1, intercept = 0) +
  geom_vline(xintercept = 0.5, linetype = "dashed") +
  geom_hline(yintercept = 0.5, linetype = "dashed") +
  geom_smooth(method = "lm") +
  labs(x = "Predicted Democratic Two-Party Vote Share",
       y = "Actual Democratic Two-Party Vote Share")


ggsave("act_pred_scatter.png", path = "figures/eval", height = 6, width = 6)


brier <- sum((dooby_avgs$win_prob - as.numeric(dooby_avgs$bin_state_win))^2) / 50

rmse <- sqrt(sum((dooby_avgs$avg_D_pv2p - dooby_avgs$D_pv2p)^2) / 50) * 100

rmse_538 <- sqrt(sum(error_538$error^2) / 50)

rmse_econ <- sqrt(sum(error_econ$error^2) / 50)


dooby_avgs %>% 
  select(state, win_prob, bin_state_win, avg_D_pv2p, D_pv2p) %>% 
  mutate(diff = abs(avg_D_pv2p - D_pv2p),
         diff_brier = abs(win_prob - bin_state_win))



### Turnout modeling includes midterm elections, depresses turnout average (FiF)

### Normal distribution allows for negative vote probabilities for some parties;
### creates NAs for those election simulations (FiF)
