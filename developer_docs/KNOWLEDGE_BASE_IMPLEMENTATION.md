# Knowledge Base Feature — Complete Implementation

**Branch:** `development/white_label`

---

## Overview

Added a Knowledge Base settings page to BrainAssistant23. Admins can:
- Save a website URL for their account (to be scraped later)
- View scraped content (read-only field)
- Add, edit, and delete custom knowledge entries (level + description)

---

## Files Changed Summary

| File Path | Action |
|-----------|--------|
| `db/migrate/TIMESTAMP_add_knowledge_base_to_accounts.rb` | NEW |
| `db/migrate/TIMESTAMP_create_knowledge_base_entries.rb` | NEW |
| `app/models/knowledge_base_entry.rb` | NEW |
| `app/models/account.rb` | MODIFIED — 1 line added |
| `app/policies/knowledge_base_entry_policy.rb` | NEW |
| `app/controllers/api/v1/accounts/knowledge_base_entries_controller.rb` | NEW |
| `app/controllers/api/v1/accounts_controller.rb` | MODIFIED — 2 lines changed |
| `app/views/api/v1/models/_account.json.jbuilder` | MODIFIED — 2 lines added |
| `config/routes.rb` | MODIFIED — 1 line added |
| `app/javascript/dashboard/api/knowledgeBaseEntries.js` | NEW |
| `app/javascript/dashboard/store/modules/knowledgeBaseEntries.js` | NEW |
| `app/javascript/dashboard/store/index.js` | MODIFIED — 2 lines added |
| `app/javascript/dashboard/routes/dashboard/settings/knowledgeBase/knowledgeBase.routes.js` | NEW |
| `app/javascript/dashboard/routes/dashboard/settings/knowledgeBase/Index.vue` | NEW |
| `app/javascript/dashboard/routes/dashboard/settings/knowledgeBase/components/KnowledgeBaseEntryForm.vue` | NEW |
| `app/javascript/dashboard/routes/dashboard/settings/settings.routes.js` | MODIFIED — 2 lines added |
| `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` | MODIFIED — 6 lines added |
| `app/javascript/dashboard/i18n/locale/en/generalSettings.json` | MODIFIED — keys added |
| `app/javascript/dashboard/i18n/locale/en/sidebar.json` | MODIFIED — 1 key added |

---

## 1. Migrations

### `db/migrate/TIMESTAMP_add_knowledge_base_to_accounts.rb` — NEW

```ruby
class AddKnowledgeBaseToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :website_url, :string
    add_column :accounts, :scraped_data, :text
  end
end
```

### `db/migrate/TIMESTAMP_create_knowledge_base_entries.rb` — NEW

```ruby
class CreateKnowledgeBaseEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :knowledge_base_entries do |t|
      t.references :account, null: false, foreign_key: true
      t.string :level, null: false
      t.text :description, null: false
      t.timestamps
    end
  end
end
```

---

## 2. Backend — Ruby Files

### `app/models/knowledge_base_entry.rb` — NEW (full file)

```ruby
class KnowledgeBaseEntry < ApplicationRecord
  belongs_to :account

  validates :level, presence: true
  validates :description, presence: true
end
```

### `app/models/account.rb` — MODIFIED

Find:
```ruby
has_many :working_hours, dependent: :destroy_async
```

Add after it:
```ruby
has_many :knowledge_base_entries, dependent: :destroy_async
```

### `app/policies/knowledge_base_entry_policy.rb` — NEW (full file)

```ruby
class KnowledgeBaseEntryPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end
end
```

### `app/controllers/api/v1/accounts/knowledge_base_entries_controller.rb` — NEW (full file)

```ruby
class Api::V1::Accounts::KnowledgeBaseEntriesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action :fetch_entry, except: [:index, :create]
  before_action :check_authorization

  def index
    @entries = Current.account.knowledge_base_entries.order(created_at: :asc)
    render json: @entries
  end

  def show
    render json: @entry
  end

  def create
    @entry = Current.account.knowledge_base_entries.create!(permitted_params)
    render json: @entry, status: :created
  end

  def update
    @entry.update!(permitted_params)
    render json: @entry
  end

  def destroy
    @entry.destroy!
    head :ok
  end

  private

  def fetch_entry
    @entry = Current.account.knowledge_base_entries.find(params[:id])
  end

  def permitted_params
    params.require(:knowledge_base_entry).permit(:level, :description)
  end
end
```

