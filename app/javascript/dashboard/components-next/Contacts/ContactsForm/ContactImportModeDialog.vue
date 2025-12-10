<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['select-mode']);
const { t } = useI18n();

const dialogRef = ref(null);
const csvUrl = '/downloads/import-contacts-sample.csv';

const handleModeSelection = mode => {
  emit('select-mode', mode);
  dialogRef.value?.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT_MODE.TITLE')"
    :show-footer="false"
    size="lg"
  >
    <template #description>
      <p class="mb-4 text-sm text-n-slate-11">
        {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT_MODE.DESCRIPTION') }}
      </p>
    </template>

    <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
      <button
        class="flex flex-col items-start gap-3 rounded-lg border-2 border-n-slate-6 bg-n-slate-2 p-6 text-left transition-all hover:border-n-blue-9 hover:bg-n-slate-3"
        @click="handleModeSelection('standard')"
      >
        <div class="flex h-12 w-12 items-center justify-center rounded-lg bg-n-blue-3">
          <i class="i-lucide-file-text text-2xl text-n-blue-11" />
        </div>
        <div class="flex-1">
          <h3 class="mb-2 text-base font-semibold text-n-slate-12">
            {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT_MODE.STANDARD.TITLE') }}
          </h3>
          <p class="mb-3 text-sm text-n-slate-11">
            {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT_MODE.STANDARD.DESCRIPTION') }}
          </p>
          <a
            :href="csvUrl"
            target="_blank"
            rel="noopener noreferrer"
            download="import-contacts-sample.csv"
            class="inline-flex items-center gap-1 text-sm text-n-blue-text hover:underline"
            @click.stop
          >
            <i class="i-lucide-download text-base" />
            {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.DOWNLOAD_LABEL') }}
          </a>
        </div>
      </button>

      <button
        class="flex flex-col items-start gap-3 rounded-lg border-2 border-n-slate-6 bg-n-slate-2 p-6 text-left transition-all hover:border-n-blue-9 hover:bg-n-slate-3"
        @click="handleModeSelection('custom')"
      >
        <div class="flex h-12 w-12 items-center justify-center rounded-lg bg-n-green-3">
          <i class="i-lucide-upload text-2xl text-n-green-11" />
        </div>
        <div class="flex-1">
          <h3 class="mb-2 text-base font-semibold text-n-slate-12">
            {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT_MODE.CUSTOM.TITLE') }}
          </h3>
          <p class="text-sm text-n-slate-11">
            {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT_MODE.CUSTOM.DESCRIPTION') }}
          </p>
        </div>
      </button>
    </div>
  </Dialog>
</template>

