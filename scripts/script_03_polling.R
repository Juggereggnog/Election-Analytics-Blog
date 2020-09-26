# Reading in necessary libraries
library(tidyverse) # For bread-and-butter functions



# Reading in necessary data files
popvote <- read_csv("data/poll/popvote_1948-2016.csv")

popvote_state <- read_csv("data/poll/popvote_bystate_1948-2016.csv")

pollavg <- read_csv("data/poll/pollavg_1968-2016.csv") %>% 
  ## Refactoring party names to look nicer on the graph
  mutate(party = factor(party, levels = c("democrat", "republican"),
                        labels = c("Democrat", "Republican")))

polls_2016 <- read_csv("data/poll/polls_2016.csv") %>% 
  filter(grade != is.na(grade)) %>% 
  select(type, forecastdate, state, createddate, pollster, grade, samplesize,
         poll_wt:rawpoll_trump, adjpoll_clinton, adjpoll_trump)

polls_2020 <- read_csv("data/poll/polls_2020.csv") %>% 
  filter(candidate_name %in% c("Joseph R. Biden Jr.", "Donald Trump"),
         fte_grade != is.na(fte_grade)) %>% 
  select(question_id, election_date, state, pollster, pollster_rating_id,
         fte_grade, sample_size, methodology, internal, created_at,
         candidate_party, pct) %>% 
  pivot_wider(names_from = candidate_party, values_from = pct)



# Modified version of lab plot of pollavg
pollavg %>% 
  filter(year == 2016) %>%
  ggplot(aes(x = poll_date, y = avg_support, color = party)) +
  geom_point(size = 1) +
  geom_line() +
  scale_x_date(date_labels = "%b, %Y") +
  scale_color_manual(values = c("#00BFC4", "#F8766D")) +
  labs(x = "",
       y = "Poll Average",
       color = "Party") +
  theme_classic()

ggsave("pollavg_2016.png", path = "figures/poll", height = 4, width = 8)



# Creating a weight scale for 2016 pollster quality
polls_2016 <- polls_2016 %>% 
  mutate(grade_weight = case_when(grade == "A+" ~ 1.00, grade == "A" ~ 1.00,
                                  grade == "A-" ~ 0.925, grade == "B+" ~ 0.825,
                                  grade == "B" ~ 0.750, grade == "B-" ~ 0.675,
                                  grade == "C+" ~ 0.575, grade == "C" ~ 0.500,
                                  grade == "C-" ~ 0.425, grade == "D" ~ 0.250,
                                  TRUE ~ 42))

## Plotting distribution of 2016 ratings
ggplot(polls_2016, aes(x = grade, fill = grade_weight)) +
  geom_bar() +
  scale_x_discrete(limits = c("A+", "A", "A-",
                              "B+", "B", "B-",
                              "C+", "C", "C-", "D")) +
  scale_fill_gradient(low = "lightblue", high = "darkblue") +
  labs(x = "Pollster Rating",
       y = "Number of Polls",
       fill = "Weight") +
  theme_classic()

ggsave("grade_dist_2016.png", path = "figures/poll", height = 4, width = 8)



# Creating a weight scale for 2020 pollster quality
polls_2020 <- polls_2020 %>% 
  mutate(grade_weight = case_when(fte_grade == "A+" ~ 1.00,
                                  fte_grade == "A" ~ 1.00,
                                  fte_grade == "A-" ~ 0.925,
                                  fte_grade == "A/B" ~ 0.825,
                                  fte_grade == "B+" ~ 0.825,
                                  fte_grade == "B" ~ 0.750,
                                  fte_grade == "B-" ~ 0.675,
                                  fte_grade == "B/C" ~ 0.575,
                                  fte_grade == "C+" ~ 0.575,
                                  fte_grade == "C" ~ 0.500,
                                  fte_grade == "C-" ~ 0.425,
                                  fte_grade == "C/D" ~ 0.325,
                                  fte_grade == "D" ~ 0.250,
                                  fte_grade == "D-" ~ 0.175,
                                  TRUE ~ 42))

## Plotting distribution of 2020 ratings
ggplot(polls_2020, aes(x = fte_grade, fill = grade_weight)) +
  geom_bar() +
  scale_x_discrete(limits = c("A+", "A", "A-", "A/B",
                              "B+", "B", "B-", "B/C",
                              "C+", "C", "C-", "C/D", "D-")) +
  scale_fill_gradient(low = "lightblue", high = "darkblue") +
  labs(x = "Pollster Rating",
       y = "Number of Polls",
       fill = "Weight") +
  theme_classic()

ggsave("grade_dist_2020.png", path = "figures/poll", height = 4, width = 8)


