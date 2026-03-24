# Scrape Data Feature — Implementation Summary

**Branch:** `development/white_label`

---

## Overview

Extended the existing Knowledge Base settings page with a **Scrape Data** button. Admins can trigger a background web scrape of their saved website URL. The scraper runs as a separate FastAPI microservice; Rails acts as a secure proxy so the browser never communicates with the scraper directly. Scraped pages are saved automatically as Knowledge Base entries. The UI polls for live progress every 3 seconds and refreshes the entries list automatically when the job completes.

---

## Architecture

```
Browser (Vue)
    │
    │  POST /api/v1/accounts/:id/scrape
    │  GET  /api/v1/accounts/:id/scrape_status
    ▼
Rails API (proxy)
    │
    │  POST http://SCRAPER_SERVICE_URL/scrape
    │  GET  http://SCRAPER_SERVICE_URL/scrape/:id/status
    ▼
FastAPI Microservice (scraper_service/)
    │
    │  POST /api/v1/accounts/:id/knowledge_base_entries
    ▼
Rails API (entries callback)
    │
    ▼
Database (knowledge_base_entries table)
```

---

## Files Changed

| File Path | Action | What Changed |
|-----------|--------|--------------|
| `config/initializers/scraper.rb` | **NEW** | Reads `SCRAPER_SERVICE_URL` from ENV at boot |
| `config/routes.rb` | MODIFIED | Added `post :scrape` and `get :scrape_status` member routes |
| `app/controllers/api/v1/accounts_controller.rb` | MODIFIED | Added `scrape` and `scrape_status` actions |
| `app/javascript/dashboard/api/account.js` | MODIFIED | Added `triggerScrape()` and `scrapeStatus()` API methods |
| `app/javascript/dashboard/store/modules/accounts.js` | MODIFIED | Added `scrapeJob` state, `getScrapeJob` getter, `triggerScrape` and `pollScrapeStatus` actions, `SET_SCRAPE_JOB` mutation |
| `app/javascript/dashboard/store/mutation-types.js` | MODIFIED | Added `SET_SCRAPE_JOB` constant |
| `app/javascript/dashboard/routes/dashboard/settings/knowledgeBase/Index.vue` | MODIFIED | Added Scrape button, live status banner, auto-refresh on completion |
| `app/javascript/dashboard/i18n/locale/en/generalSettings.json` | MODIFIED | Added scrape UI translation keys |

---

## Backend Changes

### `config/initializers/scraper.rb` *(NEW)*

```ruby
SCRAPER_SERVICE_URL = ENV.fetch('SCRAPER_SERVICE_URL', nil)
```

Set `SCRAPER_SERVICE_URL=http://your-scraper-host:8088` in your `.env` or deployment config. If the variable is not set, the scrape endpoints return `503 Service Unavailable`.

---

### `config/routes.rb`

Find the existing `resources :accounts` member block and add two new routes:

```ruby
resources :accounts, only: [:create, :show, :update] do
  member do
    post :update_active_at
    get  :cache_keys
    delete :logo
    post :scrape           # NEW
    get  :scrape_status    # NEW
  end
end
```

---

### `app/controllers/api/v1/accounts_controller.rb`

Add near the top of the file:

```ruby
require 'net/http'
require 'json'
```

Add two new actions inside the controller class alongside the existing `logo` action:

```ruby
# POST /api/v1/accounts/:id/scrape
def scrape
  unless SCRAPER_SERVICE_URL
    render json: { error: 'Scraper service is not configured.' }, status: :service_unavailable
    return
  end

  unless @account.website_url.present?
    render json: { error: 'No website URL saved for this account.' }, status: :unprocessable_entity
    return
  end

  api_token = current_user.access_token.token

  payload = {
    account_id:      @account.id,
    website_url:     @account.website_url,
    rails_api_url:   root_url.chomp('/'),
    rails_api_token: api_token
  }.to_json

  uri  = URI("#{SCRAPER_SERVICE_URL}/scrape")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
  request.body = payload

  begin
    response = http.request(request)
    render json: JSON.parse(response.body), status: response.code.to_i
  rescue StandardError => e
    render json: { error: "Could not reach scraper service: #{e.message}" }, status: :bad_gateway
  end
end

# GET /api/v1/accounts/:id/scrape_status
def scrape_status
  unless SCRAPER_SERVICE_URL
    render json: { error: 'Scraper service is not configured.' }, status: :service_unavailable
    return
  end

  uri  = URI("#{SCRAPER_SERVICE_URL}/scrape/#{@account.id}/status")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'

  begin
    response = http.get(uri.path)
    render json: JSON.parse(response.body), status: response.code.to_i
  rescue StandardError => e
    render json: { error: "Could not reach scraper service: #{e.message}" }, status: :bad_gateway
  end
end
```

