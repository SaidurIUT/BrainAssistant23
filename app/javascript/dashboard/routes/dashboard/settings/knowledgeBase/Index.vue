<!--File: app/javascript/dashboard/routes/dashboard/settings/knowledgeBase/Index.vue-->

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
      scrapeJob: 'accounts/getScrapeJob', // { status, message }
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

    // Show the Scrape button only when a URL has been saved on the account.
    // This intentionally checks the stored account value, not the local input,
    // so the button only appears after a successful Save.
    hasSavedWebsiteUrl() {
      return !!this.currentAccount.website_url;
    },

    // True while the job is in a transient state
    isScraping() {
      return ['pending', 'running'].includes(this.scrapeJob?.status);
    },

    // Used to drive the status banner colour and icon
    scrapeStatusType() {
      const s = this.scrapeJob?.status;
      if (s === 'done') return 'success';
      if (s === 'failed') return 'error';
      return 'info';
    },

    // Human-readable status line shown in the banner
    scrapeStatusText() {
      const s = this.scrapeJob?.status;
      if (!s || s === 'idle') return '';

      // For running/pending, prefer the live message from the worker
      if (s === 'pending')
        return this.$t('KNOWLEDGE_BASE.WEBSITE_URL.SCRAPE_STATUS.PENDING');
      if (s === 'running') {
        return (
          this.scrapeJob.message ||
          this.$t('KNOWLEDGE_BASE.WEBSITE_URL.SCRAPE_STATUS.RUNNING')
        );
      }
      if (s === 'done')
        return this.$t('KNOWLEDGE_BASE.WEBSITE_URL.SCRAPE_STATUS.DONE');
      if (s === 'failed') {
        return (
          this.scrapeJob.message ||
          this.$t('KNOWLEDGE_BASE.WEBSITE_URL.SCRAPE_STATUS.FAILED')
        );
      }
      return '';
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

        // If a scrape was already running when the user navigated here,
        // resume polling so the UI stays in sync.
        const existingStatus = this.scrapeJob?.status;
        if (['pending', 'running'].includes(existingStatus)) {
          this.$store.dispatch('accounts/pollScrapeStatus', {
            accountId: this.accountId,
          });
        }
      } catch {
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

    async triggerScrape() {
      try {
        await this.$store.dispatch('accounts/triggerScrape', {
          accountId: this.accountId,
        });
        // polling is started inside the action — nothing else to do here
      } catch {
        useAlert(
          this.$t('KNOWLEDGE_BASE.WEBSITE_URL.SCRAPE_STATUS.TRIGGER_ERROR')
        );
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
      <!-- ── Website URL Section ──────────────────────────────────────────── -->
      <SectionLayout
        :title="$t('KNOWLEDGE_BASE.WEBSITE_URL.SECTION_TITLE')"
        :description="$t('KNOWLEDGE_BASE.WEBSITE_URL.SECTION_NOTE')"
      >
        <div class="grid gap-4">
          <WithLabel :label="$t('KNOWLEDGE_BASE.WEBSITE_URL.LABEL')">
            <!-- URL input + Save button -->
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

            <!-- Scrape Data button — only visible once a URL has been saved -->
            <div v-if="hasSavedWebsiteUrl" class="mt-2">
              <NextButton
                blue
                :is-loading="isScraping || accountUIFlags.isScraping"
                :disabled="isScraping || accountUIFlags.isScraping"
                @click="triggerScrape"
              >
                {{
                  isScraping
                    ? $t('KNOWLEDGE_BASE.WEBSITE_URL.SCRAPE_BUTTON_LOADING')
                    : $t('KNOWLEDGE_BASE.WEBSITE_URL.SCRAPE_BUTTON')
                }}
              </NextButton>
            </div>
          </WithLabel>

          <!-- ── Live status banner ───────────────────────────────────────── -->
          <!--
            Shown whenever a scrape job exists and is not idle.
            Colour coding:
              info    → pending / running  (blue-ish)
              success → done               (green)
              error   → failed             (red)
          -->
          <div
            v-if="scrapeJob && scrapeJob.status !== 'idle' && scrapeStatusText"
            class="flex items-start gap-2 rounded-lg px-4 py-3 text-sm"
            :class="{
              'bg-blue-50  text-blue-800  dark:bg-blue-900/30  dark:text-blue-300':
                scrapeStatusType === 'info',
              'bg-green-50 text-green-800 dark:bg-green-900/30 dark:text-green-300':
                scrapeStatusType === 'success',
              'bg-red-50   text-red-800   dark:bg-red-900/30   dark:text-red-300':
                scrapeStatusType === 'error',
            }"
          >
            <!-- Spinning indicator while running -->
            <span
              v-if="isScraping"
              class="mt-0.5 h-4 w-4 shrink-0 animate-spin rounded-full border-2 border-current border-t-transparent"
            />
            <!-- Static dot when finished -->
            <span
              v-else
              class="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-current"
            />

            <span>{{ scrapeStatusText }}</span>
          </div>
        </div>
      </SectionLayout>

      <!-- ── Scraped Data Section ─────────────────────────────────────────── -->
      <SectionLayout
        :title="$t('KNOWLEDGE_BASE.SCRAPED_DATA.SECTION_TITLE')"
        :description="$t('KNOWLEDGE_BASE.SCRAPED_DATA.SECTION_NOTE')"
      >
        <div class="grid gap-2">
          <textarea
            v-model="scrapedData"
            readonly
            class="w-full min-h-[200px] text-sm border border-n-slate-5 rounded-lg p-3 resize-y bg-n-slate-2 dark:bg-n-slate-3 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none cursor-default"
            :placeholder="$t('KNOWLEDGE_BASE.SCRAPED_DATA.EMPTY')"
          />
          <p class="text-xs text-n-slate-10">
            {{ $t('KNOWLEDGE_BASE.SCRAPED_DATA.HELPER') }}
          </p>
        </div>
      </SectionLayout>

      <!-- ── Additional Data Entries Section ─────────────────────────────── -->
      <SectionLayout
        :title="$t('KNOWLEDGE_BASE.ENTRIES.SECTION_TITLE')"
        :description="$t('KNOWLEDGE_BASE.ENTRIES.SECTION_NOTE')"
      >
        <div class="flex flex-col gap-3">
          <woot-loading-state v-if="kbUIFlags.isFetching" />

          <template v-else>
            <div
              v-for="entry in entries"
              :key="entry.id"
              class="flex flex-col gap-2"
            >
              <!-- Inline edit form -->
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
                  <span
                    class="text-xs font-semibold text-woot-500 uppercase tracking-wide"
                  >
                    {{ entry.level }}
                  </span>
                  <p
                    class="text-sm text-n-slate-12 whitespace-pre-wrap break-words"
                  >
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

            <p
              v-if="!entries.length && !showAddForm"
              class="text-sm text-n-slate-9 text-center py-4"
            >
              {{ $t('KNOWLEDGE_BASE.ENTRIES.EMPTY') }}
            </p>

            <KnowledgeBaseEntryForm
              v-if="showAddForm"
              :is-loading="kbUIFlags.isCreating"
              @submit="handleAddEntry"
              @cancel="cancelAdd"
            />

            <div v-if="!showAddForm">
              <NextButton blue icon="add" @click="showAddForm = true">
                {{ $t('KNOWLEDGE_BASE.ENTRIES.ADD_BUTTON') }}
              </NextButton>
            </div>
          </template>
        </div>
      </SectionLayout>
    </div>
  </div>
</template>
