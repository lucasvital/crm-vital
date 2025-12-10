<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  columns: {
    type: Array,
    required: true,
  },
  previewData: {
    type: Array,
    default: () => [],
  },
  suggestedMapping: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['confirm', 'cancel']);
const { t } = useI18n();

const dialogRef = ref(null);
const columnMapping = ref({});

// Available fields to map to
const FIELD_OPTIONS = [
  { value: 'name', label: 'Nome', required: true },
  { value: 'email', label: 'Email', required: true },
  { value: 'phone_number', label: 'Telefone', required: true },
  { value: 'identifier', label: 'Identificador', required: false },
  { value: 'company', label: 'Empresa', required: false },
  { value: 'city', label: 'Cidade', required: false },
  { value: 'ignore', label: 'Ignorar coluna', required: false },
];

// Initialize mapping with suggestions on mount
onMounted(() => {
  if (Object.keys(props.suggestedMapping).length > 0) {
    columnMapping.value = { ...props.suggestedMapping };
  }
});

// Check if all required fields are mapped
const missingRequiredFields = computed(() => {
  const mappedFields = Object.values(columnMapping.value);
  const requiredFields = FIELD_OPTIONS.filter(f => f.required).map(f => f.value);
  return requiredFields.filter(field => !mappedFields.includes(field));
});

const canConfirm = computed(() => missingRequiredFields.value.length === 0);

const getFieldLabel = fieldId => {
  const field = FIELD_OPTIONS.find(f => f.value === fieldId);
  return field ? field.label : fieldId;
};

const getAvailableOptionsForColumn = column => {
  const alreadyMapped = Object.entries(columnMapping.value)
    .filter(([col]) => col !== column)
    .map(([, field]) => field);

  return FIELD_OPTIONS.map(option => ({
    ...option,
    disabled: option.value !== 'ignore' && alreadyMapped.includes(option.value),
  }));
};

const handleApplySuggestions = () => {
  columnMapping.value = { ...props.suggestedMapping };
};

const updateMapping = (column, value) => {
  columnMapping.value = {
    ...columnMapping.value,
    [column]: value,
  };
};

const getMappingForColumn = column => {
  return columnMapping.value[column] || '';
};

const handleConfirm = () => {
  // Remove ignored columns from mapping
  const finalMapping = Object.fromEntries(
    Object.entries(columnMapping.value).filter(([, field]) => field !== 'ignore')
  );
  emit('confirm', finalMapping);
  dialogRef.value?.close();
};

const handleCancel = () => {
  emit('cancel');
  dialogRef.value?.close();
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.TITLE')"
    :confirm-button-label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.CONFIRM')"
    :cancel-button-label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.CANCEL')"
    :disable-confirm-button="!canConfirm"
    size="lg"
    @confirm="handleConfirm"
    @cancel="handleCancel"
  >
    <template #description>
      <div class="mb-4 flex items-center justify-between">
        <p class="text-sm text-n-slate-11">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.DESCRIPTION') }}
        </p>
        <Button
          v-if="Object.keys(suggestedMapping).length > 0"
          :label="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.AUTO_SUGGEST')"
          icon="i-lucide-wand-sparkles"
          color="slate"
          variant="ghost"
          size="sm"
          @click="handleApplySuggestions"
        />
      </div>
      <div
        v-if="missingRequiredFields.length > 0"
        class="mb-4 rounded-lg border border-n-red-6 bg-n-red-2 p-3"
      >
        <div class="flex items-start gap-2">
          <i class="i-lucide-alert-circle text-lg text-n-red-11" />
          <div class="flex-1">
            <p class="text-sm font-medium text-n-red-12">
              {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.MISSING_REQUIRED') }}
            </p>
            <p class="mt-1 text-sm text-n-red-11">
              {{ missingRequiredFields.map(getFieldLabel).join(', ') }}
            </p>
          </div>
        </div>
      </div>
    </template>

    <div class="space-y-4 max-h-[60vh] overflow-y-auto">
      <!-- Mapping Table -->
      <div class="overflow-hidden rounded-lg border border-n-slate-6">
        <table class="w-full">
          <thead class="bg-n-slate-3">
            <tr>
              <th class="px-4 py-3 text-left text-sm font-semibold text-n-slate-12">
                {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.CSV_COLUMN') }}
              </th>
              <th class="px-4 py-3 text-left text-sm font-semibold text-n-slate-12">
                {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.MAP_TO') }}
              </th>
              <th
                v-if="previewData.length > 0"
                class="px-4 py-3 text-left text-sm font-semibold text-n-slate-12"
              >
                {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.PREVIEW') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-slate-6">
            <tr
              v-for="column in columns"
              :key="column"
              class="bg-n-slate-1 hover:bg-n-slate-2"
            >
              <td class="px-4 py-3 text-sm font-medium text-n-slate-12">
                {{ column }}
              </td>
              <td class="px-4 py-3">
                <ComboBox
                  :model-value="getMappingForColumn(column)"
                  :options="getAvailableOptionsForColumn(column)"
                  :placeholder="t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.SELECT_FIELD')"
                  size="sm"
                  class="w-full"
                  @update:model-value="updateMapping(column, $event)"
                />
              </td>
              <td
                v-if="previewData.length > 0"
                class="px-4 py-3 text-sm text-n-slate-11"
              >
                <span class="line-clamp-1">
                  {{ previewData[0]?.[column] || '-' }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Preview Section - Simplified -->
      <div
        v-if="previewData.length > 0"
        class="rounded-lg border border-n-slate-6 bg-n-slate-2 p-3"
      >
        <h4 class="mb-2 text-sm font-semibold text-n-slate-12">
          {{ t('CONTACTS_LAYOUT.HEADER.ACTIONS.IMPORT_CONTACT.FIELD_MAPPER.PREVIEW_DATA') }}
        </h4>
        <div class="space-y-2">
          <div
            v-for="(row, index) in previewData.slice(0, 2)"
            :key="index"
            class="rounded border border-n-slate-6 bg-n-slate-1 p-2 text-xs"
          >
            <div class="flex flex-wrap gap-x-3 gap-y-1">
              <span
                v-for="[col, field] of Object.entries(columnMapping)"
                :key="col"
                class="text-n-slate-11"
              >
                <span v-if="field && field !== 'ignore'">
                  <strong class="text-n-slate-12">{{ getFieldLabel(field) }}:</strong>
                  {{ row[col] || '-' }}
                </span>
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Dialog>
</template>