### `app/controllers/api/v1/accounts_controller.rb` — MODIFIED

Find:
```ruby
@account.assign_attributes(account_params.slice(:name, :locale, :domain, :support_email, :logo))
```

Replace with:
```ruby
@account.assign_attributes(account_params.slice(:name, :locale, :domain, :support_email, :logo, :website_url, :scraped_data))
```

Find:
```ruby
def account_params
  params.permit(:account_name, :email, :name, :password, :locale, :domain, :support_email, :user_full_name, :logo)
end
```

Replace with:
```ruby
def account_params
  params.permit(:account_name, :email, :name, :password, :locale, :domain, :support_email, :user_full_name, :logo, :website_url, :scraped_data)
end
```

### `app/views/api/v1/models/_account.json.jbuilder` — MODIFIED

Find:
```ruby
json.logo_url resource.logo_url
```

Add after it:
```ruby
json.website_url resource.website_url
json.scraped_data resource.scraped_data
```

### `config/routes.rb` — MODIFIED

Find:
```ruby
resources :labels, only: [:index, :show, :create, :update, :destroy]
```

Add after it:
```ruby
resources :knowledge_base_entries, only: [:index, :show, :create, :update, :destroy]
```

---

## 3. Frontend — JavaScript Files

### `app/javascript/dashboard/api/knowledgeBaseEntries.js` — NEW (full file)

```js
/* global axios */

import ApiClient from './ApiClient';

class KnowledgeBaseEntriesAPI extends ApiClient {
  constructor() {
    super('knowledge_base_entries', { accountScoped: true });
  }

  getEntries() {
    return axios.get(this.url);
  }

  createEntry(data) {
    return axios.post(this.url, { knowledge_base_entry: data });
  }

  updateEntry(id, data) {
    return axios.patch(`${this.url}/${id}`, { knowledge_base_entry: data });
  }

  deleteEntry(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new KnowledgeBaseEntriesAPI();
```

### `app/javascript/dashboard/store/modules/knowledgeBaseEntries.js` — NEW (full file)

```js
import KnowledgeBaseEntriesAPI from '../../api/knowledgeBaseEntries';

export const state = {
  entries: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getEntries(_state) {
    return _state.entries;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  fetchEntries: async function fetchEntries({ commit }) {
    commit('SET_KB_UI_FLAG', { isFetching: true });
    try {
      const response = await KnowledgeBaseEntriesAPI.getEntries();
      commit('SET_ENTRIES', response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit('SET_KB_UI_FLAG', { isFetching: false });
    }
  },

  createEntry: async function createEntry({ commit }, data) {
    commit('SET_KB_UI_FLAG', { isCreating: true });
    try {
      const response = await KnowledgeBaseEntriesAPI.createEntry(data);
      commit('ADD_ENTRY', response.data);
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit('SET_KB_UI_FLAG', { isCreating: false });
    }
  },

  updateEntry: async function updateEntry({ commit }, { id, ...updateObj }) {
    commit('SET_KB_UI_FLAG', { isUpdating: true });
    try {
      const response = await KnowledgeBaseEntriesAPI.updateEntry(id, updateObj);
      commit('EDIT_ENTRY', response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit('SET_KB_UI_FLAG', { isUpdating: false });
    }
  },

  deleteEntry: async function deleteEntry({ commit }, id) {
    commit('SET_KB_UI_FLAG', { isDeleting: true });
    try {
      await KnowledgeBaseEntriesAPI.deleteEntry(id);
      commit('DELETE_ENTRY', id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit('SET_KB_UI_FLAG', { isDeleting: false });
    }
  },
};

export const mutations = {
  SET_KB_UI_FLAG(_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  SET_ENTRIES(_state, data) {
    _state.entries = data;
  },

  ADD_ENTRY(_state, data) {
    _state.entries = [..._state.entries, data];
  },

  EDIT_ENTRY(_state, data) {
    const index = _state.entries.findIndex(e => e.id === data.id);
    if (index !== -1) {
      _state.entries = [
        ..._state.entries.slice(0, index),
        data,
        ..._state.entries.slice(index + 1),
      ];
    }
  },

  DELETE_ENTRY(_state, id) {
    _state.entries = _state.entries.filter(e => e.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
```

### `app/javascript/dashboard/store/index.js` — MODIFIED

