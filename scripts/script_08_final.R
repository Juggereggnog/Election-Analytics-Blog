library(tidyverse)
library(lubridate)
library(statebins)
library(geofacet)


turnout <- read_csv("data/final/turnout_1980-2016.csv") %>% 
  mutate(turnout_pct = substr(turnout_pct, 1, nchar(turnout_pct) - 1),
         turnout_pct = as.double(turnout_pct),
         turnout_pct = ifelse(year == 2016, round(turnout_pct * 100, 1), turnout_pct)) %>% 
  filter(!is.na(turnout_pct),
         state != "District of Columbia",
         state != "United States")

pollstate <- read_csv("data/final/pollavg_bystate_1968-2016.csv")

pvstate <- read_csv("data/final/popvote_bystate_1948-2016.csv")

vep <- read_csv("data/final/vep_1980-2016.csv")

poll_pvstate <- pvstate %>% 
  inner_join(pollstate %>% 
               filter(weeks_left <= 5, days_left >= 3, state != "District of Columbia") %>%
               group_by(state, year, candidate_name) %>%
               top_n(1, poll_date)) %>% 
  mutate(D_pv = (D / total) * 100,
         R_pv = (R / total) * 100)

poll_pvstate_vep <- poll_pvstate %>% 
  inner_join(vep)



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


s <- unique(poll_pvstate_vep$state)

pollR_sd <- sd(pollstate_2020 %>% 
                 filter(party == "republican", !is.na(avg_poll)) %>% 
                 pull(avg_poll)) / 100

pollD_sd <- sd(pollstate_2020 %>% 
                 filter(party == "democrat", !is.na(avg_poll)) %>% 
                 pull(avg_poll)) / 100


meow <- lapply(s, function(s){
  
  VEP_s_2020 <- as.integer(vep$VEP[vep$state == s & vep$year == 2016])
  
  poll_s_R_2020 <- pollstate_2020 %>% 
    filter(state == s, party == "republican") %>% 
    pull(avg_poll)
  
  poll_s_D_2020 <- pollstate_2020 %>% 
    filter(state == s, party == "democrat") %>% 
    pull(avg_poll)
  
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

ggsave("better_binomial.png", path = "figures/final", height = 6, width = 10)


# Same process but with the average win margin for each state
dooby_avgs <- dooby %>% 
  group_by(state) %>% 
  summarize(avg_win_margin = mean(sim_elxns_s_2020),
            avg_Rvotes = mean(sim_Rvotes_s_2020),
            avg_Dvotes = mean(sim_Dvotes_s_2020),
            ) %>% 
  mutate(state_win = case_when(avg_win_margin > 0 ~ "win",
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
                        state_abb == "WY" ~ 3,
                        TRUE ~ 999),
         ev_won = ifelse(state_win == "win", ev, 0),
         ev_lost = ifelse(state_win == "win", 0, ev),
         total_votes = avg_Rvotes + avg_Dvotes,
         D_pv2p = avg_Dvotes / total_votes,
         R_pv2p = avg_Rvotes / total_votes)


dooby_avgs %>% 
  ggplot(aes(state = state, fill = state_win)) +
  geom_statebins() +
  theme_statebins() +
  labs(fill = "Average Dem Result")

ggsave("avg_elxn.png", path = "figures/final", height = 6, width = 8)


### Category Error: Turnout too low (R: 45.55%, D: 54.45%)
sum(dooby_avgs$avg_Rvotes)
sum(dooby_avgs$avg_Dvotes)
sum(dooby_avgs$total_votes)

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

ggsave("election_results.png", path = "figures/final", height = 4, width = 8)


# Counting number of wins and losses (for intuition and proportion) (91.38% win chance)
ev_dist %>% 
  count(election_result >= 267)
