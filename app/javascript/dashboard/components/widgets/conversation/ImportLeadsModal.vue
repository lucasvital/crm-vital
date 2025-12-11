<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PipelinesAPI from 'dashboard/api/pipelines';
import LeadsAPI from 'dashboard/api/leads';

const props = defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['cancel', 'update:show', 'success']);

const { t } = useI18n();
const alert = useAlert;

// Wizard steps
const currentStep = ref(1);
const isProcessing = ref(false);

// Step 1: File upload
const fileInput = ref(null);
const selectedFile = ref(null);
const selectedFileName = ref('');
const importId = ref(null);

// Step 2: Column mapping
const csvColumns = ref([]);
const previewRows = ref([]);
const totalRows = ref(0);
const columnMapping = ref({});

// Step 3: Configuration
const pipelines = ref([]);
const selectedPipelineId = ref(null);
const stageOptions = ref([]);
const selectedStageId = ref(null);

// Available system fields for mapping
const systemFields = [
  { value: 'skip', label: t('LEADS.IMPORT.STEP_2.SKIP_COLUMN') },
  { value: 'contact_name', label: t('LEADS.IMPORT.FIELDS.CONTACT_NAME'), group: 'contact', required: true },
  { value: 'contact_email', label: t('LEADS.IMPORT.FIELDS.CONTACT_EMAIL'), group: 'contact', required: true },
  { value: 'contact_phone', label: t('LEADS.IMPORT.FIELDS.CONTACT_PHONE'), group: 'contact', required: true },
  { value: 'contact_company', label: t('LEADS.IMPORT.FIELDS.CONTACT_COMPANY'), group: 'contact' },
  { value: 'contact_city', label: t('LEADS.IMPORT.FIELDS.CONTACT_CITY'), group: 'contact' },
  { value: 'contact_country', label: t('LEADS.IMPORT.FIELDS.CONTACT_COUNTRY'), group: 'contact' },
  { value: 'contact_labels', label: t('LEADS.IMPORT.FIELDS.CONTACT_LABELS'), group: 'contact' },
  { value: 'deal_title', label: t('LEADS.IMPORT.FIELDS.DEAL_TITLE'), group: 'deal' },
  { value: 'deal_amount', label: t('LEADS.IMPORT.FIELDS.DEAL_AMOUNT'), group: 'deal' },
  { value: 'deal_currency', label: t('LEADS.IMPORT.FIELDS.DEAL_CURRENCY'), group: 'deal' },
  { value: 'deal_close_date', label: t('LEADS.IMPORT.FIELDS.DEAL_CLOSE_DATE'), group: 'deal' },
  { value: 'deal_notes', label: t('LEADS.IMPORT.FIELDS.DEAL_NOTES'), group: 'deal' },
  { value: 'deal_labels', label: t('LEADS.IMPORT.FIELDS.DEAL_LABELS'), group: 'deal' },
];

const localShow = computed({
  get() {
    return props.show;
  },
  set(value) {
    emit('update:show', value);
  },
});

const canProceedStep1 = computed(() => selectedFile.value !== null);

const canProceedStep2 = computed(() => {
  // Verificar se os campos obrigatórios foram mapeados
  const requiredFields = ['contact_name', 'contact_email', 'contact_phone'];
  const mappedValues = Object.values(columnMapping.value);
  return requiredFields.every(field => mappedValues.includes(field));
});

const canProceedStep3 = computed(() => {
  return selectedPipelineId.value && selectedStageId.value;
});

const validRowsCount = computed(() => {
  // Para simplificar, assumimos que todas as linhas são válidas se os campos obrigatórios estão mapeados
  return canProceedStep2.value ? totalRows.value : 0;
});

const invalidRowsCount = computed(() => {
  return totalRows.value - validRowsCount.value;
});

// Step 1 methods
const handleFileClick = () => fileInput.value?.click();

const processFileName = fileName => {
  const lastDotIndex = fileName.lastIndexOf('.');
  const extension = fileName.slice(lastDotIndex);
  const baseName = fileName.slice(0, lastDotIndex);
  return baseName.length > 30
    ? `${baseName.slice(0, 30)}...${extension}`
    : fileName;
};

const handleFileChange = async () => {
  const file = fileInput.value?.files[0];
  if (!file) return;

  selectedFile.value = file;
  selectedFileName.value = processFileName(file.name);
};

const handleRemoveFile = () => {
  selectedFile.value = null;
  selectedFileName.value = '';
  if (fileInput.value) {
    fileInput.value.value = null;
  }
};

