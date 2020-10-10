library(tidyverse)
library(geofacet)
library(scales)


ad_campaigns <- read_csv("data/air_war/ad_campaigns_2000-2012.csv")
ad_creative <- read_csv("data/air_war/ad_creative_2000-2012.csv")
ads_2020 <- read_csv("data/air_war/ads_2020.csv")
pollavg <- read_csv("data/air_war/pollavg_1968-2016.csv")
pollstate <- read_csv("data/air_war/pollavg_bystate_1968-2016.csv")
polls_2016 <- read_csv("data/air_war/polls_2016.csv")
polls_2020 <- read_csv("data/air_war/polls_2020.csv")
pv <- read_csv("data/air_war/popvote_1948-2016.csv")
pvstate <- read_csv("data/air_war/popvote_bystate_1948-2016.csv")
vep <- read_csv("data/air_war/vep_1980-2016.csv")

poll_pvstate <- pvstate %>% 
  inner_join(pollstate %>% 
               filter(weeks_left == 5) %>% 
               group_by(state, year, candidate_name) %>%
               top_n(1, poll_date)) %>% 
  mutate(D_pv = (D / total) * 100,
         R_pv = (R / total) * 100)

poll_pvstate_vep <- poll_pvstate %>% 
  inner_join(vep)

######################## DESCRIPTIVE ANALYSIS ##################################

# percent of vap disenfranchised (california highest, perhaps due to private prisons)
vep %>% 
  mutate(disenf = (VAP - VEP) / VAP) %>% 
  arrange(desc(disenf)) %>% 
  View()





######################## PREDICTIVE ANALYSIS ###################################

#TODO



































pollstate_2020 <- data.frame(ID = 1:100)
pollstate_2020$state <- state.name
pollstate_2020 <- pollstate_2020 %>% 
  arrange(state) %>% 
  select(-ID)
pollstate_2020$party <- c("democrat", "republican")
pollstate_2020$avg_poll <- c(40.1, 55.0, 45.2, 49.7, 48.4, 45.1, 45.1, 48.2,
                             62.1, 30.8, 51.1, 41.1, 55.1, 34.3, 57.5, 38.0,
                             47.9, 46.1, 46.8, 47.0, 56.7, 31.2, 34.6, 59.5,
                             52.9, 39.8, 38.9, 53.4, 45.8, 46.6, 41.6, 50.5,
                             38.2, 57.0, 40.4, 51.1, 54.3, 39.0, 61.0, 32.7,
                             63.9, 29.7, 49.9, 43.0, 50.7, 42.0, 40.7, 52.5,
                             44.0, 50.7, 42.9, 51.0, NA, NA, 48.8, 42.4,
                             51.4, 42.8, 55.6, 36.4, 54.1, 41.4, 60.3, 33.4,
                             47.5, 46.5, 38.0, 55.2, 48.0, 47.0, 34.5, 58.0,
                             51.0, 39.1, 49.9, 44.5, NA, NA, 43.6, 51.1,
                             NA, NA, 40.8, 53.2, 45.9, 47.9, 37.0, 49.5,
                             55.6, 32.4, 51.1, 41.0, 59.1, 34.8, 33.5, 62.9,
                             50.5, 43.8, NA, NA)

s <- unique(poll_pvstate$state)

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
sim_Rvotes_s_2020 <- rbinom(n = 10000, size = VEP_s_2020, prob = prob_Rvote_s_2020)
sim_Dvotes_s_2020 <- rbinom(n = 10000, size = VEP_s_2020, prob = prob_Dvote_s_2020)

## Simulating a distribution of election results: Biden win margin
sim_elxns_s_2020 <- ((sim_Dvotes_s_2020 - sim_Rvotes_s_2020) / (sim_Dvotes_s_2020 + sim_Rvotes_s_2020)) * 100


cbind.data.frame(election_id = 1:10000,
                 state = s,
                 prob_Rvote_s_2020,
                 prob_Dvote_s_2020,
                 sim_Rvotes_s_2020,
                 sim_Dvotes_s_2020,
                 sim_elxns_s_2020)
})

dooby <- do.call(rbind, meow)


dooby %>% 
  ggplot(aes(x = sim_elxns_s_2020)) +
  facet_geo(~ state) +
  geom_histogram(bins = 100) +
  coord_flip()


dooby %>% 
  filter(state == "Virginia") %>% 
  ggplot(aes(x = sim_elxns_s_2020)) + 
  geom_histogram(bins = 100)

