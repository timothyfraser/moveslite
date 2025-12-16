# moveslite v2 Functions Reference

## Core Workflow Functions

### Data Query Functions

#### `check_status()`
**Purpose:** Check the status of the CAT Public API and warm it up.

**Description:** Handy helper function that ensures the API is ready before running queries. Useful for warming up the API connection.

**Parameters:** None

**Returns:** A data frame with API status information

**Example:**
```r
check_status()
```

---

#### `query()`
**Purpose:** Query the CATSERVER database via the CAT Public API to retrieve MOVES emissions data.

**Parameters:**
- `geoid` (character): Unique 5-digit county or 2-digit state FIPS code. Default: `"36109"` (Tompkins County, NY)
- `pollutant` (integer): EPA pollutant code from MOVES software. Default: `98` (CO2 Equivalent Emissions)
- `aggregation` (integer): Aggregation level ID. Options:
  - `16` = Overall
  - `8` = By Sourcetype
  - `12` = By Regulatory Class
  - `14` = By Fueltype
  - `15` = By Roadtype
  - `17` = Overall with Sourcetype
  - `18` = Overall with Regulatory Class
  - `19` = Overall with Fueltype
  - `20` = Overall with Roadtype
  - `21` = Overall with Sourcetype and Fueltype
- `var` (character vector): Variable names to return. Default: `c("year", "vmt", "vehicles", "starts", "sourcehours")`
- `sourcetype` (integer, optional): EPA sourcetype ID
- `regclass` (integer, optional): EPA regulatory class ID
- `fueltype` (integer, optional): EPA fueltype ID
- `roadtype` (integer, optional): EPA roadtype ID

**Returns:** A tibble with queried data or an HTTP response object if the query fails

**Example:**
```r
# Overall CO2e emissions for Tompkins County
data <- query(geoid = "36109", pollutant = 98, aggregation = 16, 
              var = c("year", "vmt", "vehicles"))

# CO2e emissions by sourcetype
data <- query(geoid = "36109", pollutant = 98, aggregation = 8, 
              var = c("year", "vmt", "vehicles"))

# Specific sourcetypes (Public Transit = 42)
data <- query(geoid = "36109", pollutant = 98, aggregation = 8, 
              sourcetype = c(21, 31), var = c("year", "vmt", "vehicles"))
```

---

#### `get_default()`
**Purpose:** Produces default input data for a given CATSERVER query scenario.

**Parameters:**
- `.scenario` (character): Scenario identifier, e.g., `"granddata.d36109"`
- `.pollutant` (integer): Pollutant code, e.g., `98`
- `.by` (character): Aggregation specification, e.g., `"8.41"` (sourcetype 8, type 41)

**Returns:** A data frame with default/baseline data

**Note:** This function parses scenario strings to extract geoid and aggregation information, then calls `query()` internally.

---

### Modeling Functions

#### `estimate()`
**Purpose:** Estimate a statistical model from queried MOVES data.

**Parameters:**
- `data` (data.frame): Data frame from `query()` containing MOVES emissions data
- `.vars` (character vector): Variables to use as predictors. Default: `c("vmt", "vehicles", "starts", "sourcehours", "year")`
- `.best` (logical): If `TRUE`, uses the best-fitting model formula from the moveslite paper. Default: `TRUE`

**Model Formula (when `.best = TRUE`):**
```
log(emissions) ~ poly(log(vmt),3) + poly(year,2) + vehicles + sourcehours + starts
```

**Returns:** An `lm` (linear model) object

**Example:**
```r
# Estimate model with default best formula
model <- estimate(data = data, .vars = c("vmt", "vehicles", "year"))

# Estimate model with custom variables
model <- estimate(data = data, .vars = c("vmt", "year"), .best = FALSE)

# View model quality
library(broom)
glance(model)
```

---

#### `project()`
**Purpose:** Generate emissions predictions for custom scenarios using an estimated model.

**Parameters:**
- `m`: Model object from `estimate()`
- `data`: Original data frame from `query()` (used as benchmark)
- `.newx`: Data frame, named vector, or list of new values for predictor variables
- `.cats` (character vector): Stratifying variable names (e.g., `"year"`). Default: `"year"`
- `.exclude` (character vector): Variable names to exclude. Default: `"geoid"`
- `.context` (logical): If `TRUE`, includes pre-benchmark and post-benchmark years for context. Default: `TRUE`
- `.ci` (numeric): Confidence interval level. Default: `0.95`

**Returns:** A data frame with predictions including:
- `emissions`: Predicted emissions
- `lower`: Lower confidence bound
- `upper`: Upper confidence bound
- `se`: Standard error
- `type`: Type of prediction (`"custom"`, `"benchmark"`, `"pre_benchmark"`, `"post_benchmark"`)
- Other columns from the original data

**Example:**
```r
# Single year prediction
predictions <- project(m = model, data = data, 
                       .newx = tibble(year = 2023, vmt = 343926))

# Multiple years
predictions <- project(m = model, data = data, 
                       .newx = tibble(year = c(2023:2024), 
                                     vmt = c(23023023, 234023402)))

# Filter to custom and benchmark
predictions %>% filter(type %in% c("custom", "benchmark"))
```

---