// Step 2 methods
const uploadAndPreview = async () => {
  if (!selectedFile.value) return;

  isProcessing.value = true;
  try {
    const response = await LeadsAPI.importUpload(selectedFile.value);
    importId.value = response.data.import_id;
    csvColumns.value = response.data.columns || [];
    previewRows.value = response.data.preview_rows || [];
    totalRows.value = response.data.total_rows || 0;

    // Auto-map columns based on similar names
    autoMapColumns();

    currentStep.value = 2;
  } catch (error) {
    const errorMessage =
      error.response?.data?.error || t('LEADS.IMPORT.ERROR');
    alert(errorMessage);
  } finally {
    isProcessing.value = false;
  }
};

const autoMapColumns = () => {
  const mapping = {};
  csvColumns.value.forEach(column => {
    const normalized = column.toLowerCase().trim();
    
    // Try to auto-detect field based on column name
    if (normalized.includes('nome') || normalized.includes('name')) {
      mapping[column] = 'contact_name';
    } else if (normalized.includes('email') || normalized.includes('e-mail')) {
      mapping[column] = 'contact_email';
    } else if (normalized.includes('telefone') || normalized.includes('phone') || normalized.includes('celular')) {
      mapping[column] = 'contact_phone';
    } else if (normalized.includes('empresa') || normalized.includes('company')) {
      mapping[column] = 'contact_company';
    } else if (normalized.includes('cidade') || normalized.includes('city')) {
      mapping[column] = 'contact_city';
    } else if (normalized.includes('país') || normalized.includes('pais') || normalized.includes('country')) {
      mapping[column] = 'contact_country';
    } else if ((normalized.includes('etiqueta') || normalized.includes('label') || normalized.includes('tag')) && 
               (normalized.includes('contato') || normalized.includes('contact'))) {
      mapping[column] = 'contact_labels';
    } else if (normalized.includes('título') || normalized.includes('titulo') || normalized.includes('title')) {
      mapping[column] = 'deal_title';
    } else if (normalized.includes('valor') || normalized.includes('amount') || normalized.includes('price')) {
      mapping[column] = 'deal_amount';
    } else if (normalized.includes('moeda') || normalized.includes('currency')) {
      mapping[column] = 'deal_currency';
    } else if (normalized.includes('data') || normalized.includes('date')) {
      mapping[column] = 'deal_close_date';
    } else if (normalized.includes('nota') || normalized.includes('observa') || normalized.includes('note')) {
      mapping[column] = 'deal_notes';
    } else if ((normalized.includes('etiqueta') || normalized.includes('label') || normalized.includes('tag')) && 
               (normalized.includes('deal') || normalized.includes('negoc'))) {
      mapping[column] = 'deal_labels';
    } else if (normalized.includes('etiqueta') || normalized.includes('label') || normalized.includes('tag')) {
      // Genérico - se só tem "etiqueta" sem contexto, mapeia para contact_labels
      mapping[column] = 'contact_labels';
    } else {
      mapping[column] = 'skip';
    }
  });
  
  columnMapping.value = mapping;
};

// Step 3 methods
const loadPipelines = async () => {
  const { data } = await PipelinesAPI.get();
  pipelines.value = data || [];
  if (pipelines.value.length) {
    selectedPipelineId.value = pipelines.value[0].id;
    stageOptions.value = (pipelines.value[0].pipeline_stages || [])
      .slice()
      .sort((a, b) => a.position - b.position);
    selectedStageId.value = stageOptions.value[0]?.id || null;
  }
};

const onChangePipeline = () => {
  const found = pipelines.value.find(
    p => p.id === Number(selectedPipelineId.value)
  );
  stageOptions.value = (found?.pipeline_stages || [])
    .slice()
    .sort((a, b) => a.position - b.position);
  selectedStageId.value = stageOptions.value[0]?.id || null;
};

const proceedToStep3 = async () => {
  await loadPipelines();
  currentStep.value = 3;
};

// Import processing
const processImport = async () => {
  if (!canProceedStep3.value) return;

  isProcessing.value = true;
  try {
    const response = await LeadsAPI.importProcess({
      import_id: importId.value,
      column_mapping: columnMapping.value,
      pipeline_id: selectedPipelineId.value,
      pipeline_stage_id: selectedStageId.value,
    });

    const successCount = response.data.success_count || 0;
    const errorCount = response.data.error_count || 0;

    if (errorCount > 0) {
      alert(
        `${t('LEADS.IMPORT.COMPLETED')} ${successCount} ${t('LEADS.IMPORT.SUCCESS')}, ${errorCount} com erros.`
      );
    } else {
      alert(t('LEADS.IMPORT.SUCCESS'));
    }

    emit('success');
    onCancel();
  } catch (error) {
    const errorMessage =
      error.response?.data?.error || t('LEADS.IMPORT.ERROR');
    alert(errorMessage);
  } finally {
    isProcessing.value = false;
  }
};

// Navigation
const goBack = () => {
  if (currentStep.value > 1) {
    currentStep.value -= 1;
  }
};

