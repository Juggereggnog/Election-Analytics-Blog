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

final_stuffs <- data.frame(state = state.name)

######################## DESCRIPTIVE ANALYSIS ##################################

# percent of vap disenfranchised (california highest, perhaps due to private prisons)
vep %>% 
  mutate(disenf = (VAP - VEP) / VAP) %>% 
  arrange(desc(disenf)) %>% 
  View()





######################## PREDICTIVE ANALYSIS ###################################

#TODO


VEP_PA_2020 <- as.integer(vep$VEP[vep$state == "Pennsylvania" & vep$year == 2016])

PA_R <- poll_pvstate_vep %>% filter(state=="Pennsylvania", party=="republican")
PA_D <- poll_pvstate_vep %>% filter(state=="Pennsylvania", party=="democrat")

## Fit D and R models
PA_R_glm <- glm(cbind(R, VEP-R) ~ avg_poll, PA_R, family = binomial)
PA_D_glm <- glm(cbind(D, VEP-D) ~ avg_poll, PA_D, family = binomial)

## Get predicted draw probabilities for D and R
prob_Rvote_PA_2020 <- predict(PA_R_glm, newdata = data.frame(avg_poll=44.5), type="response")[[1]]
prob_Dvote_PA_2020 <- predict(PA_D_glm, newdata = data.frame(avg_poll=50), type="response")[[1]]

## Get predicted distribution of draws from the population
sim_Rvotes_PA_2020 <- rbinom(n = 10000, size = VEP_PA_2020, prob = prob_Rvote_PA_2020)
sim_Dvotes_PA_2020 <- rbinom(n = 10000, size = VEP_PA_2020, prob = prob_Dvote_PA_2020)

## Simulating a distribution of election results: Biden PA PV
hist(sim_Dvotes_PA_2020, xlab="predicted turnout draws for Biden\nfrom 10,000 binomial process simulations", breaks=100)

## Simulating a distribution of election results: Trump PA PV
hist(sim_Rvotes_PA_2020, xlab="predicted turnout draws for Trump\nfrom 10,000 binomial process simulations", breaks=100)

## Simulating a distribution of election results: Biden win margin
sim_elxns_PA_2020 <- ((sim_Dvotes_PA_2020-sim_Rvotes_PA_2020)/(sim_Dvotes_PA_2020+sim_Rvotes_PA_2020))*100
hist(sim_elxns_PA_2020, xlab="predicted draws of Biden win margin (% pts)\nfrom 10,000 binomial process simulations", xlim=c(2, 7.5))





