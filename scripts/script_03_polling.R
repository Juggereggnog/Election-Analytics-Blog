# Reading in necessary libraries

library(usmap) # For U.S. map shapefiles and map creation
library(tidyverse) # For bread-and-butter functions


# Reading in necessary data files
popvote <- read_csv("data/poll/popvote_1948-2016.csv")
popvote_state <- read_csv("data/poll/popvote_bystate_1948-2016.csv")
pollavg <- read_csv("data/poll/pollavg_1968-2016.csv")

polls_2016 <- read_csv("data/poll/polls_2016.csv") %>% 
  select(type, forecastdate, state, createddate, pollster, grade, samplesize,
         poll_wt:rawpoll_trump, adjpoll_clinton, adjpoll_trump)

polls_2020 <- read_csv("data/poll/polls_2020.csv") %>% 
  select(office_type, election_date, state, pollster, pollster_rating_id,
         fte_grade, sample_size, methodology, internal, created_at, stage,
         answer, candidate_id, candidate_name, candidate_party, pct)



# Initial exploration of pollavg
pollavg %>% 
  filter(year == 2016) %>%
  ggplot(aes(x = poll_date, y = avg_support, color = party)) +
  geom_point(size = 1) +
  geom_line() +
  scale_x_date(date_labels = "%b, %Y") +
  scale_color_manual(values = c("blue", "red"), name = "") +
  labs(x = "",
       y = "Average Polling Approval") +
  theme_classic()




# Creating a weight scale for pollster quality
polls_2016 %>% 
  mutate(grade_weight = case_when(grade == "A+" ~ 1.00,
                                  grade == "A" ~ 1.00,
                                  grade == "A-" ~ 0.925,
                                  grade == "B+" ~ 0.825,
                                  grade == "B" ~ 0.750,
                                  grade == "B-" ~ 0.675,
                                  grade == "C+" ~ 0.575,
                                  grade == "C" ~ 0.500,
                                  grade == "C-" ~ 0.425,
                                  grade == "D+" ~ 0.325,
                                  grade == "D" ~ 0.250,
                                  TRUE ~ 69.69))
  