Add import at the top with other imports:
```js
import knowledgeBaseEntriesModule from './modules/knowledgeBaseEntries';
```

Add to the `modules` object after `captainCustomTools`:
```js
knowledgeBaseEntries: knowledgeBaseEntriesModule,
```

### `app/javascript/dashboard/routes/dashboard/settings/knowledgeBase/knowledgeBase.routes.js` — NEW (full file)

```js
import { frontendURL } from '../../../../helper/URLHelper';
import Index from './Index.vue';
import SettingsWrapper from '../SettingsWrapper.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/knowledge-base'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'knowledge_base_index',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
```

### `app/javascript/dashboard/routes/dashboard/settings/settings.routes.js` — MODIFIED

Add import at the top with other imports:
```js
import knowledgeBase from './knowledgeBase/knowledgeBase.routes';
```

Add to the routes array after `...captain.routes`:
```js
...knowledgeBase.routes,
```

### `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` — MODIFIED

Find:
```js
{
  name: 'Settings Account Settings',
  label: t('SIDEBAR.ACCOUNT_SETTINGS'),
  icon: 'i-lucide-briefcase',
  to: accountScopedRoute('general_settings_index'),
},
```

Add after it:
```js
{
  name: 'Settings Knowledge Base',
  label: t('SIDEBAR.KNOWLEDGE_BASE'),
  icon: 'i-lucide-database',
  to: accountScopedRoute('knowledge_base_index'),
},
```

### `app/javascript/dashboard/i18n/locale/en/sidebar.json` — MODIFIED

Find:
```json
"ACCOUNT_SETTINGS": "Account Settings",
```

Add after it:
```json
"KNOWLEDGE_BASE": "Knowledge Base",
```

### `app/javascript/dashboard/i18n/locale/en/generalSettings.json` — MODIFIED

Add this entire block at the top level of the JSON alongside `"GENERAL_SETTINGS"`:

```json
"KNOWLEDGE_BASE": {
  "TITLE": "Knowledge Base",
  "WEBSITE_URL": {
    "SECTION_TITLE": "Website",
    "SECTION_NOTE": "Add your website URL to scrape content for your knowledge base.",
    "LABEL": "Website URL",
    "PLACEHOLDER": "https://yourwebsite.com",
    "SAVE": "Save",
    "SAVE_SUCCESS": "Website URL saved successfully",
    "SAVE_ERROR": "Could not save website URL, try again!"
  },
  "SCRAPED_DATA": {
    "SECTION_TITLE": "Scraped Content",
    "SECTION_NOTE": "Content scraped from your website will appear here.",
    "EMPTY": "No scraped content yet. Save a website URL to get started.",
    "HELPER": "This content is read-only and is populated automatically after scraping."
  },
  "ENTRIES": {
    "SECTION_TITLE": "Additional Data",
    "SECTION_NOTE": "Add custom knowledge entries with a level and description. You can add as many entries as you need.",
    "EMPTY": "No entries yet. Click the button below to add your first entry.",
    "ADD_BUTTON": "Add Entry"
  },
  "ENTRY": {
    "LEVEL": {
      "LABEL": "Level",
      "PLACEHOLDER": "e.g. Beginner, Advanced, FAQ, Policy..."
    },
    "DESCRIPTION": {
      "LABEL": "Description",
      "PLACEHOLDER": "Enter the knowledge content for this entry..."
    },
    "ADD": "Add Entry",
    "UPDATE": "Update Entry",
    "EDIT": "Edit",
    "DELETE": "Delete",
    "CANCEL": "Cancel",
    "CREATE_SUCCESS": "Entry added successfully",
    "CREATE_ERROR": "Could not add entry, try again!",
    "UPDATE_SUCCESS": "Entry updated successfully",
    "UPDATE_ERROR": "Could not update entry, try again!",
    "DELETE_SUCCESS": "Entry deleted successfully",
    "DELETE_ERROR": "Could not delete entry, try again!"
  }
}
```

---

## 4. Vue Components

### `app/javascript/dashboard/routes/dashboard/settings/knowledgeBase/components/KnowledgeBaseEntryForm.vue` — NEW (full file)

