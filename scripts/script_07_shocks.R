library(tidyverse)
library(usmap)
library(lubridate)
library(geofacet)

approval <- read_csv("data/shocks/president_approval_polls.csv") %>% 
  mutate(created_at = substr(created_at, 1, nchar(created_at) - 6),
         created_at = mdy(created_at)) %>% 
  select(pollster, fte_grade, sample_size, created_at, yes, no) %>% 
  filter(year(created_at) == 2020) %>% 
  group_by(created_at) %>% 
  summarize(yes = mean(yes),
            no = mean(no))

covid_nat <- read_csv("data/shocks/national-history.csv")

covid_state <- read_csv("data/shocks/all-states-history.csv")


######################## DESCRIPTIVE ANALYSIS ##################################

# Meow
covid_app <- approval %>% 
  left_join(covid_nat, by = c("created_at" = "date")) %>% 
  select(-posNeg, )


ggplot(covid_app, aes(x = created_at, y = yes)) +
  geom_line()






ggsave(".png", path = "figures/shocks", height = 4, width = 8)
