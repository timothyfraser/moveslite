#' @name default_base_url
#' @title default_base_url()
#' @author Tim Fraser
#' @description
#' Internal helper. Returns the default base URL for the CAT Public API,
#' in this order of precedence:
#' 1. the `moveslite.base_url` option (eg. `options(moveslite.base_url = "https://connect.systems-apps.com/catplatform-public/")`)
#' 2. the `MOVESLITE_BASE_URL` environment variable
#' 3. the historical default, `"https://api.cat-apps.com/"`
#' @keywords internal
default_base_url = function(){
  getOption("moveslite.base_url", Sys.getenv("MOVESLITE_BASE_URL", "https://api.cat-apps.com/"))
}

#' @name normalize_base_url
#' @title normalize_base_url()
#' @author Tim Fraser
#' @description
#' Internal helper. Cleans up a user-supplied base URL so that it always ends
#' in exactly one trailing slash. This means `"https://x"` and `"https://x/"`
#' both work when pasted together with an endpoint. Empty, `NA`, or `NULL`
#' values fall back to the historical default.
#' @param base_url Base URL of the API, eg. `"https://api.cat-apps.com/"`.
#' @keywords internal
normalize_base_url = function(base_url){
  # If nothing usable was supplied, fall back to the historical default
  if(is.null(base_url)){ base_url = "https://api.cat-apps.com/" }
  if(length(base_url) != 1){ base_url = "https://api.cat-apps.com/" }
  if(is.na(base_url) || base_url == ""){ base_url = "https://api.cat-apps.com/" }
  # Strip any trailing slashes, then add exactly one back
  base_url = sub("/+$", "", base_url)
  url = paste0(base_url, "/")
  return(url)
}

#' @name check_response
#' @title check_response()
#' @author Tim Fraser
#' @description
#' Internal helper. Raises an informative error if an API request did not
#' return HTTP 200, reporting the status code, the URL requested, and the
#' first 200 characters of the response body. Previously, failed requests
#' were returned silently as raw `httr` response objects.
#' @param result An `httr` response object.
#' @param url The URL that was requested.
#' @keywords internal
check_response = function(result, url){
  if(result$status_code == 200){ return(invisible(TRUE)) }
  # Try to read the body; if it isn't text, say so rather than erroring here
  body = tryCatch(rawToChar(result$content), error = function(e){ "<unreadable response body>" })
  if(is.na(body) || body == ""){ body = "<empty response body>" }
  body = substr(body, 1, 200)
  stop(paste0(
    "moveslite API request failed with HTTP status ", result$status_code, ".\n",
    "  URL: ", url, "\n",
    "  Response (first 200 chars): ", body
  ), call. = FALSE)
}

#' @name check_status
#' @title check_status()
#' @author Tim Fraser
#' @description
#' Function to query the CAT Public API and check the status of CATSERVER.
#' Handy helper function that, if you run before using the optimizer,
#' will ensure that the API is warmed up and ready to go for you.
#' @param base_url Base URL of the CAT Public API. Defaults to the
#' `moveslite.base_url` option, then the `MOVESLITE_BASE_URL` environment
#' variable, then `"https://api.cat-apps.com/"`. A trailing slash is optional.
#' @importFrom httr GET add_headers config timeout
#' @importFrom readr read_csv
#' @export
check_status = function(base_url = default_base_url()){
  base = normalize_base_url(base_url)
  endpoint = "status/"
  # Build full URL
  url = paste0(base, endpoint)
  # Add Header
  headers = add_headers("Content-Type" = "text/csv")
  # Send it!
  # Make the request timeout after 10 seconds.
  result = GET(url = url, headers, encode = "json", config(timeout(10)))
  # Error informatively if the request failed
  check_response(result, url)
  # Convert from raw to character
  output = rawToChar(result$content)
  # Parse as csv
  output = read_csv(output, show_col_types = FALSE)
  # Return
  return(output)
}

