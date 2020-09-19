# Reading in necessary libraries

library(tidyverse) # For bread-and-butter functions


# Reading in necessary data files
popvote <- read_csv("data/econ/popvote_1948-2016.csv") %>% 
  filter(year >= 1976)

econ <- read_csv("data/econ/econ.csv")

popvote_state <- read_csv("data/econ/popvote_bystate_1948-2016.csv") %>% 
  arrange(state, year) %>% 
  filter(year >= 1976) %>% 
  select(state, year, R_pv2p, D_pv2p)

# Tidied column name for easier use and filtered out non-state rows
local <- read_csv("data/econ/local.csv") %>% 
  rename(State = "State and area") %>% 
  mutate(Month = as.numeric(Month)) %>% 
  filter(State != "New York city" & State != "Los Angeles County",
         Month %in% c(4:9)) %>% 
  select(State, Year, Month, Unemployed_prce)


################################ LOCAL #########################################

# Comparing local to national economy predictive power


# I'm taking the average of Q2 and Q3 unemployment rates to better join to
# popvote_state data while maintaining findings from Achen & Bartels Ch. 6
local_q2_q3 <- local %>% 
  group_by(State, Year) %>% 
  summarize(q2_q3_unemployed_prce = round(mean(Unemployed_prce), 1))

#
popvote_state_local <- popvote_state %>% 
  left_join(popvote %>% filter(incumbent_party == TRUE), by = "year") %>%
  left_join(local_q2_q3, by = c("state" = "State", "year" = "Year")) %>% 
  select(state, year, q2_q3_unemployed_prce, candidate, party, winner, R_pv2p, D_pv2p,
         pv2p)



popvote_state_local %>% 
  cor(q2_q3_unemployed_prce, state_winner)


############################ HETEROGENEITY #####################################

# Comparing incumbent presidents vs. same-party heirs, time


# Filtering vote share data to only incumbent party presidents
popvote_incumb <- popvote %>% 
  filter(incumbent_party == TRUE) %>%
  select(year, winner, pv2p, incumbent, incumbent_party) %>%
  left_join(econ %>% filter(quarter == 2))
