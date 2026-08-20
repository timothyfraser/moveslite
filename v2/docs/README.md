# moveslite v2 Documentation

## Overview

`moveslite` v2 is an R package for fast transportation emissions estimation based on statistical models built from EPA MOVES (Motor Vehicle Emission Simulator) data compiled by the Cornell Climate Action in Transportation (CAT) Team. The package provides rapid emissions predictions for any US county, enabling scenario analysis and policy evaluation within seconds rather than hours.

## Purpose

The goal of `moveslite` is to provide fast, highly accurate predictions of emissions tailored to a user's county. While generating MOVES data is extremely time-consuming, `moveslite` builds statistical models that approximate MOVES data, allowing for rapid comparison of multiple scenarios within seconds. This enables fast, data-driven decision-making using computational methods built atop the EPA's MOVES model, the gold standard in the US for emissions modeling and regulatory compliance.

## Key Features

- **Fast API-based queries** to the CAT Platform's public API
- **Configurable API host** via the `base_url` argument, the `moveslite.base_url`
  option, or the `MOVESLITE_BASE_URL` environment variable
- **Statistical modeling** using linear regression with polynomial transformations
- **Flexible aggregation levels** (overall, by sourcetype, fueltype, regulatory class, or roadtype)
- **Scenario projection** with confidence intervals
- **Model diagnostics** for evaluating fit quality
- **Automatic back-transformation** of log-transformed predictions

## Documentation Structure

This documentation is organized into the following sections:

1. **[Functions Reference](functions.md)** - Detailed documentation of all exported functions
2. **[Architecture](architecture.md)** - Package structure and data flow
3. **[Use Cases](use_cases.md)** - Practical examples and workflows

## Quick Start

```r
# Install and load the package
library(moveslite)

# Optional: point the client at a specific host
options(moveslite.base_url = "https://cat-apps.com/cat-public/")

# Check API status
check_status()

# Query data for a county (Tompkins County, NY). The default model uses all
# five activity measures, so ask for all five.
data <- query(geoid = "36109", pollutant = 98, aggregation = 16,
              var = c("year", "vmt", "vehicles", "starts", "sourcehours"))

# Estimate a model
model <- estimate(data = data)

# Generate predictions for a custom scenario
predictions <- project(m = model, data = data, 
                       .newx = tibble(year = 2023, vmt = 343926))
```

## Package Version

This documentation covers **moveslite 0.2.0** — see [`../NEWS.md`](../NEWS.md)
for what changed.

## Additional Resources

- MOVES Cheatsheet: [EPA MOVES Model Documentation](https://github.com/USEPA/EPA_MOVES_Model/blob/master/docs/MOVES4CheatsheetOnroad.pdf)
- FIPS County Codes: [Census Bureau FIPS Codes](https://www2.census.gov/programs-surveys/decennial/2010/partners/pdf/FIPS_StateCounty_Code.pdf)
- CAT Platform: <https://cat-apps.com>
- `moveslite` guide on the platform: <https://connect.systems-apps.com/cat/#/docs/moveslite>
- Public API reference: <https://connect.systems-apps.com/cat/#/docs/api-reference>