#' @name query
#' @title query()
#' @author Tim Fraser
#' @description Function to query catserver using CAT Public API.
#* @param geoid Unique 5-digit county or 2-digit state geoid. Example: "36109" is Tompkins County, NY.
#* @param pollutant EPA pollutant code from MOVES software. Example: 98 is CO2 Equivalent Emissions.
#* @param aggregation ID of Aggregation Level (overall = `16`, by sourcetype = `8`, by fueltype = `14`, by regulatory class = `12`, overall with sourcetype = `17`, overall with regulatory class = `18`, overall with fueltype = `19`, overall with roadtype = `20`, overall with sourcetype and fueltype = `21`)
#* @param var Name(s) of variables to return for MOVESLite analysis.
#* @param sourcetype EPA sourcetype ID.
#* @param regclass EPA regulatory class ID.
#* @param fueltype EPA fueltype ID.
#* @param roadtype EPA roadtype ID.
#' @param base_url Base URL of the CAT Public API. Defaults to the
#' `moveslite.base_url` option, then the `MOVESLITE_BASE_URL` environment
#' variable, then `"https://api.cat-apps.com/"`. A trailing slash is optional,
#' so both `"https://x"` and `"https://x/"` work. Use this to point the client
#' at a replica, eg. `"https://connect.systems-apps.com/catplatform-public"`.
#' @importFrom httr GET add_headers
#' @importFrom readr read_csv
#' @export
query = function(geoid = "36109",
                  pollutant = 98,
                  aggregation = 16,
                  var = c("year", "vmt", "vehicles", "starts", "sourcehours"),
                  sourcetype = NA,
                  regclass = NA,
                  fueltype = NA,
                  roadtype = NA,
                  base_url = default_base_url()){
  # Testing values
  # geoid = "36109"; pollutant = 98; aggregation = 16; var = c("year", "vmt", "vehicles", "starts", "sourcehours"); sourcetype = NA; regclass = NA; fueltype = NA; roadtype = NA
  # geoid = "36109"; pollutant = 98; aggregation = 8; var = c("year", "vmt", "vehicles", "starts", "sourcehours"); sourcetype = 21; regclass = NA; fueltype = NA; roadtype = NA
  # geoid = "36109"; pollutant = 98; aggregation = 8; var = c("year", "vmt", "vehicles", "starts", "sourcehours"); sourcetype = c(21,31); regclass = NA; fueltype = NA; roadtype = NA

  # Get base URL for api and endpoint
  base = normalize_base_url(base_url)
  endpoint = "moveslite/v1/retrieve_data/"

  query = paste0("?geoid=", geoid)
  if(!is.na(pollutant)){ query = paste0(query, "&pollutant=", pollutant)}
  if(!is.na(aggregation)){ query = paste0(query, "&aggregation=", aggregation) }
  # For as many IDs as are provided, concatenate them...
  if(any(!is.na(sourcetype))){ query = paste0(query, paste0(paste0("&sourcetype=", sourcetype), collapse = ""))}
  if(any(!is.na(fueltype))){ query = paste0(query, paste0(paste0("&fueltype=", fueltype), collapse = ""))}
  if(any(!is.na(regclass))){ query = paste0(query, paste0(paste0("&regclass=", regclass), collapse = ""))}
  if(any(!is.na(roadtype)) ){ query = paste0(query, paste0(paste0("&roadtype=", roadtype), collapse = ""))}
  # For as many variables as are provided...
  if(any(!is.na(var)) ){  query = paste0(query,   paste0( paste0("&var=", var), collapse = "")) }

  # Build full URL
  url = paste0(base, endpoint, query)

  # Add Header
  headers = add_headers("Content-Type" = "text/csv")

  # Send it! Make the request time out after 10 seconds.
  result = GET(url = url, headers, encode = "json", config(timeout(10)))

  # If the query failed, stop with an informative error.
  # (Prior to v0.2.0, this silently returned the raw httr response object.)
  check_response(result, url)

  # Convert from raw to character
  output = rawToChar(result$content)

  # Parse as csv
  output = read_csv(output, show_col_types = FALSE)

  # Return
  return(output)

}



#' @name get_default
#' @title `get_default()`
#' @author Tim
#' @description
#' Produces `default()` input data for a given CATSERVER query.
#' This data.frame is used to populate the original table and makes the benchmark scenario in the lineplot.
#' @param .scenario eg. granddata.d36109
#' @param .pollutant eg. 98
#' @param .by eg. 8.41 --> look at moveslite::choices_aggregation for values. Some are single values (by = 16), while others are combinations like 8.41 (by = 8 for sourcetype 41)
#' @param base_url Base URL of the CAT Public API, passed through to [query()].
#' Defaults to the `moveslite.base_url` option, then the `MOVESLITE_BASE_URL`
#' environment variable, then `"https://api.cat-apps.com/"`.
#'
#' @importFrom dplyr `%>%` select any_of
#' @importFrom stringr str_remove str_split
#'
#' @export
get_default = function(.scenario = "granddata.d36109", .pollutant = 98, .by = "8.41",
                       base_url = default_base_url()){
  # Testing values
  # input = list(scenario = "granddata.d36109", pollutant = 98, by = choices_aggregation[[2]][5])
  # input = list(scenario = "granddata.dXXXXX", pollutant = 98, by = choices_aggregation[[2]][5])

  # .scenario = "granddata.d36109"; .pollutant = 98; .by = "8.41"

  # Get data
  # .scenario = input$scenario
  # .pollutant = input$pollutant
  # .by = input$by

  # Derive inputs
  .dbname = stringr::str_remove(.scenario, pattern = "[.].*")
  .table = stringr::str_remove(.scenario, pattern = paste0(.dbname, "[.]"))
  .geoid = stringr::str_extract(.table, pattern = "d[0-9]+") %>% stringr::str_remove("d")

  .byvalues = stringr::str_split(string = .by, pattern = "[.]") %>% unlist()
  .byid = as.integer(.byvalues[[1]])
  # Build initial filter
  .filters = list(.pollutant = .pollutant, .by = .byid,
                  .sourcetype = NA_integer_,
                  .fueltype = NA_integer_,
                  .regclass = NA_integer_,
                  .roadtype = NA_integer_)
  # If there are 2 byvalues, grab the second; otherwise, leave it null
  if(length(.byvalues) > 1){

    .bytype = as.integer(.byvalues[[2]])
    if(.byid == 14){ .filters$.fueltype = .bytype }
    if(.byid == 8){ .filters$.sourcetype = .bytype }
    if(.byid == 15){ .filters$.roadtype = .bytype }
    if(.byid == 12){ .filters$.regclass = .bytype }
  }

  # Query CATSERVER via API
  output = query(geoid = .geoid, pollutant = .filters$.pollutant, aggregation = .filters$.by,
         sourcetype = .filters$.sourcetype, fueltype = .filters$.fueltype,
         regclass = .filters$.regclass, roadtype = .filters$.roadtype,
         base_url = base_url)

  output = output %>%
    select(-any_of("geoid"))

  return(output)
}


