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

const account = computed(() =>
  store.getters['accounts/getAccount'](accountId.value)
);
const uiFlags = computed(() => store.getters['accounts/getUIFlags']);

logoUrl.value = account.value?.logo_url || '';

const updateLogo = async ({ file, url }) => {
  logoFile.value = file;
  logoUrl.value = url;
  try {
    await store.dispatch('accounts/updateLogo', {
      accountId: accountId.value,
      logoFile: file,
    });
    useAlert(t('GENERAL_SETTINGS.ACCOUNT_LOGO.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.ACCOUNT_LOGO.UPDATE_ERROR'));
  }
};

const deleteLogo = async () => {
  try {
    await store.dispatch('accounts/deleteLogo', {
      accountId: accountId.value,
    });
    logoUrl.value = '';
    logoFile.value = null;
    useAlert(t('GENERAL_SETTINGS.ACCOUNT_LOGO.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.ACCOUNT_LOGO.DELETE_ERROR'));
  }
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
