# moveslite v2 Use Cases

## Overview

This document provides practical examples and use cases for the `moveslite` v2 package. Each use case demonstrates a common scenario for emissions analysis and policy evaluation.

## Table of Contents

1. [Basic Emissions Query](#1-basic-emissions-query)
2. [Model Estimation and Evaluation](#2-model-estimation-and-evaluation)
3. [Scenario Analysis](#3-scenario-analysis)
4. [Multi-Year Projections](#4-multi-year-projections)
5. [Sector-Specific Analysis](#5-sector-specific-analysis)
6. [Model Diagnostics](#6-model-diagnostics)
7. [Comparing Multiple Scenarios](#7-comparing-multiple-scenarios)

---

## 1. Basic Emissions Query

**Use Case:** Retrieve historical emissions data for a county.

**Scenario:** You want to see overall CO2 equivalent emissions for Tompkins County, NY over multiple years.

```r
library(moveslite)
library(dplyr)

# Check API status first
check_status()

# Query overall emissions
data <- query(geoid = "36109",           # Tompkins County, NY
              pollutant = 98,            # CO2 Equivalent
              aggregation = 16,          # Overall
              var = c("year", "vmt", "vehicles", "emissions"))

# View the data
head(data)

# Plot emissions over time
library(ggplot2)
ggplot(data, aes(x = year, y = emissions)) +
  geom_line() +
  geom_point() +
  labs(title = "CO2e Emissions: Tompkins County, NY",
       x = "Year", y = "Emissions (metric tons)")
```

**Output:** A data frame with historical emissions, VMT, and vehicle counts by year.

---

## 2. Model Estimation and Evaluation

**Use Case:** Build a statistical model to predict emissions based on transportation activity.

**Scenario:** Estimate a model for Tompkins County using VMT and vehicle counts as predictors.

```r
# Query data
data <- query(geoid = "36109", 
              pollutant = 98, 
              aggregation = 16,
              var = c("year", "vmt", "vehicles", "sourcehours", "starts"))

# Estimate model with best formula
model <- estimate(data = data, 
                 .vars = c("vmt", "vehicles", "year", "sourcehours", "starts"))

# Evaluate model quality
library(broom)
model_stats <- glance(model)
print(model_stats)
# Look for: adj.r.squared (higher is better), sigma (lower is better)

# View model summary
summary(model)
```

**Key Metrics:**
- **Adjusted R-squared**: Proportion of variance explained (0-1, higher is better)
- **Sigma**: Residual standard error (lower is better)
- **p-values**: Significance of predictors

---

## 3. Scenario Analysis

**Use Case:** Predict emissions for a specific scenario with known VMT.

**Scenario:** You know VMT for 2023 and want to predict emissions.

```r
# Query baseline data
default <- query(geoid = "36109", 
                pollutant = 98, 
                aggregation = 16,
                var = c("year", "vmt", "vehicles", "sourcehours", "starts"))

# Estimate model
model <- estimate(data = default, 
                 .vars = c("vmt", "vehicles", "year"))

# Create scenario: VMT increases to 343,926
scenario <- tibble(year = 2023, vmt = 343926)

# Generate predictions
predictions <- project(m = model, 
                      data = default, 
                      .newx = scenario,
                      .context = TRUE)

# View custom scenario vs. benchmark
comparison <- predictions %>% 
  filter(type %in% c("custom", "benchmark"))

print(comparison)

# Visualize
ggplot(comparison, aes(x = year, y = emissions, color = type)) +
  geom_point(size = 3) +
  geom_line() +
  geom_ribbon(aes(ymin = lower, ymax = upper, fill = type), 
              alpha = 0.2) +
  labs(title = "Scenario vs. Benchmark: 2023",
       x = "Year", y = "Emissions (metric tons)")
```

**Output:** Predictions with confidence intervals comparing your scenario to the default projection.

---

## 4. Multi-Year Projections

**Use Case:** Project emissions for multiple years with different VMT scenarios.

**Scenario:** Evaluate a transportation plan with VMT projections for 2023-2025.

```r
# Query and estimate
default <- query(geoid = "36109", pollutant = 98, aggregation = 16,
                var = c("year", "vmt", "vehicles"))
model <- estimate(data = default, .vars = c("vmt", "year"))

# Create multi-year scenario
scenario <- tibble(
  year = c(2023, 2024, 2025),
  vmt = c(343926, 350000, 360000)  # Increasing VMT
)

# Generate predictions
predictions <- project(m = model, 
                      data = default, 
                      .newx = scenario,
                      .context = TRUE)

# Filter to custom and benchmark
comparison <- predictions %>% 
  filter(type %in% c("custom", "benchmark"))

# Visualize trend
ggplot(comparison, aes(x = year, y = emissions, color = type)) +
  geom_point(size = 3) +
  geom_line() +
  geom_ribbon(aes(ymin = lower, ymax = upper, fill = type), 
              alpha = 0.2) +
  labs(title = "Multi-Year Scenario: 2023-2025",
       x = "Year", y = "Emissions (metric tons)")
```

**Output:** Year-by-year predictions showing how your scenario differs from the default.

---

## 5. Sector-Specific Analysis

**Use Case:** Analyze emissions from a specific vehicle sector (e.g., public transit).

**Scenario:** Evaluate emissions from public transit (sourcetype 42) in Tompkins County.

```r
# Query public transit data
transit_data <- query(geoid = "36109",
                     pollutant = 98,
                     aggregation = 8,        # By sourcetype
                     sourcetype = 42,         # Public transit
                     var = c("year", "vmt", "vehicles", "emissions"))

# Estimate model
transit_model <- estimate(data = transit_data,
                          .vars = c("vmt", "vehicles", "year"))

# Scenario: Increase transit VMT by 20%
baseline_vmt <- transit_data %>% 
  filter(year == max(year)) %>% 
  pull(vmt)

scenario <- tibble(
  year = 2023,
  vmt = baseline_vmt * 1.2  # 20% increase
)

# Project
predictions <- project(m = transit_model,
                      data = transit_data,
                      .newx = scenario)

# Compare
predictions %>% 
  filter(type %in% c("custom", "benchmark")) %>%
  select(year, type, emissions, lower, upper)
```

**Output:** Sector-specific emissions predictions with confidence intervals.

---

## 6. Model Diagnostics

**Use Case:** Evaluate model quality and compare different model specifications.

**Scenario:** Test which variables produce the best model fit.

```r
# Query data
data <- query(geoid = "36109", pollutant = 98, aggregation = 16,
             var = c("year", "vmt", "vehicles", "sourcehours", "starts"))

# Test different model specifications
models <- list(
  "VMT only" = estimate(data, .vars = c("vmt"), .best = FALSE),
  "VMT + Year" = estimate(data, .vars = c("vmt", "year"), .best = FALSE),
  "VMT + Year + Vehicles" = estimate(data, .vars = c("vmt", "year", "vehicles"), .best = FALSE),
  "Best Model" = estimate(data, .vars = c("vmt", "vehicles", "year", "sourcehours", "starts"), .best = TRUE)
)

# Compare models
comparison <- map_dfr(models, glance, .id = "model") %>%
  select(model, adj.r.squared, sigma, df.residual) %>%
  arrange(desc(adj.r.squared))

print(comparison)

# Visualize
ggplot(comparison, aes(x = reorder(model, adj.r.squared), y = adj.r.squared)) +
  geom_col() +
  coord_flip() +
  labs(title = "Model Comparison: Adjusted R-squared",
       x = "Model", y = "Adjusted R-squared")
```

**Output:** Comparison table showing which model specification fits best.

---

## 7. Comparing Multiple Scenarios

**Use Case:** Evaluate multiple policy scenarios simultaneously.

**Scenario:** Compare three transportation policies with different VMT impacts.

```r
# Setup
default <- query(geoid = "36109", pollutant = 98, aggregation = 16,
                var = c("year", "vmt", "vehicles"))
model <- estimate(data = default, .vars = c("vmt", "year"))

# Define scenarios
scenarios <- list(
  "Baseline" = tibble(year = 2023, vmt = 300000),
  "Policy A: Transit Expansion" = tibble(year = 2023, vmt = 280000),  # -6.7%
  "Policy B: EV Incentives" = tibble(year = 2023, vmt = 310000),       # +3.3%
  "Policy C: TDM Programs" = tibble(year = 2023, vmt = 275000)         # -8.3%
)

# Generate predictions for each scenario
all_predictions <- map_dfr(scenarios, 
                          ~project(m = model, data = default, .newx = .x),
                          .id = "scenario")

# Compare
comparison <- all_predictions %>%
  filter(type == "custom") %>%
  select(scenario, emissions, lower, upper)

print(comparison)

# Visualize
ggplot(comparison, aes(x = reorder(scenario, emissions), y = emissions)) +
  geom_col() +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.2) +
  coord_flip() +
  labs(title = "Emissions Comparison: Policy Scenarios",
       x = "Scenario", y = "Emissions (metric tons)")
```

**Output:** Side-by-side comparison of emissions impacts for different policies.

---

## Advanced Use Cases

### Batch Processing Multiple Counties

```r
# Process multiple counties
counties <- c("36109", "36027", "36067")  # Tompkins, Dutchess, Monroe

results <- map_dfr(counties, function(geoid) {
  data <- query(geoid = geoid, pollutant = 98, aggregation = 16,
               var = c("year", "vmt", "emissions"))
  model <- estimate(data, .vars = c("vmt", "year"))
  scenario <- tibble(year = 2023, vmt = 300000)
  predictions <- project(m = model, data = data, .newx = scenario)
  predictions %>%
    filter(type == "custom") %>%
    mutate(geoid = geoid)
}, .id = "county_id")
```

### Custom Model Formula

```r
# Use custom formula instead of best model
data <- query(geoid = "36109", pollutant = 98, aggregation = 16,
             var = c("year", "vmt", "vehicles"))

# Estimate with custom variables
model <- estimate(data = data, 
                 .vars = c("vmt", "year"), 
                 .best = FALSE)  # Uses custom formula construction
```

### Working with Different Pollutants

```r
# Query different pollutants (see MOVES cheatsheet for codes)
# CO2e = 98, CO = 2, NOx = 3, PM2.5 = 110, etc.

co2_data <- query(geoid = "36109", pollutant = 98, aggregation = 16)
nox_data <- query(geoid = "36109", pollutant = 3, aggregation = 16)

# Compare emissions
bind_rows(
  co2_data %>% mutate(pollutant = "CO2e"),
  nox_data %>% mutate(pollutant = "NOx")
) %>%
  ggplot(aes(x = year, y = emissions, color = pollutant)) +
  geom_line() +
  facet_wrap(~pollutant, scales = "free_y")
```

---

## Tips and Best Practices

1. **Always check API status first**: `check_status()` warms up the API
2. **Cache query results**: Save data frames to avoid repeated API calls
3. **Start simple**: Begin with overall aggregation (16) before drilling down
4. **Check model quality**: Use `glance()` to evaluate fit before making predictions
5. **Use context**: Set `.context = TRUE` in `project()` to see benchmark years
6. **Interpret confidence intervals**: Wider intervals indicate more uncertainty
7. **Validate assumptions**: Check that your scenario variables are reasonable

---

## Common Issues and Solutions

### Issue: API Timeout
**Solution:** Run `check_status()` first, or reduce query complexity.

### Issue: Poor Model Fit (low R-squared)
**Solution:** Try different variable combinations, or use `.best = TRUE`.

### Issue: Missing Years in Predictions
**Solution:** Ensure your scenario years are within the data range, or use interpolation.

### Issue: Confidence Intervals Too Wide
**Solution:** This may indicate model uncertainty; consider adding more predictor variables or checking data quality.