const goNext = () => {
  if (currentStep.value === 1 && canProceedStep1.value) {
    uploadAndPreview();
  } else if (currentStep.value === 2 && canProceedStep2.value) {
    proceedToStep3();
  }
};

const onCancel = () => {
  currentStep.value = 1;
  selectedFile.value = null;
  selectedFileName.value = '';
  importId.value = null;
  csvColumns.value = [];
  previewRows.value = [];
  totalRows.value = 0;
  columnMapping.value = {};
  pipelines.value = [];
  selectedPipelineId.value = null;
  stageOptions.value = [];
  selectedStageId.value = null;
  emit('cancel');
};

const getFieldLabel = value => {
  const field = systemFields.find(f => f.value === value);
  return field ? field.label : value;
};

const isFieldRequired = value => {
  const field = systemFields.find(f => f.value === value);
  return field?.required || false;
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onCancel" size="large">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('LEADS.IMPORT.TITLE')"
        :header-content="$t('LEADS.IMPORT.DESCRIPTION')"
      />

      <!-- Progress Indicator -->
      <div class="flex items-center justify-between mb-6 px-4">
        <div
          v-for="step in 3"
          :key="step"
          class="flex items-center"
          :class="{ 'flex-1': step < 3 }"
        >
          <div
            class="flex items-center justify-center w-8 h-8 rounded-full text-sm font-semibold"
            :class="
              currentStep >= step
                ? 'bg-n-blue-9 text-white'
                : 'bg-n-solid-3 text-n-slate-11'
            "
          >
            {{ step }}
          </div>
          <div
            v-if="step < 3"
            class="h-0.5 flex-1 mx-2"
            :class="
              currentStep > step ? 'bg-n-blue-9' : 'bg-n-solid-3'
            "
          />
        </div>
      </div>

      <!-- Step 1: Upload -->
      <div v-if="currentStep === 1" class="px-4">
        <h3 class="text-lg font-semibold text-n-slate-12 mb-2">
          {{ $t('LEADS.IMPORT.STEP_1.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ $t('LEADS.IMPORT.STEP_1.DESCRIPTION') }}
        </p>

        <div
          class="border-2 border-dashed border-n-alpha-2 rounded-lg p-8 text-center cursor-pointer hover:border-n-blue-9 transition"
          @click="handleFileClick"
        >
          <span class="i-lucide-upload text-4xl text-n-slate-11 mb-2" />
          <p class="text-sm text-n-slate-12 mb-1">
            {{ $t('LEADS.IMPORT.STEP_1.CHOOSE_FILE') }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ $t('LEADS.IMPORT.STEP_1.DRAG_DROP') }}
          </p>
        </div>

        <div v-if="selectedFile" class="mt-4 flex items-center justify-between bg-n-solid-2 p-3 rounded-md">
          <span class="text-sm text-n-slate-12">{{ selectedFileName }}</span>
          <button
            class="text-n-ruby-11 hover:text-n-ruby-12"
            @click.stop="handleRemoveFile"
          >
            <span class="i-lucide-x size-4" />
          </button>
        </div>

        <p class="text-xs text-n-slate-11 mt-2">
          {{ $t('LEADS.IMPORT.STEP_1.FILE_REQUIREMENTS') }}
        </p>

        <input
          ref="fileInput"
          type="file"
          accept=".csv"
          class="hidden"
          @change="handleFileChange"
        />
      </div>

      <!-- Step 2: Mapping -->
      <div v-if="currentStep === 2" class="px-4">
        <h3 class="text-lg font-semibold text-n-slate-12 mb-2">
          {{ $t('LEADS.IMPORT.STEP_2.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ $t('LEADS.IMPORT.STEP_2.DESCRIPTION') }}
        </p>

        <div class="mb-4 p-3 bg-n-amber-3 border border-n-amber-7 rounded-md">
          <p class="text-sm text-n-amber-11">
            {{ $t('LEADS.IMPORT.STEP_2.REQUIRED_FIELDS') }}
          </p>
        </div>

        <div class="space-y-3 max-h-96 overflow-y-auto">
          <div
            v-for="column in csvColumns"
            :key="column"
            class="grid grid-cols-3 gap-4 items-start p-3 bg-n-solid-2 rounded-md"
          >
            <div>
              <label class="text-xs text-n-slate-11 mb-1 block">
                {{ $t('LEADS.IMPORT.STEP_2.COLUMN') }}
              </label>
              <div class="text-sm font-medium text-n-slate-12">{{ column }}</div>
            </div>
            <div>
              <label class="text-xs text-n-slate-11 mb-1 block">
                {{ $t('LEADS.IMPORT.STEP_2.MAPS_TO') }}
              </label>
              <select
                v-model="columnMapping[column]"
                class="w-full text-sm"
              >
                <option value="skip">{{ $t('LEADS.IMPORT.STEP_2.SKIP_COLUMN') }}</option>
                <optgroup :label="$t('LEADS.IMPORT.STEP_2.CONTACT_FIELDS')">
                  <option
                    v-for="field in systemFields.filter(f => f.group === 'contact')"
                    :key="field.value"
                    :value="field.value"
                  >
                    {{ field.label }}{{ field.required ? ' *' : '' }}
                  </option>
                </optgroup>
                <optgroup :label="$t('LEADS.IMPORT.STEP_2.DEAL_FIELDS')">
                  <option
                    v-for="field in systemFields.filter(f => f.group === 'deal')"
                    :key="field.value"
                    :value="field.value"
                  >
                    {{ field.label }}
                  </option>
                </optgroup>
              </select>
            </div>
            <div>
              <label class="text-xs text-n-slate-11 mb-1 block">
                {{ $t('LEADS.IMPORT.STEP_2.PREVIEW') }}
              </label>
              <div class="text-sm text-n-slate-11 truncate">
                {{ previewRows[0]?.[column] || '-' }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Step 3: Configuration -->
      <div v-if="currentStep === 3" class="px-4">
        <h3 class="text-lg font-semibold text-n-slate-12 mb-2">
          {{ $t('LEADS.IMPORT.STEP_3.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ $t('LEADS.IMPORT.STEP_3.DESCRIPTION') }}
        </p>

        <div class="grid grid-cols-2 gap-4 mb-6">
          <div>
            <label class="text-sm text-n-slate-12 mb-1 block">
              {{ $t('LEADS.IMPORT.STEP_3.SELECT_PIPELINE') }}
            </label>
            <select
              v-model="selectedPipelineId"
              class="w-full"
              @change="onChangePipeline"
            >
              <option v-for="p in pipelines" :key="p.id" :value="p.id">
                {{ p.name }}
              </option>
            </select>
          </div>
          <div>
            <label class="text-sm text-n-slate-12 mb-1 block">
              {{ $t('LEADS.IMPORT.STEP_3.SELECT_STAGE') }}
            </label>
            <select v-model="selectedStageId" class="w-full">
              <option v-for="s in stageOptions" :key="s.id" :value="s.id">
                {{ s.name }}
              </option>
            </select>
          </div>
        </div>

        <div class="p-4 bg-n-solid-2 rounded-md">
          <h4 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ $t('LEADS.IMPORT.STEP_3.IMPORT_SUMMARY') }}
          </h4>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-n-slate-11">{{ $t('LEADS.IMPORT.STEP_3.TOTAL_ROWS') }}:</span>
              <span class="font-semibold text-n-slate-12">{{ totalRows }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-n-slate-11">{{ $t('LEADS.IMPORT.STEP_3.VALID_ROWS') }}:</span>
              <span class="font-semibold text-n-green-11">{{ validRowsCount }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-n-slate-11">{{ $t('LEADS.IMPORT.STEP_3.INVALID_ROWS') }}:</span>
              <span class="font-semibold text-n-ruby-11">{{ invalidRowsCount }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex flex-row justify-between w-full gap-2 px-4 py-4 mt-4 border-t border-n-alpha-2">
        <NextButton
          v-if="currentStep > 1"
          faded
          slate
          type="button"
          icon="i-lucide-arrow-left"
          :label="$t('LEADS.IMPORT.BUTTONS.BACK')"
          :disabled="isProcessing"
          @click="goBack"
        />
        <div v-else />

        <div class="flex gap-2">
          <NextButton
            faded
            slate
            type="button"
            :label="$t('LEADS.IMPORT.BUTTONS.CANCEL')"
            :disabled="isProcessing"
            @click="onCancel"
          />
          <NextButton
            v-if="currentStep < 3"
            type="button"
            trailing-icon="i-lucide-arrow-right"
            :label="$t('LEADS.IMPORT.BUTTONS.NEXT')"
            :disabled="
              (currentStep === 1 && !canProceedStep1) ||
              (currentStep === 2 && !canProceedStep2) ||
              isProcessing
            "
            @click="goNext"
          />
          <NextButton
            v-else
            type="button"
            :label="$t('LEADS.IMPORT.BUTTONS.IMPORT')"
            :disabled="!canProceedStep3 || isProcessing"
            @click="processImport"
          />
        </div>
      </div>
    </div>
  </woot-modal>
</template>

<style scoped>
select {
  padding: 0.5rem;
  border: 1px solid var(--n-alpha-2);
  border-radius: 0.375rem;
  background-color: var(--n-solid-1);
  color: var(--n-slate-12);
  font-size: 0.875rem;
}

select:focus {
  outline: none;
  border-color: var(--n-blue-9);
}
</style>

