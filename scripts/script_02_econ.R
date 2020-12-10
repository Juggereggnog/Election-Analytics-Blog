# Reading in necessary libraries

library(tidyverse) # For bread-and-butter functions
library(scales) # For manual color filling and various graph alterations


# Reading in necessary data files
popvote <- read_csv("data/econ/popvote_1948-2016.csv") %>% 
  filter(year >= 1976)

econ <- read_csv("data/econ/econ.csv") %>% 
  filter(year >= 1976)

popvote_state <- read_csv("data/econ/popvote_bystate_1948-2016.csv") %>% 
  arrange(state, year) %>% 
  filter(year >= 1976) %>% 
  select(state, year, R_pv2p, D_pv2p)

# Tidied column name for easier use and filtered out non-state rows
local <- read_csv("data/econ/local.csv") %>% 
  rename(State = "State and area") %>% 
  mutate(Month = as.numeric(Month)) %>% 
  filter(State != "New York city" & State != "Los Angeles County") %>% 
  select(State, Year, Month, Unemployed_prce)


################################ LOCAL #########################################

# Comparing local to national economy predictive power


# I'm taking the sum of changes for Q2 and Q3 unemployment rates to better join
# to popvote_state data while maintaining findings from Achen & Bartels Ch. 6
local_q2_q3 <- local %>% 
  group_by(State) %>% 
  mutate(prev_unem = lag(Unemployed_prce, n = 1),
         unem_chng = Unemployed_prce - prev_unem) %>% 
  ungroup() %>% 
  filter(Month %in% c(4:9)) %>% 
  group_by(State, Year) %>% 
  summarize(q2_q3_unem_chng = round(sum(unem_chng), 1))

# Joining datasets, adding a variable to make it easier to reference the
# incumbent's pv2p, and their victory in that state
pvsl_q2_q3 <- popvote_state %>% 
  left_join(popvote %>% filter(incumbent_party == TRUE), by = "year") %>%
  left_join(local_q2_q3, by = c("state" = "State", "year" = "Year")) %>% 
  mutate(state_pv2p = case_when(party == "republican" ~ R_pv2p, 
                                party == "democrat" ~ D_pv2p),
         state_winner = if_else(state_pv2p > 50, TRUE, FALSE)) %>% 
  select(state, year, q2_q3_unem_chng, candidate, party, state_winner,
         state_pv2p, winner, pv2p)


# General correlation (-0.18)
cor(pvsl_q2_q3$state_pv2p, pvsl_q2_q3$q2_q3_unem_chng)


# Correlation for Democratic incumbents (-0.22)
pvsl_q2_q3_dem <- pvsl_q2_q3 %>% 
  filter(party == "democrat")

cor(pvsl_q2_q3_dem$state_pv2p, pvsl_q2_q3_dem$q2_q3_unem_chng)


# Correlation for Republican incumbents (-0.14)
pvsl_q2_q3_rep <- pvsl_q2_q3 %>% 
  filter(party == "republican")

cor(pvsl_q2_q3_rep$state_pv2p, pvsl_q2_q3_rep$q2_q3_unem_chng)


# Refactoring party names to look nicer on the graph
pvsl_q2_q3$party <- factor(pvsl_q2_q3$party,
                           levels = c("democrat", "republican"),
                           labels = c("Democrat", "Republican"))

# Hex codes of defualt ggplot palette, only flipped to reflect party colors
ggplot(pvsl_q2_q3, aes(x = q2_q3_unem_chng, y = state_pv2p, color = party)) +
  geom_point() +
  geom_smooth(method = "lm") +
  geom_hline(yintercept = 50) +
  geom_vline(xintercept = 0) +
  labs(x = "Second & Third Quarter Change in Unemployment Rates (%)",
       y = "Incumbent Party's State Two-Party Popular Voteshare (%)",
       color = "Party") +
  scale_color_manual(values = c("#00BFC4", "#F8766D")) +
  theme_bw() +
  facet_wrap(~ party)

ggsave("popvote_state_local_unem.png", path = "figures", height = 6, width = 8)


