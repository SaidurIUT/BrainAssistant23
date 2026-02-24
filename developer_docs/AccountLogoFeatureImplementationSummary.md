# Account Logo Feature — Implementation Summary

**Branch:** `development/white_label` | **Commit:** `e93188b`

---

## Overview

Added account logo upload/delete functionality to BrainAssistant23 (Chatwoot-based). Admins can upload and remove a logo for their account from the Account Settings page. Built to mirror the existing **User Avatar** pattern exactly. No database migration required — Active Storage handles attachments via its own existing tables.

---

## Files Changed

| File Path | Action | What Changed |
|-----------|--------|--------------|
| `app/models/account.rb` | MODIFIED | Added `has_one_attached :logo`, `logo_url` method, `acceptable_logo` validation, included URL helpers |
| `app/controllers/api/v1/accounts_controller.rb` | MODIFIED | Added `logo` delete action, permitted `:logo` in params, passed `:logo` in `update` |
| `config/routes.rb` | MODIFIED | Added `delete :logo` member route inside accounts resource |
| `app/views/api/v1/models/_account.json.jbuilder` | MODIFIED | Added `json.logo_url resource.logo_url` to API response |
| `app/javascript/dashboard/api/account.js` | MODIFIED | Added `updateLogo()` and `deleteLogo()` API methods |
| `app/javascript/dashboard/store/modules/accounts.js` | MODIFIED | Added `updateLogo`, `deleteLogo` actions and `isUpdatingLogo` UI flag |
| `app/javascript/dashboard/routes/dashboard/settings/account/components/AccountLogo.vue` | **NEW** | Logo upload/delete Vue component |
| `app/javascript/dashboard/routes/dashboard/settings/account/Index.vue` | MODIFIED | Imported and rendered `AccountLogo` in settings page |
| `app/javascript/dashboard/i18n/locale/en/generalSettings.json` | MODIFIED | Added `GENERAL_SETTINGS.ACCOUNT_LOGO` translation keys |

---

## Backend Changes

### `app/models/account.rb`

```ruby
include Rails.application.routes.url_helpers   # added — needed for url_for in logo_url

has_one_attached :contacts_export              # existing
has_one_attached :logo                         # NEW

validate :acceptable_logo, if: -> { logo.changed? }  # NEW

def logo_url
  return url_for(logo.representation(resize_to_fill: [250, nil])) if logo.attached? && logo.representable?
  ''
end

# inside private:
def acceptable_logo
  return unless logo.attached?
  errors.add(:logo, 'is too big') if logo.byte_size > 15.megabytes
  acceptable_types = ['image/jpeg', 'image/png', 'image/gif'].freeze
  errors.add(:logo, 'filetype not supported') unless acceptable_types.include?(logo.content_type)
end
```

### `app/controllers/api/v1/accounts_controller.rb`

```ruby
# New action — handles DELETE /api/v1/accounts/:id/logo
def logo
  @account.logo.attachment.destroy! if @account.logo.attached?
  @account.reload
  render 'api/v1/accounts/show', format: :json
end

# Updated — :logo added to slice
def update
  @account.assign_attributes(account_params.slice(:name, :locale, :domain, :support_email, :logo))
  # ...
end

# Updated — :logo permitted
def account_params
  params.permit(:account_name, :email, :name, :password, :locale, :domain, :support_email, :user_full_name, :logo)
end
```

### `config/routes.rb`

```ruby
resources :accounts, only: [:create, :show, :update] do
  member do
    post :update_active_at
    get  :cache_keys
    delete :logo    # NEW
  end
end
```

### `app/views/api/v1/models/_account.json.jbuilder`

```ruby
json.logo_url resource.logo_url    # NEW — added near other top-level fields
json.domain @account.domain
# ...
```

---

## Frontend Changes

### `app/javascript/dashboard/api/account.js`

```js
updateLogo(accountId, logoFile) {
  const formData = new FormData();
  formData.append('logo', logoFile);
  return axios.patch(`${this.apiVersion}/accounts/${accountId}`, formData);
},

deleteLogo(accountId) {
  return axios.delete(`${this.apiVersion}/accounts/${accountId}/logo`);
}
```

### `app/javascript/dashboard/store/modules/accounts.js`

```js
// New UI flag in state
uiFlags: {
  isUpdatingLogo: false,   // NEW
  // ... existing flags
}

// New actions
updateLogo: async ({ commit }, { accountId, logoFile }) => {
  commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdatingLogo: true });
  try {
    const response = await AccountAPI.updateLogo(accountId, logoFile);
    commit(types.default.EDIT_ACCOUNT, response.data);
  } finally {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdatingLogo: false });
  }
},

deleteLogo: async ({ commit }, { accountId }) => {
  commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdatingLogo: true });
  try {
    const response = await AccountAPI.deleteLogo(accountId);
    commit(types.default.EDIT_ACCOUNT, response.data);
  } finally {
    commit(types.default.SET_ACCOUNT_UI_FLAG, { isUpdatingLogo: false });
  }
},
```

