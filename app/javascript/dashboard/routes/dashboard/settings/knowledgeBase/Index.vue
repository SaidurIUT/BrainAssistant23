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
            class="w-full min-h-[200px] text-sm border border-n-slate-5 rounded-lg p-3 resize-y bg-n-slate-2 dark:bg-n-slate-3 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none cursor-default"
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
