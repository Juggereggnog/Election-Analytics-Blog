# Reading in necessary libraries

library(tidyverse) # For bread-and-butter functions


# Reading in necessary data files
popvote <- read_csv("data/econ/popvote_1948-2016.csv")
popvote_state <- read_csv("data/econ/popvote_bystate_1948-2016.csv")
econ <- read_csv("data/econ/econ.csv")

# Tidied column name for easier use and filtered out non-state rows
local <- read_csv("data/econ/local.csv") %>% 
  rename(State = "State and area") %>% 
  filter(State != "New York city" & State != "Los Angeles County")


#
#TODO
