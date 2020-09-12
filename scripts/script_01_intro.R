library(usmap)
library(tidyverse)

popvote <- read_csv("data/intro/popvote_1948-2016.csv")

popvote_state <- read_csv("data/intro/popvote_bystate_1948-2016.csv") %>% 
  arrange(state, year)

popvote_state_2 <- popvote_state %>% 
  mutate(prev_D_pv2p = lag(D_pv2p, n = 1),
         swing = D_pv2p - prev_D_pv2p)