```vue
<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'next/input/Input.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';

const props = defineProps({
  entry: {
    type: Object,
    default: null,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const level = ref('');
const description = ref('');

watch(
  () => props.entry,
  val => {
    if (val) {
      level.value = val.level || '';
      description.value = val.description || '';
    } else {
      level.value = '';
      description.value = '';
    }
  },
  { immediate: true }
);

const handleSubmit = () => {
  if (!level.value.trim() || !description.value.trim()) return;
  emit('submit', { level: level.value.trim(), description: description.value.trim() });
};

const handleCancel = () => {
  level.value = '';
  description.value = '';
  emit('cancel');
};
</script>

<template>
  <div class="flex flex-col gap-3 p-4 border border-n-slate-5 rounded-lg bg-n-slate-1">
    <WithLabel :label="$t('KNOWLEDGE_BASE.ENTRY.LEVEL.LABEL')">
      <NextInput
        v-model="level"
        type="text"
        class="w-full"
        :placeholder="$t('KNOWLEDGE_BASE.ENTRY.LEVEL.PLACEHOLDER')"
      />
    </WithLabel>
    <WithLabel :label="$t('KNOWLEDGE_BASE.ENTRY.DESCRIPTION.LABEL')">
      <textarea
        v-model="description"
        class="w-full min-h-[100px] text-sm border border-n-slate-5 rounded-lg p-2 resize-y
               bg-white dark:bg-n-slate-2 text-n-slate-12 placeholder:text-n-slate-9
               focus:outline-none focus:ring-1 focus:ring-woot-500"
        :placeholder="$t('KNOWLEDGE_BASE.ENTRY.DESCRIPTION.PLACEHOLDER')"
      />
    </WithLabel>
    <div class="flex gap-2 justify-end">
      <NextButton ghost @click="handleCancel">
        {{ $t('KNOWLEDGE_BASE.ENTRY.CANCEL') }}
      </NextButton>
      <NextButton
        blue
        :is-loading="isLoading"
        :disabled="!level.trim() || !description.trim()"
        @click="handleSubmit"
      >
        {{ entry ? $t('KNOWLEDGE_BASE.ENTRY.UPDATE') : $t('KNOWLEDGE_BASE.ENTRY.ADD') }}
      </NextButton>
    </div>
  </div>
</template>
```

### `app/javascript/dashboard/routes/dashboard/settings/knowledgeBase/Index.vue` — NEW (full file)

