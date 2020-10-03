# Reading in necessary libraries
library(tidyverse) # For bread-and-butter functions


# Reading in necessary data files
popvote <- read_csv("data/poll/popvote_1948-2016.csv")

pollavg <- read_csv("data/poll/pollavg_1968-2016.csv")

polls_2016 <- read_csv("data/poll/polls_2016.csv") %>% 
  filter(grade != is.na(grade)) %>% 
  select(type, forecastdate, state, createddate, pollster, grade, samplesize,
         poll_wt:rawpoll_trump, adjpoll_clinton, adjpoll_trump)

polls_2020 <- read_csv("data/poll/polls_2020.csv") %>% 
  filter(candidate_name %in% c("Joseph R. Biden Jr.", "Donald Trump"),
         fte_grade != is.na(fte_grade)) %>% 
  select(question_id, election_date, state, pollster, pollster_rating_id,
         fte_grade, sample_size, methodology, internal, created_at,
         candidate_party, pct)



# Modified version of lab plot of pollavg
pollavg %>% 
  ## Refactoring party names to look nicer on the graph
  mutate(party = factor(party, levels = c("democrat", "republican"),
                        labels = c("Democrat", "Republican"))) %>% 
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




polls_2020 <- polls_2020 %>% 
  mutate(pv_wt = pct * grade_weight)

polls_2020_d <- polls_2020 %>% 
  filter(candidate_party == "DEM")

polls_2020_r <- polls_2020 %>% 
  filter(candidate_party == "REP")

sum(polls_2020_r$pct) / sum(polls_2020_r$grade_weight)

sum(polls_2020_d$pct) / sum(polls_2020_d$grade_weight)

polls_2016 <- polls_2016 %>% 
  mutate(dem_wt = DEM * grade_weight,
         rep_wt = REP * grade_weight)

########################### PREDICTION WORKFLOW ################################

# Joining poll data to popular vote data
omega <- popvote %>% 
  full_join(pollavg %>% 
              filter(weeks_left == 6) %>% 
              group_by(year, party) %>% 
              summarize(avg_support = mean(avg_support)))



### Step 1: Create adjusted polls-only model
omega_poll <- omega[!is.na(omega$avg_support),]
omega_poll_inc <- omega_poll[omega_poll$incumbent_party,]
omega_poll_chl <- omega_poll[!omega_poll$incumbent_party,]
mod_poll_inc <- lm(pv ~ avg_support, data = omega_poll_inc)
mod_poll_chl <- lm(pv ~ avg_support, data = omega_poll_chl)



### Step 2: Summarize key statistics and interpret them
summary(mod_poll_inc)
summary(mod_poll_chl)



### Step 3: In-sample testing (Mean Standard Error (MSE))
mean(abs(mod_poll_inc$residuals))
mean(abs(mod_poll_chl$residuals))



### Step 4: Out-of-sample testing
all_years <- seq(from = 1980, to = 2016, by = 4)
outsamp_dflist <- lapply(all_years, function(year){
  
  true_inc <- unique(omega$pv[omega$year == year & omega$incumbent_party])
  true_chl <- unique(omega$pv[omega$year == year & !omega$incumbent_party])
  
  ##poll model out-of-sample prediction
  mod_poll_inc_ <- lm(pv ~ avg_support, data = omega_poll_inc[omega_poll_inc$year != year,])
  mod_poll_chl_ <- lm(pv ~ avg_support, data = omega_poll_chl[omega_poll_chl$year != year,])
  pred_poll_inc <- predict(mod_poll_inc_, omega_poll_inc[omega_poll_inc$year == year,])
  pred_poll_chl <- predict(mod_poll_chl_, omega_poll_chl[omega_poll_chl$year == year,])
  
  cbind.data.frame(year,
                   poll_margin_error = (pred_poll_inc - pred_poll_chl) - (true_inc - true_chl),
                   poll_winner_correct = (pred_poll_inc > pred_poll_chl) == (true_inc > true_chl)
  )
})


outsamp_df <- do.call(rbind, outsamp_dflist)
colMeans(abs(outsamp_df[2]), na.rm = T)
colMeans(outsamp_df[3], na.rm = T) ### classification accuracy
outsamp_df[,c("year","poll_winner_correct")]



### Step 5: Supply 2020 data
omega_2020_inc <- data.frame(GDP_growth_qt = -0.0949, avg_support = 43.5)
omega_2020_chl <- data.frame(GDP_growth_qt = -0.0949, avg_support = 50.5)



### Step 6: Predict
(pred_poll_inc <- predict(mod_poll_inc, omega_2020_inc, 
                          interval = "prediction", level = 0.95))
(pred_poll_chl <- predict(mod_poll_chl, omega_2020_chl, 
                          interval = "prediction", level = 0.95))
