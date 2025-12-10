<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, numeric } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';
import DealsAPI from 'dashboard/api/deals';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  selectedDeal: {
    type: Object,
    required: true,
  },
  pipelineStages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['updated', 'close']);

const { t } = useI18n();
const alert = useAlert;

const isSubmitting = ref(false);

// Form data
const formData = ref({
  title: '',
  amount: '',
  currency: 'BRL',
  closeDate: '',
  notes: '',
  stageId: null,
});

// Initialize form with current deal data
watch(
  () => props.selectedDeal,
  deal => {
    if (deal) {
      const ca = deal.custom_attributes || {};
      formData.value = {
        title: ca.deal_title || '',
        amount: ca.deal_amount || '',
        currency: ca.deal_currency || 'BRL',
        closeDate: ca.deal_close_date || '',
        notes: ca.deal_notes || '',
        stageId: deal.pipeline_stage_id || props.pipelineStages[0]?.id || null,
      };
    }
  },
  { immediate: true }
);

// Validation rules
const rules = {
  title: { required },
  amount: { required, numeric },
  currency: { required },
  stageId: { required },
};

const v$ = useVuelidate(rules, formData);

const currencyOptions = ['BRL', 'USD', 'EUR'];

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

const contactName = computed(() => {
  return props.selectedDeal?.meta?.sender?.name || t('DEAL_DETAILS.NO_CONTACT');
});

const assigneeName = computed(() => {
  return props.selectedDeal?.meta?.assignee?.name || t('DEAL_DETAILS.NO_ASSIGNEE');
});

const currentStageName = computed(() => {
  const stage = props.pipelineStages.find(s => s.id === formData.value.stageId);
  return stage?.name || '';
});

const handleSubmit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    isSubmitting.value = true;
    
    const selectedStage = props.pipelineStages.find(s => s.id === Number(formData.value.stageId));
    
    await DealsAPI.update(props.selectedDeal.id, {
      deal: {
        title: formData.value.title,
        amount: Number(formData.value.amount),
        currency: formData.value.currency,
        close_date: formData.value.closeDate || null,
        notes: formData.value.notes || null,
        pipeline_stage_id: Number(formData.value.stageId),
      },
    });

    alert(t('DEAL_DETAILS.UPDATE_SUCCESS'));
    emit('updated', {
      ...formData.value,
      stageKey: selectedStage?.key,
    });
  } catch (error) {
    console.error('Error updating deal:', error);
    alert(t('DEAL_DETAILS.UPDATE_ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const handleCancel = () => {
  emit('close');
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <!-- Formulário de edição -->
    <form @submit.prevent="handleSubmit">
      <div class="rounded-xl bg-n-solid-2 p-6 ring-1 ring-n-alpha-2">
        <h2 class="text-base font-semibold text-n-slate-12 mb-4">
          {{ $t('DEAL_DETAILS.SECTIONS.EDIT_INFO') }}
        </h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Título -->
          <div class="col-span-2">
            <label class="text-xs font-medium text-n-slate-11 block mb-1">
              {{ $t('DEAL_DETAILS.FIELDS.TITLE') }} *
            </label>
            <input
              v-model="formData.title"
              type="text"
              class="w-full rounded-lg border border-n-strong bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 placeholder-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
              :class="{ 'border-n-ruby-9': v$.title.$error }"
              :placeholder="$t('KANBAN.FORM.PLACEHOLDERS.TITLE')"
              @blur="v$.title.$touch"
            />
            <span v-if="v$.title.$error" class="text-xs text-n-ruby-11 mt-1">
              {{ $t('DEAL_DETAILS.VALIDATION.TITLE_REQUIRED') }}
            </span>
          </div>

          <!-- Etapa -->
          <div>
            <label class="text-xs font-medium text-n-slate-11 block mb-1">
              {{ $t('DEAL_DETAILS.FIELDS.STAGE') }} *
            </label>
            <select
              v-model="formData.stageId"
              class="w-full rounded-lg border border-n-strong bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
              :class="{ 'border-n-ruby-9': v$.stageId.$error }"
              @blur="v$.stageId.$touch"
            >
              <option v-for="stage in pipelineStages" :key="stage.id" :value="stage.id">
                {{ stage.name }}
              </option>
            </select>
          </div>

          <!-- Moeda -->
          <div>
            <label class="text-xs font-medium text-n-slate-11 block mb-1">
              {{ $t('DEAL_DETAILS.FIELDS.CURRENCY') }} *
            </label>
            <select
              v-model="formData.currency"
              class="w-full rounded-lg border border-n-strong bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
              @blur="v$.currency.$touch"
            >
              <option v-for="curr in currencyOptions" :key="curr" :value="curr">
                {{ curr }}
              </option>
            </select>
          </div>

          <!-- Valor -->
          <div>
            <label class="text-xs font-medium text-n-slate-11 block mb-1">
              {{ $t('DEAL_DETAILS.FIELDS.AMOUNT') }} *
            </label>
            <input
              v-model="formData.amount"
              type="number"
              step="0.01"
              min="0"
              class="w-full rounded-lg border border-n-strong bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 placeholder-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
              :class="{ 'border-n-ruby-9': v$.amount.$error }"
              :placeholder="$t('KANBAN.FORM.PLACEHOLDERS.AMOUNT')"
              @blur="v$.amount.$touch"
            />
            <span v-if="v$.amount.$error" class="text-xs text-n-ruby-11 mt-1">
              {{ $t('DEAL_DETAILS.VALIDATION.AMOUNT_REQUIRED') }}
            </span>
          </div>

          <!-- Data de Fechamento -->
          <div>
            <label class="text-xs font-medium text-n-slate-11 block mb-1">
              {{ $t('DEAL_DETAILS.FIELDS.CLOSE_DATE') }}
            </label>
            <input
              v-model="formData.closeDate"
              type="date"
              class="w-full rounded-lg border border-n-strong bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
            />
          </div>

          <!-- Notas -->
          <div class="col-span-2">
            <label class="text-xs font-medium text-n-slate-11 block mb-1">
              {{ $t('DEAL_DETAILS.FIELDS.NOTES') }}
            </label>
            <textarea
              v-model="formData.notes"
              rows="4"
              class="w-full rounded-lg border border-n-strong bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 placeholder-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent resize-none"
              :placeholder="$t('KANBAN.FORM.PLACEHOLDERS.NOTES')"
            />
          </div>
        </div>

        <!-- Informações não editáveis -->
        <div class="mt-6 pt-6 border-t border-n-weak">
          <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ $t('DEAL_DETAILS.SECTIONS.CONTACT_INFO') }}
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
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

        <!-- Botões de ação -->
        <div class="flex justify-end gap-3 mt-6">
          <Button
            faded
            slate
            type="button"
            :label="$t('DEAL_DETAILS.CANCEL')"
            @click="handleCancel"
          />
          <Button
            type="submit"
            :label="$t('DEAL_DETAILS.SAVE')"
            :is-loading="isSubmitting"
            :disabled="isSubmitting || v$.$invalid"
          />
        </div>
      </div>
    </form>
  </div>
</template>