```vue
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import NextInput from 'next/input/Input.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import KnowledgeBaseEntryForm from './components/KnowledgeBaseEntryForm.vue';

export default {
  components: {
    BaseSettingsHeader,
    SectionLayout,
    NextButton,
    NextInput,
    WithLabel,
    KnowledgeBaseEntryForm,
  },

  setup() {
    const { accountId } = useAccount();
    return { accountId };
  },

  data() {
    return {
      websiteUrl: '',
      scrapedData: '',
      showAddForm: false,
      editingEntry: null,
    };
  },

  computed: {
    ...mapGetters({
      getAccount: 'accounts/getAccount',
      accountUIFlags: 'accounts/getUIFlags',
    }),
    entries() {
      return this.$store.getters['knowledgeBaseEntries/getEntries'];
    },
    kbUIFlags() {
      return this.$store.getters['knowledgeBaseEntries/getUIFlags'];
    },
    currentAccount() {
      return this.getAccount(this.accountId) || {};
    },
  },

  mounted() {
    this.initializePage();
  },

  methods: {
    async initializePage() {
      try {
        const account = this.getAccount(this.accountId);
        this.websiteUrl = account?.website_url || '';
        this.scrapedData = account?.scraped_data || '';
        await this.$store.dispatch('knowledgeBaseEntries/fetchEntries');
      } catch (error) {
        // Ignore
      }
    },

    async saveWebsiteUrl() {
      try {
        await this.$store.dispatch('accounts/update', {
          website_url: this.websiteUrl,
        });
        useAlert(this.$t('KNOWLEDGE_BASE.WEBSITE_URL.SAVE_SUCCESS'));
      } catch {
        useAlert(this.$t('KNOWLEDGE_BASE.WEBSITE_URL.SAVE_ERROR'));
      }
    },

    async handleAddEntry(data) {
      try {
        await this.$store.dispatch('knowledgeBaseEntries/createEntry', data);
        useAlert(this.$t('KNOWLEDGE_BASE.ENTRY.CREATE_SUCCESS'));
        this.showAddForm = false;
      } catch {
        useAlert(this.$t('KNOWLEDGE_BASE.ENTRY.CREATE_ERROR'));
      }
    },

    async handleUpdateEntry(data) {
      try {
        await this.$store.dispatch('knowledgeBaseEntries/updateEntry', {
          id: this.editingEntry.id,
          ...data,
        });
        useAlert(this.$t('KNOWLEDGE_BASE.ENTRY.UPDATE_SUCCESS'));
        this.editingEntry = null;
      } catch {
        useAlert(this.$t('KNOWLEDGE_BASE.ENTRY.UPDATE_ERROR'));
      }
    },

    async handleDeleteEntry(id) {
      try {
        await this.$store.dispatch('knowledgeBaseEntries/deleteEntry', id);
        useAlert(this.$t('KNOWLEDGE_BASE.ENTRY.DELETE_SUCCESS'));
      } catch {
        useAlert(this.$t('KNOWLEDGE_BASE.ENTRY.DELETE_ERROR'));
      }
    },

    startEdit(entry) {
      this.editingEntry = entry;
      this.showAddForm = false;
    },

    cancelEdit() {
      this.editingEntry = null;
    },

    cancelAdd() {
      this.showAddForm = false;
    },
  },
};
</script>

<template>
  <div class="flex flex-col max-w-2xl mx-auto w-full">
    <BaseSettingsHeader :title="$t('KNOWLEDGE_BASE.TITLE')" />

    <div class="flex-grow flex-shrink min-w-0 mt-3 flex flex-col gap-4">

      <!-- Website URL Section -->
      <SectionLayout
        :title="$t('KNOWLEDGE_BASE.WEBSITE_URL.SECTION_TITLE')"
        :description="$t('KNOWLEDGE_BASE.WEBSITE_URL.SECTION_NOTE')"
      >
        <div class="grid gap-4">
          <WithLabel :label="$t('KNOWLEDGE_BASE.WEBSITE_URL.LABEL')">
            <div class="flex gap-2">
              <NextInput
                v-model="websiteUrl"
                type="url"
                class="w-full"
                :placeholder="$t('KNOWLEDGE_BASE.WEBSITE_URL.PLACEHOLDER')"
              />
              <NextButton
                blue
                :is-loading="accountUIFlags.isUpdating"
                @click="saveWebsiteUrl"
              >
                {{ $t('KNOWLEDGE_BASE.WEBSITE_URL.SAVE') }}
              </NextButton>
            </div>
          </WithLabel>
        </div>
      </SectionLayout>

      <!-- Scraped Data Section -->
      <SectionLayout
        :title="$t('KNOWLEDGE_BASE.SCRAPED_DATA.SECTION_TITLE')"
        :description="$t('KNOWLEDGE_BASE.SCRAPED_DATA.SECTION_NOTE')"
      >
        <div class="grid gap-2">
          <textarea
            v-model="scrapedData"
            readonly
            class="w-full min-h-[200px] text-sm border border-n-slate-5 rounded-lg p-3 resize-y
                   bg-n-slate-2 dark:bg-n-slate-3 text-n-slate-12 placeholder:text-n-slate-9
                   focus:outline-none cursor-default"
            :placeholder="$t('KNOWLEDGE_BASE.SCRAPED_DATA.EMPTY')"
          />
          <p class="text-xs text-n-slate-10">
            {{ $t('KNOWLEDGE_BASE.SCRAPED_DATA.HELPER') }}
          </p>
        </div>
      </SectionLayout>

      <!-- Additional Data Entries Section -->
      <SectionLayout
        :title="$t('KNOWLEDGE_BASE.ENTRIES.SECTION_TITLE')"
        :description="$t('KNOWLEDGE_BASE.ENTRIES.SECTION_NOTE')"
      >
        <div class="flex flex-col gap-3">

          <!-- Loading state -->
          <woot-loading-state v-if="kbUIFlags.isFetching" />

          <!-- Entries list -->
          <template v-else>
            <div
              v-for="entry in entries"
              :key="entry.id"
              class="flex flex-col gap-2"
            >
              <!-- Edit form inline -->
              <KnowledgeBaseEntryForm
                v-if="editingEntry && editingEntry.id === entry.id"
                :entry="editingEntry"
                :is-loading="kbUIFlags.isUpdating"
                @submit="handleUpdateEntry"
                @cancel="cancelEdit"
              />

              <!-- Entry card -->
              <div
                v-else
                class="flex items-start justify-between gap-4 p-4 border border-n-slate-5 rounded-lg bg-n-slate-1"
              >
                <div class="flex flex-col gap-1 min-w-0 flex-1">
                  <span class="text-xs font-semibold text-woot-500 uppercase tracking-wide">
                    {{ entry.level }}
                  </span>
                  <p class="text-sm text-n-slate-12 whitespace-pre-wrap break-words">
                    {{ entry.description }}
                  </p>
                </div>
                <div class="flex gap-2 shrink-0">
                  <NextButton ghost icon="edit" @click="startEdit(entry)">
                    {{ $t('KNOWLEDGE_BASE.ENTRY.EDIT') }}
                  </NextButton>
                  <NextButton
                    ghost
                    icon="delete"
                    :is-loading="kbUIFlags.isDeleting"
                    @click="handleDeleteEntry(entry.id)"
                  >
                    {{ $t('KNOWLEDGE_BASE.ENTRY.DELETE') }}
                  </NextButton>
                </div>
              </div>
            </div>

            <!-- Empty state -->
            <p
              v-if="!entries.length && !showAddForm"
              class="text-sm text-n-slate-9 text-center py-4"
            >
              {{ $t('KNOWLEDGE_BASE.ENTRIES.EMPTY') }}
            </p>

            <!-- Add form -->
            <KnowledgeBaseEntryForm
              v-if="showAddForm"
              :is-loading="kbUIFlags.isCreating"
              @submit="handleAddEntry"
              @cancel="cancelAdd"
            />

            <!-- Add button -->
            <div v-if="!showAddForm">
              <NextButton
                blue
                icon="add"
                @click="showAddForm = true"
              >
                {{ $t('KNOWLEDGE_BASE.ENTRIES.ADD_BUTTON') }}
              </NextButton>
            </div>
          </template>

        </div>
      </SectionLayout>

    </div>
  </div>
</template>
```

