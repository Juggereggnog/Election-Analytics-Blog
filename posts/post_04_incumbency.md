# Incumbency

# October 3, 2020



## Incumbency: A Diminishing Marginal Benefit


### Campbell (2016) "Forecasting the 2016 American National Elections"

![Pv2P by Terms and Election Period](../figures/incumbency/campbell.png)


The more I look at this graph, the more I am irrevocably convinced that the
decay of the benefits of incumbency must be accounted for in our models.


1) Is Trump benefiting from an incumbency advantage? The short answer is most
likely yes, but that effect is being offset and obfuscated by everything else
extraordinary happening this year.

2) How does my



## Time for Change in the Time for Change Model


### (Traditional) Time for Change Model Results

```r
Call:
lm(formula = pv2p ~ GDP_growth_qt + net_approve + incumbent, 
    data = time_chg)

Residuals:
    Min      1Q  Median      3Q     Max 
-4.1481 -1.1348 -0.0782  1.5210  3.9414 

Coefficients:
              Estimate Std. Error t value Pr(>|t|)    
(Intercept)   48.20356    1.05610  45.643  < 2e-16 ***
GDP_growth_qt  1.82267    0.62432   2.919 0.011203 *  
net_approve    0.12899    0.02453   5.259 0.000121 ***
incumbentTRUE  2.41125    1.23201   1.957 0.070571 .  
---
Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

Residual standard error: 2.479 on 14 degrees of freedom
Multiple R-squared:  0.8177,	Adjusted R-squared:  0.7787 
F-statistic: 20.94 on 3 and 14 DF,  p-value: 1.924e-05
```






## **_Funny Stuff_**




[Abramawitz's Article on 2020 Model Update](https://centerforpolitics.org/crystalball/articles/its-the-pandemic-stupid-a-simplified-model-for-forecasting-the-2020-presidential-election/)


"Indeed, roughly 1 year into the new administration, Trump’s approval rating is
much lower than would be expected based on economic performance." [(Donovan et al)](https://doi.org/10.1007/s11109-019-09539-8).
