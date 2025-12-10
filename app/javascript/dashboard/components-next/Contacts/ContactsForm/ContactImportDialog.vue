<script setup>
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import ContactAPI from 'dashboard/api/contacts';
import { useAlert } from 'dashboard/composables';

import ContactImportModeDialog from './ContactImportModeDialog.vue';
import ContactFieldMapper from './ContactFieldMapper.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['import']);
const { t } = useI18n();

const uiFlags = useMapGetter('contacts/getUIFlags');
const isImportingContact = computed(() => uiFlags.value.isImporting);

const modeDialogRef = ref(null);
const standardDialogRef = ref(null);
const customDialogRef = ref(null);
const mapperDialogRef = ref(null);
const fileInput = ref(null);

const selectedMode = ref(null);
const hasSelectedFile = ref(null);
const selectedFileName = ref('');
const detectedColumns = ref([]);
const suggestedMapping = ref({});
const previewData = ref([]);
const isAnalyzing = ref(false);

const csvUrl = '/downloads/import-contacts-sample.csv';

// Exposed method to open the import flow
const open = () => {
  modeDialogRef.value?.dialogRef?.open();
};

const handleModeSelection = mode => {
  selectedMode.value = mode;
  
  if (mode === 'standard') {
    standardDialogRef.value?.open();
  } else {
    customDialogRef.value?.open();
  }
};

const handleFileClick = () => fileInput.value?.click();

const processFileName = fileName => {
  const lastDotIndex = fileName.lastIndexOf('.');
  const extension = fileName.slice(lastDotIndex);
  const baseName = fileName.slice(0, lastDotIndex);

  return baseName.length > 20
    ? `${baseName.slice(0, 20)}...${extension}`
    : fileName;
};

const handleFileChange = async () => {
  const file = fileInput.value?.files[0];
  hasSelectedFile.value = file;
  selectedFileName.value = file ? processFileName(file.name) : '';
};

const handleAnalyzeClick = async () => {
  if (!hasSelectedFile.value) return;
  await analyzeFile(hasSelectedFile.value);
};

const analyzeFile = async file => {
  isAnalyzing.value = true;
  try {
    const response = await ContactAPI.analyzeImportFile(file);
    detectedColumns.value = response.data.columns || [];
    suggestedMapping.value = response.data.suggested_mapping || {};
    
    // Parse CSV to get preview data
    await parsePreviewData(file);
    
    // Close custom dialog and open mapper
    customDialogRef.value?.close();
    mapperDialogRef.value?.dialogRef?.open();
  } catch (error) {
    useAlert(t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.ANALYZE_ERROR'));
    console.error('Error analyzing CSV:', error);
  } finally {
    isAnalyzing.value = false;
  }
};

const parsePreviewData = async file => {
  const text = await file.text();
  const lines = text.split('\n').slice(0, 4); // Header + 3 rows
  if (lines.length < 2) return;

  const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g, ''));
  previewData.value = lines.slice(1).map(line => {
    const values = line.split(',').map(v => v.trim().replace(/^"|"$/g, ''));
    const row = {};
    headers.forEach((header, index) => {
      row[header] = values[index] || '';
    });
    return row;
  });
};

const handleRemoveFile = () => {
  hasSelectedFile.value = null;
  if (fileInput.value) {
    fileInput.value.value = null;
  }
  selectedFileName.value = '';
  detectedColumns.value = [];
  suggestedMapping.value = {};
  previewData.value = [];
};

const uploadStandardFile = async () => {
  if (!hasSelectedFile.value) return;
  emit('import', hasSelectedFile.value, 'standard');
  standardDialogRef.value?.close();
  resetState();
};

const handleMappingConfirm = async columnMapping => {
  if (!hasSelectedFile.value) return;
  emit('import', hasSelectedFile.value, 'custom', columnMapping);
  mapperDialogRef.value?.dialogRef?.close();
  resetState();
};

const handleMappingCancel = () => {
  mapperDialogRef.value?.dialogRef?.close();
  customDialogRef.value?.open();
};