---

## 5. API Reference

| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| `PATCH` | `/api/v1/accounts/:id` | `{ website_url, scraped_data }` | Save website URL / scraped data |
| `GET` | `/api/v1/accounts/:id/knowledge_base_entries` | none | List all entries |
| `POST` | `/api/v1/accounts/:id/knowledge_base_entries` | `{ knowledge_base_entry: { level, description } }` | Create entry |
| `PATCH` | `/api/v1/accounts/:id/knowledge_base_entries/:id` | `{ knowledge_base_entry: { level, description } }` | Update entry |
| `DELETE` | `/api/v1/accounts/:id/knowledge_base_entries/:id` | none | Delete entry |

**Auth:** All requests require `api_access_token` header.
**Permission:** Administrator only.

---

## 6. Run Migrations

```bash
docker-compose run --rm rails bundle exec rake db:migrate
```

---

## 7. Future Change Guide

| To change... | Edit this file |
|---|---|
| Website URL or scraped data columns | `db/migrate/..._add_knowledge_base_to_accounts.rb` |
| Entry table structure | `db/migrate/..._create_knowledge_base_entries.rb` |
| Entry validation rules | `app/models/knowledge_base_entry.rb` |
| Who can access the KB API | `app/policies/knowledge_base_entry_policy.rb` |
| Entry API logic | `app/controllers/api/v1/accounts/knowledge_base_entries_controller.rb` |
| website_url / scraped_data save logic | `app/controllers/api/v1/accounts_controller.rb` |
| API response fields for account | `app/views/api/v1/models/_account.json.jbuilder` |
| Add new KB API routes | `config/routes.rb` |
| Frontend API calls | `app/javascript/dashboard/api/knowledgeBaseEntries.js` |
| Vuex state / actions / mutations | `app/javascript/dashboard/store/modules/knowledgeBaseEntries.js` |
| Register new store modules | `app/javascript/dashboard/store/index.js` |
| KB page route / URL | `…/settings/knowledgeBase/knowledgeBase.routes.js` |
| KB settings page UI | `…/settings/knowledgeBase/Index.vue` |
| Entry add/edit form UI | `…/settings/knowledgeBase/components/KnowledgeBaseEntryForm.vue` |
| Register new settings routes | `…/settings/settings.routes.js` |
| Sidebar nav link | `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` |
| UI text / labels | `app/javascript/dashboard/i18n/locale/en/generalSettings.json` |
| Sidebar label text | `app/javascript/dashboard/i18n/locale/en/sidebar.json` |