lm_local_econ <- lm(state_pv2p ~ q2_q3_unem_chng, data = pvsl_q2_q3)
summary(lm_local_econ)


local_outsamp_mod <- lm(state_pv2p ~ q2_q3_unem_chng, pvsl_q2_q3[pvsl_q2_q3$year != 2016,])
local_outsamp_pred <- predict(local_outsamp_mod, pvsl_q2_q3[pvsl_q2_q3$year == 2016,])
local_outsamp_true <- pvsl_q2_q3$state_pv2p[pvsl_q2_q3$year == 2016]
local_outsamp_pred - local_outsamp_true


local_q2_q3_unem_chng_new <- local_q2_q3 %>%
  subset(Year == 2020) %>%
  select(q2_q3_unem_chng)


predict(lm_local_econ, local_q2_q3_unem_chng_new)
predict(lm_local_econ, local_q2_q3_unem_chng_new, interval = "prediction")


############################## NATIONAL ########################################


nat_econ_q2_q3 <- econ %>% 
  mutate(prev_unem = lag(unemployment, n = 1),
         unem_chng = unemployment - prev_unem) %>% 
  filter(quarter %in% c(2, 3)) %>% 
  group_by(year) %>% 
  summarize(q2_q3_unem_chng = round(sum(unem_chng), 1))

#
pvn <- popvote %>% 
  filter(incumbent_party == TRUE) %>% 
  left_join(nat_econ_q2_q3, by = "year") %>% 
  select(year, q2_q3_unem_chng, candidate, party, winner, pv, pv2p)


# General correlation (-0.82)
cor(pvn$pv2p, pvn$q2_q3_unem_chng)


# Correlation for Democratic incumbents (-0.95)
pvn_dem <- pvn %>% 
  filter(party == "democrat")

cor(pvn_dem$pv2p, pvn_dem$q2_q3_unem_chng)


# Correlation for Republican incumbents (-0.78)
pvn_rep <- pvn %>% 
  filter(party == "republican")

cor(pvn_rep$pv2p, pvn_rep$q2_q3_unem_chng)


# Refactoring party names to look nicer on the graph
pvn$party <- factor(pvn$party,
                           levels = c("democrat", "republican"),
                           labels = c("Democrat", "Republican"))

# Hex codes of defualt ggplot palette, only flipped to reflect party colors
ggplot(pvn, aes(x = q2_q3_unem_chng, y = pv2p, color = party)) +
  geom_point() +
  geom_smooth(method = "lm") +
  geom_hline(yintercept = 50) +
  geom_vline(xintercept = 0) +
  labs(x = "Second & Third Quarter Change in Unemployment Rates (%)",
       y = "Incumbent Party's Two-Party Popular Voteshare (%)",
       color = "Party") +
  scale_color_manual(values = c("#00BFC4", "#F8766D")) +
  theme_bw() +
  facet_wrap(~ party)

ggsave("popvote_state_nat_unem.png", path = "figures", height = 6, width = 8)


lm_nat_econ <- lm(pv2p ~ q2_q3_unem_chng, data = pvn)
summary(lm_nat_econ)


nat_outsamp_mod <- lm(pv2p ~ q2_q3_unem_chng, pvn[pvn$year != 2016,])
nat_outsamp_pred <- predict(nat_outsamp_mod, pvn[pvn$year == 2016,])
nat_outsamp_true <- pvn$pv2p[pvn$year == 2016]
nat_outsamp_pred - nat_outsamp_true


nat_econ_q2_q3 <- nat_econ_q2_q3 %>% 
  mutate(q2_q3_unem_chng = if_else(year == 2020, 9.4, q2_q3_unem_chng))


nat_q2_q3_unem_chng_new <- nat_econ_q2_q3 %>%
  subset(year == 2020) %>%
  select(q2_q3_unem_chng)


predict(lm_nat_econ, nat_q2_q3_unem_chng_new)
predict(lm_nat_econ, nat_q2_q3_unem_chng_new, interval = "prediction")