**What each action does:**

- `scrape` — validates that a `website_url` is saved, then forwards a job request to the FastAPI microservice. Passes the current user's `api_access_token` so the worker can POST entries back into Rails. Returns `202` immediately.
- `scrape_status` — proxies a status poll to the microservice and returns the current job state (`idle`, `pending`, `running`, `done`, or `failed`) with a live progress message.

---

## Frontend Changes

### `app/javascript/dashboard/api/account.js`

Add two methods inside the `AccountAPI` class alongside `updateLogo()` and `deleteLogo()`:

```js
triggerScrape(accountId) {
  return axios.post(`${this.apiVersion}/accounts/${accountId}/scrape`);
},

scrapeStatus(accountId) {
  return axios.get(`${this.apiVersion}/accounts/${accountId}/scrape_status`);
},
```

---

### `app/javascript/dashboard/store/modules/accounts.js`

**State — move `scrapeJob` to top level (NOT inside `uiFlags`):**

```js
const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isUpdating: false,
    isUpdatingLogo: false,
    isCheckoutInProcess: false,
    isFetchingLimits: false,
    isScraping: false,       // ← controls the trigger button spinner
  },
  scrapeJob: {               // ← top level, NOT inside uiFlags
    status: 'idle',
    message: '',
  },
};
```

> **Critical:** `scrapeJob` must be at the top level of `state`. Placing it inside `uiFlags` causes `$state.scrapeJob` in the getter and mutation to return `undefined`, breaking the entire Vue app.

**Getter:**

```js
getScrapeJob: $state => $state.scrapeJob,
```

**Actions:**

```js
triggerScrape: async ({ commit, dispatch }, { accountId }) => {
  commit(types.default.SET_ACCOUNT_UI_FLAG, { isScraping: true });
  try {
    await AccountAPI.triggerScrape(accountId);
    dispatch('pollScrapeStatus', { accountId });
  } finally {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isScraping: false });
  }
},

pollScrapeStatus: async ({ commit, dispatch }, { accountId }) => {
  const INTERVAL_MS = 3000;

  const poll = async () => {
    try {
      const response = await AccountAPI.scrapeStatus(accountId);
      const { status, message } = response.data;
      commit(types.default.SET_SCRAPE_JOB, { status, message });

      if (status === 'done') {
        dispatch('knowledgeBaseEntries/fetchEntries', null, { root: true });
        return;
      }
      if (status === 'failed') return;

      setTimeout(poll, INTERVAL_MS);
    } catch {
      commit(types.default.SET_SCRAPE_JOB, {
        status: 'failed',
        message: 'Lost connection to scraper service.',
      });
    }
  };

  poll();
},
```

**Mutation:**

```js
[types.default.SET_SCRAPE_JOB]($state, data) {
  $state.scrapeJob = { ...$state.scrapeJob, ...data };
},
```

---

### `app/javascript/dashboard/store/mutation-types.js`

In the `// Agent` section, add one constant after `DELETE_ACCOUNT`:

```js
// Agent
SET_ACCOUNT_UI_FLAG: 'SET_ACCOUNT_UI_FLAG',
SET_ACCOUNT_LIMITS: 'SET_ACCOUNT_LIMITS',
SET_ACCOUNTS: 'SET_ACCOUNTS',
ADD_ACCOUNT: 'ADD_ACCOUNT',
EDIT_ACCOUNT: 'EDIT_ACCOUNT',
DELETE_ACCOUNT: 'DELETE_AGENT',
SET_SCRAPE_JOB: 'SET_SCRAPE_JOB',   // ← NEW
```

---

### `app/javascript/dashboard/i18n/locale/en/generalSettings.json`

Inside `KNOWLEDGE_BASE.WEBSITE_URL`, add:

```json
"SCRAPE_BUTTON": "Scrape Data",
"SCRAPE_BUTTON_LOADING": "Scraping…",
"SCRAPE_STATUS": {
  "PENDING":       "Scrape job accepted — starting up…",
  "RUNNING":       "Scraping in progress…",
  "DONE":          "Scraping complete! New entries have been added below.",
  "FAILED":        "Scraping failed",
  "TRIGGER_ERROR": "Could not start scrape job, try again!"
}
```

---

### `app/javascript/dashboard/routes/dashboard/settings/knowledgeBase/Index.vue`

Key additions to the existing page (full file replacement provided separately):

