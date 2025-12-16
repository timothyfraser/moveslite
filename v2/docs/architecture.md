# moveslite v2 Architecture

## Package Overview

`moveslite` v2 is designed as a streamlined, API-based package that connects to the Cornell CATSERVER database to provide fast emissions estimates. The architecture emphasizes simplicity, speed, and ease of use compared to v1.

## Core Components

### 1. Data Layer

#### CAT Public API
- **Base URL**: `https://api.cat-apps.com/`
- **Endpoints**:
  - `/status/` - API health check
  - `/moveslite/v1/retrieve_data/` - Data retrieval

#### Data Structure
- **Geographic Scope**: All US counties (5-digit FIPS codes) and states (2-digit FIPS codes)
- **Time Range**: Multiple years of historical MOVES data
- **Aggregation Levels**: Overall, by sourcetype, fueltype, regulatory class, roadtype
- **Variables**: `year`, `vmt`, `vehicles`, `starts`, `sourcehours`, `emissions`, etc.

### 2. Query Layer

```
User Input
    ↓
query() / get_default()
    ↓
CAT Public API
    ↓
Data Frame (tibble)
```

**Key Functions:**
- `check_status()` - API health check
- `query()` - Direct API query with filters
- `get_default()` - Wrapper for scenario-based queries

### 3. Modeling Layer

```
Data Frame
    ↓
estimate()
    ↓
Linear Model (lm)
```

**Model Specifications:**
- **Default/Best Model** (`.best = TRUE`):
  ```
  log(emissions) ~ poly(log(vmt),3) + poly(year,2) + vehicles + sourcehours + starts
  ```
- **Custom Models** (`.best = FALSE`): User-specified variable combinations

**Key Features:**
- Log transformation of outcome for skewness correction
- Polynomial terms for non-linear relationships
- Multiple predictor variables

### 4. Prediction Layer

```
Model + Original Data + New Values
    ↓
setx() - Prepare newdata
    ↓
predict() - Generate predictions
    ↓
find_transformation() - Detect outcome transformation
    ↓
convert() - Back-transform if needed
    ↓
project() - Return predictions with CI
```

**Data Flow:**
1. **setx()** creates `newdata` with:
   - Custom values from user input
   - Interpolated default values for missing variables
   - Context years (pre/post benchmark) if requested

2. **predict()** generates predictions on transformed scale

3. **find_transformation()** detects if outcome was transformed (e.g., `log(emissions)`)

4. **convert()** (if needed) back-transforms predictions and confidence intervals using simulation

5. **project()** returns final predictions with:
   - Custom scenario predictions
   - Benchmark predictions
   - Confidence intervals

### 5. Diagnostic Layer

```
Model + Formula
    ↓
diagnose() / diagnose_many()
    ↓
Goodness of Fit Metrics
```

**Diagnostic Functions:**
- `diagnose()` - Single formula evaluation
- `diagnose_many()` - Multiple formula comparison
- `tabler()` - Quick diagnostic table

**Metrics Returned:**
- Adjusted R-squared
- Residual standard error (sigma)
- Residual degrees of freedom

## Data Flow Diagram

```
┌─────────────────┐
│   User Input    │
│  (geoid, etc.)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   query()       │─────────┐
│   API Query     │         │
└────────┬────────┘         │
         │                   │
         ▼                   │
┌─────────────────┐         │
│   Data Frame    │         │
│   (tibble)      │         │
└────────┬────────┘         │
         │                   │
         ▼                   │
┌─────────────────┐         │
│   estimate()    │         │
│   Build Model   │         │
└────────┬────────┘         │
         │                   │
         ▼                   │
┌─────────────────┐         │
│   Model Object  │         │
│   (lm)          │         │
└────────┬────────┘         │
         │                   │
         │                   │
         ▼                   ▼
┌─────────────────────────────────┐
│         project()                │
│  ┌───────────────────────────┐  │
│  │  setx() - Prepare newdata │  │
│  └───────────┬───────────────┘  │
│              ▼                   │
│  ┌───────────────────────────┐  │
│  │  predict() - Get estimates│  │
│  └───────────┬───────────────┘  │
│              ▼                   │
│  ┌───────────────────────────┐  │
│  │ find_transformation()     │  │
│  └───────────┬───────────────┘  │
│              ▼                   │
│  ┌───────────────────────────┐  │
│  │ convert() - Back-transform│  │
│  └───────────┬───────────────┘  │
│              ▼                   │
│  └───────────────────────────┘  │
└──────────────┬───────────────────┘
               │
               ▼
      ┌─────────────────┐
      │   Predictions   │
      │  with CI, type  │
      └─────────────────┘
```

## Key Design Decisions

### 1. API-Based Architecture
- **Why**: Eliminates need for local database connections
- **Benefit**: Easier setup, always up-to-date data
- **Trade-off**: Requires internet connection

### 2. Statistical Modeling
- **Why**: MOVES runs are computationally expensive
- **Benefit**: Fast predictions (seconds vs. hours)
- **Approach**: Linear regression with transformations and polynomial terms

### 3. Log Transformation
- **Why**: Emissions data is highly skewed
- **Benefit**: Better model fit, more stable predictions
- **Handling**: Automatic detection and back-transformation

### 4. Interpolation for Missing Variables
- **Why**: Users may only know some variables (e.g., VMT)
- **Benefit**: Flexible scenario specification
- **Method**: Linear interpolation using `approxfun()`

### 5. Simulation for Back-Transformation
- **Why**: Direct back-transformation of confidence intervals is biased
- **Benefit**: Accurate uncertainty quantification
- **Method**: 1000 draws from t-distribution

## Package Dependencies

### Core Dependencies
- `dplyr` - Data manipulation
- `broom` - Model tidying
- `stats` - Statistical modeling (lm, predict)
- `httr` - API requests
- `readr` - CSV parsing
- `purrr` - Functional programming

### Optional Dependencies
- `DBI` - Database connections (for v1 compatibility functions)

## Comparison: v1 vs v2

### v1 Features (Not in v2)
- Direct database connections (`connect()`)
- Local SQLite database support
- More complex diagnostic workflows

### v2 Improvements
- Simplified API-only interface
- Streamlined workflow (fewer functions)
- Better error handling
- Automatic transformation detection
- Built-in confidence intervals

## Extension Points

The architecture supports extension in several areas:

1. **Custom Model Formulas**: Users can specify custom formulas via `.best = FALSE`
2. **Additional Variables**: Support for more MOVES variables can be added
3. **Different Aggregations**: New aggregation levels can be queried
4. **Alternative Models**: The `estimate()` function can be extended to support other model types

## Error Handling

- **API Timeouts**: 10-second timeout on all API requests
- **Failed Queries**: Returns HTTP response object instead of data frame
- **Model Fitting**: `diagnose()` uses `purrr::possibly()` for graceful failure
- **Missing Data**: Linear interpolation handles missing years

## Performance Considerations

1. **API Warming**: `check_status()` recommended before first query
2. **Batch Queries**: Consider caching results for repeated analyses
3. **Model Complexity**: Simpler models (fewer variables) fit faster
4. **Simulation Size**: `convert()` uses 1000 draws (balance between speed and accuracy)