### `app/javascript/dashboard/routes/dashboard/settings/account/components/AccountLogo.vue` *(NEW)*

New Vue 3 component (Composition API). Mirrors `UserProfilePicture.vue` from profile settings. Uses the shared `Avatar` component with `allow-upload` prop.

```vue
<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const store = useStore();
const { t } = useI18n();
const { accountId } = useAccount();
const logoFile = ref(null);
const logoUrl = ref('');
const account = computed(() => store.getters['accounts/getAccount'](accountId.value));
const uiFlags = computed(() => store.getters['accounts/getUIFlags']);
logoUrl.value = account.value?.logo_url || '';

const updateLogo = async ({ file, url }) => {
  logoFile.value = file;
  logoUrl.value = url;
  try {
    await store.dispatch('accounts/updateLogo', { accountId: accountId.value, logoFile: file });
    useAlert(t('GENERAL_SETTINGS.ACCOUNT_LOGO.UPDATE_SUCCESS'));
  } catch { useAlert(t('GENERAL_SETTINGS.ACCOUNT_LOGO.UPDATE_ERROR')); }
};

const deleteLogo = async () => {
  try {
    await store.dispatch('accounts/deleteLogo', { accountId: accountId.value });
    logoUrl.value = '';
    useAlert(t('GENERAL_SETTINGS.ACCOUNT_LOGO.DELETE_SUCCESS'));
  } catch { useAlert(t('GENERAL_SETTINGS.ACCOUNT_LOGO.DELETE_ERROR')); }
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <span class="text-sm font-medium text-n-slate-12">
      {{ $t('GENERAL_SETTINGS.ACCOUNT_LOGO.LABEL') }}
    </span>
    <Avatar
      :src="logoUrl || account.logo_url || ''"
      :name="account.name || ''"
      :size="72"
      allow-upload
      rounded-full
      @upload="updateLogo"
      @delete="deleteLogo"
    />
    <p v-if="uiFlags.isUpdatingLogo" class="text-xs text-n-slate-11">
      {{ $t('GENERAL_SETTINGS.ACCOUNT_LOGO.UPDATING') }}
    </p>
  </div>
</template>
```

### `app/javascript/dashboard/routes/dashboard/settings/account/Index.vue`

```js
import AccountLogo from './components/AccountLogo.vue';  // added
// registered in components: { ..., AccountLogo }
```

```html
<!-- Added inside SectionLayout, above the form -->
<AccountLogo />
```

### `app/javascript/dashboard/i18n/locale/en/generalSettings.json`

```json
"ACCOUNT_LOGO": {
  "LABEL": "Account Logo",
  "UPDATING": "Updating...",
  "UPDATE_SUCCESS": "Account logo updated successfully",
  "UPDATE_ERROR": "Could not update account logo, try again!",
  "DELETE_SUCCESS": "Account logo deleted successfully",
  "DELETE_ERROR": "Could not delete account logo, try again!"
}
```

---

## API Reference

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| `PATCH` | `/api/v1/accounts/:id` | `form-data: logo=<file>` | Upload logo |
| `DELETE` | `/api/v1/accounts/:id/logo` | none | Delete logo |
| `GET` | `/api/v1/accounts/:id` | none | Returns `logo_url` in response |

**Auth:** All requests require `api_access_token` header.

**Constraints:** Max 15MB · Types: jpeg, png, gif only · One logo per account (new upload replaces old).

---

## Design Pattern — Mirrors User Avatar

| User Avatar | Account Logo |
|-------------|--------------|
| `Avatarable` concern → `has_one_attached :avatar` | `has_one_attached :logo` in `account.rb` |
| `User#avatar_url` | `Account#logo_url` |
| `ProfilesController#avatar` (DELETE) | `AccountsController#logo` (DELETE) |
| `authAPI.deleteAvatar()` | `AccountAPI.deleteLogo(accountId)` |
| `auth` store `deleteAvatar` action | `accounts` store `deleteLogo` action |
| `UserProfilePicture.vue` | `AccountLogo.vue` |

---

## Future Change Guide

| To change... | Edit this file |
|---|---|
| Logo validation rules (size, type) | `app/models/account.rb` → `acceptable_logo` |
| Logo URL format or resize dimensions | `app/models/account.rb` → `logo_url` |
| Add new logo API endpoint | `config/routes.rb` + `accounts_controller.rb` |
| Change API response fields | `app/views/api/v1/models/_account.json.jbuilder` |
| New frontend API call | `app/javascript/dashboard/api/account.js` |
| New Vuex action or state | `app/javascript/dashboard/store/modules/accounts.js` |
| UI changes to logo section | `…/account/components/AccountLogo.vue` |
| New strings in the logo UI | `AccountLogo.vue` + `generalSettings.json` under `ACCOUNT_LOGO` |

> **ESLint rule:** All visible strings in `.vue` templates must use `$t()`. Raw strings will fail the pre-commit hook.