const resetState = () => {
  selectedMode.value = null;
  hasSelectedFile.value = null;
  selectedFileName.value = '';
  detectedColumns.value = [];
  suggestedMapping.value = {};
  previewData.value = [];
};

defineExpose({ open });
</script>

<template>
  <div>
    <!-- Mode Selection Dialog -->
    <ContactImportModeDialog
      ref="modeDialogRef"
      @select-mode="handleModeSelection"
    />

    <!-- Standard Import Dialog -->
    <Dialog
      ref="standardDialogRef"
      :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.TITLE')"
      :confirm-button-label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.IMPORT')"
      :is-loading="isImportingContact"
      :disable-confirm-button="isImportingContact || !hasSelectedFile"
      @confirm="uploadStandardFile"
    >
      <template #description>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.DESCRIPTION') }}
          <a
            :href="csvUrl"
            target="_blank"
            rel="noopener noreferrer"
            download="import-contacts-sample.csv"
            class="text-n-blue-text"
          >
            {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.DOWNLOAD_LABEL') }}
          </a>
        </p>
      </template>

      <div class="flex flex-col gap-2">
        <div class="flex items-center gap-2">
          <label class="text-sm text-n-slate-12 whitespace-nowrap">
            {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.LABEL') }}
          </label>
          <div class="flex items-center justify-between w-full gap-2">
            <span v-if="hasSelectedFile" class="text-sm text-n-slate-12">
              {{ selectedFileName }}
            </span>
            <Button
              v-if="!hasSelectedFile"
              :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHOOSE_FILE')"
              icon="i-lucide-upload"
              color="slate"
              variant="ghost"
              size="sm"
              class="!w-fit"
              @click="handleFileClick"
            />
            <div v-else class="flex items-center gap-1">
              <Button
                :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANGE')"
                color="slate"
                variant="ghost"
                size="sm"
                @click="handleFileClick"
              />
              <div class="w-px h-3 bg-n-strong" />
              <Button
                icon="i-lucide-trash"
                color="slate"
                variant="ghost"
                size="sm"
                @click="handleRemoveFile"
              />
            </div>
          </div>
        </div>
      </div>
      <input
        ref="fileInput"
        type="file"
        accept="text/csv"
        class="hidden"
        @change="handleFileChange"
      />
    </Dialog>

    <!-- Custom Import Dialog -->
    <Dialog
      ref="customDialogRef"
      :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.TITLE')"
      :confirm-button-label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.NEXT')"
      :is-loading="isAnalyzing"
      :disable-confirm-button="isAnalyzing || !hasSelectedFile"
      @confirm="handleAnalyzeClick"
    >
      <template #description>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.UPLOAD_DESCRIPTION') }}
        </p>
      </template>

      <div class="flex flex-col gap-2">
        <div class="flex items-center gap-2">
          <label class="text-sm text-n-slate-12 whitespace-nowrap">
            {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.LABEL') }}
          </label>
          <div class="flex items-center justify-between w-full gap-2">
            <span v-if="hasSelectedFile" class="text-sm text-n-slate-12">
              {{ selectedFileName }}
            </span>
            <Button
              v-if="!hasSelectedFile"
              :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHOOSE_FILE')"
              icon="i-lucide-upload"
              color="slate"
              variant="ghost"
              size="sm"
              class="!w-fit"
              @click="handleFileClick"
            />
            <div v-else class="flex items-center gap-1">
              <Button
                :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.CHANGE')"
                color="slate"
                variant="ghost"
                size="sm"
                @click="handleFileClick"
              />
              <div class="w-px h-3 bg-n-strong" />
              <Button
                icon="i-lucide-trash"
                color="slate"
                variant="ghost"
                size="sm"
                @click="handleRemoveFile"
              />
            </div>
          </div>
        </div>
      </div>
    </Dialog>

    <!-- Field Mapper Dialog -->
    <ContactFieldMapper
      ref="mapperDialogRef"
      :columns="detectedColumns"
      :preview-data="previewData"
      :suggested-mapping="suggestedMapping"
      @confirm="handleMappingConfirm"
      @cancel="handleMappingCancel"
    />
  </div>
</template>
