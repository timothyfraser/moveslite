# moveslite 0.2.0

## Configurable API base URL

* `query()`, `check_status()`, and `get_default()` gain a `base_url` argument.
  The API host is no longer hardcoded to `https://api.cat-apps.com/`.
* `base_url` defaults to, in order of precedence:
  1. the `moveslite.base_url` option --
     eg. `options(moveslite.base_url = "https://connect.systems-apps.com/catplatform-public/")`
  2. the `MOVESLITE_BASE_URL` environment variable
  3. `"https://api.cat-apps.com/"`, the historical default
* Trailing slashes are normalized, so `"https://x"` and `"https://x/"` both
  work. Base URLs with a path prefix (eg.
  `https://connect.systems-apps.com/catplatform-public`) are supported, which
  makes it possible to point the client at a replica of the API.
* This is backwards compatible: zero-argument calls behave exactly as before.

## Stricter error handling

* On a non-200 response, `query()` and `check_status()` now raise an
  informative error reporting the HTTP status code, the URL requested, and the
  first 200 characters of the response body. Previously, `query()` silently
  returned the raw `httr` response object, which downstream code could easily
  mistake for data.

# moveslite 0.1.0

* Initial version.
