library(tidyverse)
library(geofacet) # For faceting, but, map shaped


ad_campaigns <- read_csv("data/air_war/ad_campaigns_2000-2012.csv")
ad_creative <- read_csv("data/air_war/ad_creative_2000-2012.csv")
pollstate <- read_csv("data/air_war/pollavg_bystate_1968-2016.csv")
polls_2020 <- read_csv("data/air_war/polls_2020.csv")
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

## percent of vap disenfranchised (california highest, perhaps due to private prisons)
vep %>% 
  mutate(disenf = (VAP - VEP) / VAP) %>% 
  arrange(desc(disenf)) %>% 
  ggplot(aes(x = year, y = disenf)) +
  geom_line() +
  facet_wrap(~ state) +
  theme_bw()

## Campaign Ads Aired By Issue and Party: 2008
party_issues2008 <- ad_campaigns %>%
  filter(cycle == 2008) %>%
  left_join(ad_creative) %>%
  filter(ad_issue != "None") %>%
  group_by(cycle, ad_issue) %>% mutate(tot_n = n()) %>% ungroup() %>%
  group_by(cycle, ad_issue, party) %>% summarize(p_n = n() * 100 / first(tot_n)) %>% ungroup() %>%
  group_by(cycle, ad_issue) %>% mutate(Dp_n = ifelse(first(party) == "democrat", first(p_n), 0))

ggplot(party_issues2008, aes(x = reorder(ad_issue, Dp_n), y = p_n, fill = party)) + 
  geom_bar(stat = "identity") +
  scale_fill_manual(values = c("#00BFC4", "#F8766D")) +
  labs(x = "Issue",
       y = "Party's % of Ads",
       fill = "Party") +
  coord_flip() + 
  theme_bw()

ggsave("ad_issues_2008.png", path = "figures/air_war", height = 6, width = 8)


######################## PREDICTIVE ANALYSIS ###################################


# Making (relevant) polls_2020 dataframe (polls 5 weeks out)
pollstate_2020 <- data.frame(ID = 1:100)
pollstate_2020$state <- state.name
pollstate_2020 <- pollstate_2020 %>% 
  arrange(state) %>% 
  select(-ID)
pollstate_2020$party <- c("democrat", "republican")
## Manually coded in FiveThirtyEight state poll avgs alphabetically (two per state)
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
                        state_abb == "KY" ~ 6,
                        state_abb == "LA" ~ 8,
                        state_abb == "ME" ~ 4,
                        state_abb == "MD" ~ 10,
                        state_abb == "MA" ~ 11,
                        state_abb == "MI" ~ 16,
                        state_abb == "MN" ~ 16,
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
                        state_abb == "SC" ~ 9,
                        state_abb == "TN" ~ 11,
                        state_abb == "TX" ~ 38,
                        state_abb == "UT" ~ 6,
                        state_abb == "VA" ~ 13,
                        state_abb == "WA" ~ 12,
                        state_abb == "WV" ~ 5,
                        state_abb == "WI" ~ 10,
                        TRUE ~ 999),
         ev_won = ifelse(state_win == "win", ev, 0),
         ev_lost = 522 - ev_won)


dooby %>% 
  ggplot(aes(x = sim_elxns_s_2020, fill = state_win)) +
  facet_geo(~ state_abb, scales = "free") +
  geom_histogram(bins = 100) +
  labs(x = "Democratic Win Margin",
       y = "Number of Simulations",
       fill = "Dem Results") +
  theme_bw()

ggsave("geo_simulations.png", path = "figures/air_war", height = 6, width = 10)



################################## TESTING #####################################


dooby %>% 
  filter(state == "Ohio") %>% 
  ggplot(aes(x = sim_elxns_s_2020)) + 
  geom_histogram(bins = 100) +
  labs(x = "Democratic Win Margin",
       y = "Number of Simulations") +
  theme_bw()


meow <- data.frame()
for (s in unique(dooby$state)) {
  
  top <- dooby %>% 
    filter(state == s) %>% 
    arrange(desc(sim_elxns_s_2020)) %>% 
    slice(1) %>% 
    pull(sim_elxns_s_2020)
  
  bottom <- dooby %>% 
    filter(state == s) %>% 
    arrange(sim_elxns_s_2020) %>% 
    slice(1) %>% 
    pull(sim_elxns_s_2020)
  
  w_l <- top * bottom
  
  meow <- rbind(meow,
                cbind(state = s,
                      tootle = w_l))
}

meow %>% 
  mutate(tootle = as.double(tootle)) %>% 
  arrange(desc(tootle))
