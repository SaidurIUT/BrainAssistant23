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
  emit('submit', {
    level: level.value.trim(),
    description: description.value.trim(),
  });
};

const handleCancel = () => {
  level.value = '';
  description.value = '';
  emit('cancel');
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 border border-n-slate-5 rounded-lg bg-n-slate-1"
  >
    <WithLabel :label="t('KNOWLEDGE_BASE.ENTRY.LEVEL.LABEL')">
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
        class="w-full min-h-[100px] text-sm border border-n-slate-5 rounded-lg p-2 resize-y bg-white dark:bg-n-slate-2 text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:ring-1 focus:ring-woot-500"
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
        {{
          entry
            ? $t('KNOWLEDGE_BASE.ENTRY.UPDATE')
            : $t('KNOWLEDGE_BASE.ENTRY.ADD')
        }}
      </NextButton>
    </div>
  </div>
</template>