### Data Preparation Functions

#### `setx()`
**Purpose:** Create a data frame of `newdata` to pass to a model, filling in missing values with defaults from the original data.

**Parameters:**
- `data`: Data frame from `query()` containing default/baseline data
- `.newx`: Data frame, named vector, or list of new values for predictor variables
- `.cats` (character vector): Stratifying variable names. Default: `"year"`
- `.exclude` (character vector): Variable names to exclude. Default: `c("geoid")`
- `.context` (logical): If `TRUE`, includes pre-benchmark and post-benchmark years. Default: `TRUE`

**Returns:** A data frame with:
- `type`: `"custom"` for user-provided values, `"benchmark"` for interpolated defaults, `"pre_benchmark"` and `"post_benchmark"` for context years
- All predictor variables, with interpolated values for missing variables

**Note:** Uses linear interpolation (`approxfun`) to estimate missing variable values for custom years.

**Example:**
```r
newdata <- setx(data = default_data, 
                .newx = tibble(year = 2023, vmt = 343926),
                .context = TRUE)
```

---

### Diagnostic Functions

#### `diagnose()`
**Purpose:** Evaluate the goodness of fit for a single model formula.

**Parameters:**
- `.data`: Data frame with MOVES data
- `.formula`: Statistical formula (e.g., `emissions ~ year + vmt`)
- `.pollutant`: Pollutant code
- `.by`: Aggregation level ID
- `.geoid`: County/state geoid

**Returns:** A tibble with diagnostic metrics:
- `geoid`: Geographic identifier
- `by`: Aggregation level
- `pollutant`: Pollutant code
- `adjr`: Adjusted R-squared
- `sigma`: Residual standard error
- `df.residual`: Residual degrees of freedom
- `formula`: Formula string

**Example:**
```r
diagnosis <- diagnose(.data = data, 
                      .formula = emissions ~ year + poly(vmt, 3),
                      .pollutant = 98, 
                      .by = 8, 
                      .geoid = "36109")
```

---

#### `diagnose_many()`
**Purpose:** Evaluate the goodness of fit for multiple model formulas.

**Parameters:**
- `.geoid`: Geographic identifier. Default: `"36109"`
- `.pollutant`: Pollutant code. Default: `98`
- `.by`: Aggregation level. Default: `8`
- `.type`: Type identifier (depends on `.by`). Default: `42`
- `.formulas`: List of formulas to test

**Returns:** A tibble with diagnostics for all formulas, sorted by adjusted R-squared (descending)

**Note:** Requires database connection functions (from v1). Filters out formulas that fail to fit.

---

#### `tabler()`
**Purpose:** Generate a diagnostic table comparing multiple model formulas.

**Parameters:**
- `.geoid`: Geographic identifier. Default: `"36109"`
- `.pollutant`: Pollutant code. Default: `98`
- `.by`: Aggregation level. Default: `8`
- `.type`: Type identifier. Default: `42`

**Returns:** A tibble comparing default formulas with diagnostics

**Note:** Tests a fixed set of formulas: `emissions ~ year + poly(vmt, 3)`, `emissions ~ year + poly(vmt, 2)`, `emissions ~ year + poly(vmt, 1)`

---

### Utility Functions

#### `find_transformation()`
**Purpose:** Detect the transformation applied to the model outcome (if any).

**Parameters:**
- `m`: Model object from `estimate()`

**Returns:** A list with:
- `trans`: Transformation type (`"log"`, `"log10"`, `"sqrt"`, `"asis"`, etc.)
- `backtrans`: Back-transformation expression (e.g., `"exp(y)"`)
- `pattern`: Pattern used to detect the transformation

**Example:**
```r
trans_info <- find_transformation(model)
# Returns: list(trans = "log", backtrans = "exp(y)", ...)
```

---

#### `convert()`
**Purpose:** Convert outcome predictions and standard errors back from a transformation using simulation.

**Parameters:**
- `y`: Emission estimate (transformed scale)
- `se`: Standard error
- `backtrans`: Back-transformation expression (e.g., `"exp(y)"`)
- `df`: Degrees of freedom
- `ci`: Confidence interval level. Default: `0.95`

**Returns:** A tibble with:
- `emissions`: Back-transformed estimate
- `se`: Back-transformed standard error
- `lower`: Lower confidence bound
- `upper`: Upper confidence bound

**Note:** Uses simulation (1000 draws) with t-distribution to account for uncertainty in back-transformation.

---

#### `table_exists()`
**Purpose:** Check if a database table exists (internal utility).

**Note:** This function is exported but primarily used internally for database operations.

---

## Function Dependencies

The core workflow follows this pattern:

1. **Query Data**: `query()` or `get_default()` → returns data frame
2. **Estimate Model**: `estimate()` → returns model object
3. **Prepare New Data**: `setx()` (called internally by `project()`) → returns newdata
4. **Generate Predictions**: `project()` → returns predictions with confidence intervals
5. **Evaluate Model**: `diagnose()` or `diagnose_many()` → returns diagnostics

The `project()` function automatically:
- Calls `setx()` to prepare new data
- Calls `find_transformation()` to detect outcome transformation
- Calls `convert()` if transformation is detected
- Returns predictions with confidence intervals





