<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  selectedDeal: {
    type: Object,
    required: true,
  },
  pipelineStages: {
    type: Array,
    default: () => [],
  },
  isUpdating: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['updateDeal']);

const { t } = useI18n();

const dealData = computed(() => {
  const ca = props.selectedDeal?.custom_attributes || {};
  return {
    title: ca.deal_title || '',
    amount: ca.deal_amount || 0,
    currency: ca.deal_currency || 'BRL',
    closeDate: ca.deal_close_date || '',
    notes: ca.deal_notes || '',
    stage: ca.deal_stage || '',
  };
});

const contactName = computed(() => {
  return props.selectedDeal?.meta?.sender?.name || t('DEAL_DETAILS.NO_CONTACT');
});

const assigneeName = computed(() => {
  return props.selectedDeal?.meta?.assignee?.name || t('DEAL_DETAILS.NO_ASSIGNEE');
});

const formatCurrency = (amount, currency = 'BRL') => {
  try {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency,
      maximumFractionDigits: 2,
    }).format(Number(amount || 0));
  } catch (_) {
    return `R$ ${Number(amount || 0).toFixed(2)}`;
  }
};

const formatDate = date => {
  if (!date) return t('DEAL_DETAILS.NO_DATE');
  try {
    return new Intl.DateTimeFormat('pt-BR').format(new Date(date));
  } catch (_) {
    return date;
  }
};

const currentStageName = computed(() => {
  const stage = props.pipelineStages.find(s => s.key === dealData.value.stage);
  return stage?.name || dealData.value.stage;
});

// Obter custom attributes do contato que estejam preenchidos
const contactCustomAttributes = computed(() => {
  const customAttrs = props.selectedDeal?.contact?.custom_attributes || {};
  
  // Filtrar apenas atributos que têm valor
  const filled = Object.entries(customAttrs).filter(([key, value]) => {
    // Ignorar valores vazios, null, undefined
    if (value === null || value === undefined || value === '') return false;
    // Ignorar arrays/objetos vazios
    if (Array.isArray(value) && value.length === 0) return false;
    if (typeof value === 'object' && Object.keys(value).length === 0) return false;
    return true;
  });
  
  return filled.map(([key, value]) => ({
    key,
    value,
    label: formatAttributeLabel(key),
    formattedValue: formatAttributeValue(value),
  }));
});

// Formatar label do atributo (converter snake_case para título)
const formatAttributeLabel = key => {
  return key
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};

// Formatar valor do atributo
const formatAttributeValue = value => {
  if (typeof value === 'boolean') {
    return value ? t('DEAL_DETAILS.YES') : t('DEAL_DETAILS.NO');
  }
  if (Array.isArray(value)) {
    return value.join(', ');
  }
  if (typeof value === 'object') {
    return JSON.stringify(value, null, 2);
  }
  return String(value);
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <!-- Informações principais -->
    <div class="rounded-xl bg-n-solid-2 p-6 ring-1 ring-n-alpha-2">
      <h2 class="text-base font-semibold text-n-slate-12 mb-4">
        {{ $t('DEAL_DETAILS.SECTIONS.MAIN_INFO') }}
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="text-xs font-medium text-n-slate-11 block mb-1">
            {{ $t('DEAL_DETAILS.FIELDS.TITLE') }}
          </label>
          <p class="text-sm text-n-slate-12">
            {{ dealData.title || $t('DEAL_DETAILS.NO_TITLE') }}
          </p>
        </div>
        <div>
          <label class="text-xs font-medium text-n-slate-11 block mb-1">
            {{ $t('DEAL_DETAILS.FIELDS.STAGE') }}
          </label>
          <div class="inline-flex items-center gap-1.5 rounded-full bg-n-solid-1 px-2.5 py-1 text-xs font-medium text-n-slate-12 ring-1 ring-n-alpha-1">
            <span class="i-lucide-flag size-3 text-n-slate-11" />
            {{ currentStageName }}
          </div>
        </div>
        <div>
          <label class="text-xs font-medium text-n-slate-11 block mb-1">
            {{ $t('DEAL_DETAILS.FIELDS.AMOUNT') }}
          </label>
          <p class="text-sm font-semibold text-n-slate-12">
            {{ formatCurrency(dealData.amount, dealData.currency) }}
          </p>
        </div>
        <div>
          <label class="text-xs font-medium text-n-slate-11 block mb-1">
            {{ $t('DEAL_DETAILS.FIELDS.CLOSE_DATE') }}
          </label>
          <p class="text-sm text-n-slate-12">
            {{ formatDate(dealData.closeDate) }}
          </p>
        </div>
        <div>
          <label class="text-xs font-medium text-n-slate-11 block mb-1">
            {{ $t('DEAL_DETAILS.FIELDS.CONTACT') }}
          </label>
          <p class="text-sm text-n-slate-12">
            {{ contactName }}
          </p>
        </div>
        <div>
          <label class="text-xs font-medium text-n-slate-11 block mb-1">
            {{ $t('DEAL_DETAILS.FIELDS.ASSIGNEE') }}
          </label>
          <p class="text-sm text-n-slate-12">
            {{ assigneeName }}
          </p>
        </div>
      </div>
    </div>

    <!-- Notas -->
    <div
      v-if="dealData.notes"
      class="rounded-xl bg-n-solid-2 p-6 ring-1 ring-n-alpha-2"
    >
      <h2 class="text-base font-semibold text-n-slate-12 mb-4">
        {{ $t('DEAL_DETAILS.SECTIONS.NOTES') }}
      </h2>
      <p class="text-sm text-n-slate-11 whitespace-pre-wrap">
        {{ dealData.notes }}
      </p>
    </div>

    <!-- Atributos Personalizados do Contato -->
    <div
      v-if="contactCustomAttributes.length > 0"
      class="rounded-xl bg-n-solid-2 p-6 ring-1 ring-n-alpha-2"
    >
      <div class="flex items-center gap-2 mb-4">
        <span class="i-lucide-user size-5 text-n-slate-11" />
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ $t('DEAL_DETAILS.SECTIONS.CONTACT_ATTRIBUTES') }}
        </h2>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div
          v-for="attr in contactCustomAttributes"
          :key="attr.key"
          class="rounded-lg bg-n-solid-1 p-3 ring-1 ring-n-alpha-1"
        >
          <label class="text-xs font-medium text-n-slate-11 block mb-1">
            {{ attr.label }}
          </label>
          <p class="text-sm text-n-slate-12 break-words">
            {{ attr.formattedValue }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