**New computed properties:**

```js
scrapeJob:      'accounts/getScrapeJob',   // from Vuex

hasSavedWebsiteUrl() {
  return !!this.currentAccount.website_url;
},
isScraping() {
  return ['pending', 'running'].includes(this.scrapeJob?.status);
},
scrapeStatusType() {
  // returns 'info' | 'success' | 'error' for banner colour
},
scrapeStatusText() {
  // returns human-readable string from i18n or live worker message
},
```

**New method:**

```js
async triggerScrape() {
  try {
    await this.$store.dispatch('accounts/triggerScrape', {
      accountId: this.accountId,
    });
  } catch {
    useAlert(this.$t('KNOWLEDGE_BASE.WEBSITE_URL.SCRAPE_STATUS.TRIGGER_ERROR'));
  }
},
```

**Resume polling on mount** (handles page navigation mid-scrape):

```js
const existingStatus = this.scrapeJob?.status;
if (['pending', 'running'].includes(existingStatus)) {
  this.$store.dispatch('accounts/pollScrapeStatus', { accountId: this.accountId });
}
```

**Template additions** — inside the Website URL `SectionLayout`:

1. **Scrape Data button** — appears only when `hasSavedWebsiteUrl` is true, disabled and shows loading text while `isScraping`
2. **Live status banner** — blue while pending/running (with spinner), green on done, red on failed

---

## API Reference

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/accounts/:id/scrape` | none | Triggers background scrape job |
| `GET` | `/api/v1/accounts/:id/scrape_status` | none | Returns current job status and message |

**Auth:** Both endpoints require `api_access_token` header.
**Permission:** Administrator only (inherits from `AccountsController`).

**Status values returned by `/scrape_status`:**

| Status | Meaning |
|--------|---------|
| `idle` | No job triggered yet for this account |
| `pending` | Job accepted by microservice, not started yet |
| `running` | Actively scraping — `message` shows current step |
| `done` | Completed — entries have been saved to the database |
| `failed` | Something went wrong — `message` contains the error |

---

## Environment Configuration

| Variable | Required | Example | Description |
|----------|----------|---------|-------------|
| `SCRAPER_SERVICE_URL` | Yes | `http://localhost:8088` | Base URL of the FastAPI scraper microservice |

Set this in your `.env` file or deployment environment. Without it, both scrape endpoints return `503`.

---

## User Flow

1. Admin saves a website URL on the Knowledge Base settings page
2. **"Scrape Data"** button appears below the Save button
3. Admin clicks **"Scrape Data"**
4. Blue status banner appears: *"Scrape job accepted — starting up…"*
5. Banner updates every 3 seconds with live worker messages (e.g. *"Extracting page 2/5: https://example.com/privacy"*)
6. On completion, banner turns green: *"Scraping complete! New entries have been added below."*
7. Knowledge Base entries list refreshes automatically — new entries appear without a page reload
8. On failure, banner turns red with the error message from the worker

---

## Bug Fixed During Implementation

**Symptom:** Entire Vue app stuck on loading after adding the scrape feature.

**Root cause:** `scrapeJob` was placed inside `uiFlags` in the Vuex state, but the getter (`$state.scrapeJob`) and the `SET_SCRAPE_JOB` mutation (`$state.scrapeJob = ...`) both referenced it at the top level of `$state`. This caused `scrapeJob` to be `undefined` on read, crashing the Vue reactivity system at startup.

**Fix:** Move `scrapeJob` out of `uiFlags` to the top level of `state` so the getter and mutation can reach it correctly.

---

## Future Change Guide

| To change… | Edit this file |
|---|---|
| Scraper service URL | `.env` → `SCRAPER_SERVICE_URL` |
| Rails → scraper connection logic | `app/controllers/api/v1/accounts_controller.rb` → `scrape` / `scrape_status` |
| Add new scrape routes | `config/routes.rb` + `accounts_controller.rb` |
| Frontend API calls | `app/javascript/dashboard/api/account.js` |
| Polling interval (currently 3s) | `app/javascript/dashboard/store/modules/accounts.js` → `INTERVAL_MS` |
| Scrape job Vuex state / actions | `app/javascript/dashboard/store/modules/accounts.js` |
| Mutation type constants | `app/javascript/dashboard/store/mutation-types.js` |
| Scrape button and status banner UI | `…/settings/knowledgeBase/Index.vue` |
| UI text for scrape section | `app/javascript/dashboard/i18n/locale/en/generalSettings.json` → `KNOWLEDGE_BASE.WEBSITE_URL.SCRAPE_STATUS` |
