# Reading in necessary libraries

library(usmap) # For U.S. map shapefiles and map creation
library(tidyverse) # For bread-and-butter functions


## Reading in necessary data files
popvote <- read_csv("data/intro/popvote_1948-2016.csv")

# I pre-sorted the dataset, so using lag()'s "order_by" argument was unnecessary
popvote_state <- read_csv("data/intro/popvote_bystate_1948-2016.csv") %>% 
  arrange(state, year) %>% 
  mutate(prev_D_pv2p = lag(D_pv2p, n = 1),
         swing_margin = D_pv2p - prev_D_pv2p,
         d_win_margin = D_pv2p - R_pv2p)


# plot_usmap() is the ggplot() of the usmap package; I used the democrat win
# margin to be consistent with the swing margin graph
plot_usmap(data = popvote_state, regions = "states", values = "d_win_margin") + 
  scale_fill_gradient2(
    low = "red",
    mid = "white",
    high = "blue",
    name = "Win Margin (%)") +
  theme_void() +
  facet_wrap(. ~ year)

# Saving the resulting image to put in blog post
ggsave("popvote_win_margin.png", path = "figures", height = 4, width = 8)


# Similar process, only now with the calculated swing margin
plot_usmap(data = popvote_state, regions = "states", values = "swing_margin") + 
  scale_fill_gradient2(
    low = "red",
    mid = "white",
    high = "blue",
    name = "Swing Margin (%)") +
  theme_void() +
  facet_wrap(. ~ year)

ggsave("popvote_swing_margin.png", path = "figures", height = 4, width = 8)
