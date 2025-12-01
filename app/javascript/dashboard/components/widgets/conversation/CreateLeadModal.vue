<script setup>
import { ref, computed, watch } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
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

// Contact fields
const contactName = ref('');
const contactEmail = ref('');
const contactPhone = ref('');
const companyName = ref('');
const city = ref('');
const country = ref('');

// Deal fields
const dealTitle = ref('');
const amount = ref('');
const currency = ref('BRL');
const closeDate = ref('');
const notes = ref('');

// Pipeline selection
const pipelines = ref([]);
const selectedPipelineId = ref(null);
const stageOptions = ref([]);
const selectedStageId = ref(null);

const isSubmitting = ref(false);

const validations = {
  contactName: { required, minLength: minLength(2) },
  contactEmail: { required, email },
  contactPhone: { required, minLength: minLength(8) },
  dealTitle: { required, minLength: minLength(2) },
  amount: { required },
  currency: { required },
  selectedPipelineId: { required },
  selectedStageId: { required },
};

const v$ = useVuelidate(validations, {
  contactName,
  contactEmail,
  contactPhone,
  dealTitle,
  amount,
  currency,
  selectedPipelineId,
  selectedStageId,
});

const localShow = computed({
  get() {
    return props.show;
  },
  set(value) {
    emit('update:show', value);
  },
});

const isFormValid = computed(() => {
  return (
    contactName.value &&
    contactEmail.value &&
    contactPhone.value &&
    dealTitle.value &&
    amount.value &&
    currency.value &&
    selectedPipelineId.value &&
    selectedStageId.value
  );
});

const currencyOptions = ['BRL', 'USD', 'EUR'];

const loadPipelines = async () => {
  try {
    const { data } = await PipelinesAPI.get();
    pipelines.value = data || [];
    console.log('Pipelines loaded:', pipelines.value);
    if (pipelines.value.length) {
      selectedPipelineId.value = pipelines.value[0].id;
      stageOptions.value = (pipelines.value[0].pipeline_stages || [])
        .slice()
        .sort((a, b) => a.position - b.position);
      selectedStageId.value = stageOptions.value[0]?.id || null;
      console.log('Selected pipeline:', selectedPipelineId.value);
      console.log('Stage options:', stageOptions.value);
    }
  } catch (error) {
    console.error('Error loading pipelines:', error);
    alert('Erro ao carregar pipelines');
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

const onCancel = () => {
  resetForm();
  emit('cancel');
};

const resetForm = () => {
  contactName.value = '';
  contactEmail.value = '';
  contactPhone.value = '';
  companyName.value = '';
  city.value = '';
  country.value = '';
  dealTitle.value = '';
  amount.value = '';
  currency.value = 'BRL';
  closeDate.value = '';
  notes.value = '';
};

const onSubmit = async () => {
  if (!isFormValid.value) return;

  isSubmitting.value = true;
  try {
    await LeadsAPI.create({
      name: contactName.value,
      email: contactEmail.value,
      phone_number: contactPhone.value,
      company_name: companyName.value,
      city: city.value,
      country: country.value,
      title: dealTitle.value,
      amount: Number(amount.value),
      currency: currency.value,
      close_date: closeDate.value || null,
      notes: notes.value || null,
      pipeline_id: Number(selectedPipelineId.value),
      pipeline_stage_id: Number(selectedStageId.value),
    });

    alert(t('LEADS.CREATE.SUCCESS'));
    emit('success');
    onCancel();
  } catch (error) {
    const errorMessage =
      error.response?.data?.errors?.join(', ') ||
      t('LEADS.CREATE.ERROR');
    alert(errorMessage);
  } finally {
    isSubmitting.value = false;
  }
};

watch(
  () => props.show,
  newVal => {
    if (newVal) {
      loadPipelines();
    }
  },
  { immediate: true }
);
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onCancel">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('LEADS.CREATE.TITLE')"
        :header-content="$t('LEADS.CREATE.DESCRIPTION')"
      />
      <form class="w-full" @submit.prevent="onSubmit">
        <!-- Contact Information -->
        <div class="mb-4">
          <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ $t('LEADS.CREATE.CONTACT_INFO') }}
          </h3>
          <div class="grid grid-cols-2 gap-4">
            <div class="col-span-2">
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.NAME') }}
                  <span class="text-red-500">*</span>
                </span>
                <input
                  v-model="contactName"
                  type="text"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.NAME')"
                  required
                />
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.EMAIL') }}
                  <span class="text-red-500">*</span>
                </span>
                <input
                  v-model="contactEmail"
                  type="email"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.EMAIL')"
                  required
                />
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.PHONE') }}
                  <span class="text-red-500">*</span>
                </span>
                <input
                  v-model="contactPhone"
                  type="tel"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.PHONE')"
                  required
                />
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.COMPANY') }}
                </span>
                <input
                  v-model="companyName"
                  type="text"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.COMPANY')"
                />
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.CITY') }}
                </span>
                <input
                  v-model="city"
                  type="text"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.CITY')"
                />
              </label>
            </div>
          </div>
        </div>

        <!-- Deal Information -->
        <div class="mb-4">
          <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ $t('LEADS.CREATE.DEAL_INFO') }}
          </h3>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label>
                <span class="block text-sm mb-1">Pipeline</span>
                <select 
                  v-model="selectedPipelineId" 
                  @change="onChangePipeline"
                  :disabled="!pipelines.length"
                >
                  <option v-if="!pipelines.length" value="">Carregando...</option>
                  <option v-for="p in pipelines" :key="p.id" :value="p.id">
                    {{ p.name }}
                  </option>
                </select>
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.STAGE') }}
                </span>
                <select 
                  v-model="selectedStageId"
                  :disabled="!stageOptions.length"
                >
                  <option v-if="!stageOptions.length" value="">Selecione pipeline primeiro</option>
                  <option v-for="s in stageOptions" :key="s.id" :value="s.id">
                    {{ s.name }}
                  </option>
                </select>
              </label>
            </div>
            <div class="col-span-2">
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.TITLE') }}
                  <span class="text-red-500">*</span>
                </span>
                <input
                  v-model="dealTitle"
                  type="text"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.TITLE')"
                  required
                />
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.AMOUNT') }}
                  <span class="text-red-500">*</span>
                </span>
                <input
                  v-model="amount"
                  type="number"
                  step="0.01"
                  min="0"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.AMOUNT')"
                  required
                />
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.CURRENCY') }}
                </span>
                <select v-model="currency">
                  <option v-for="c in currencyOptions" :key="c" :value="c">
                    {{ c }}
                  </option>
                </select>
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.CLOSE_DATE') }}
                </span>
                <input
                  v-model="closeDate"
                  type="date"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.CLOSE_DATE')"
                />
              </label>
            </div>
            <div class="col-span-2">
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.NOTES') }}
                </span>
                <textarea
                  v-model="notes"
                  rows="3"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.NOTES')"
                />
              </label>
            </div>
          </div>
        </div>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-4">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('LEADS.CREATE.CANCEL')"
            @click.prevent="onCancel"
          />
          <NextButton
            type="submit"
            :label="$t('LEADS.CREATE.SUBMIT')"
            :disabled="!isFormValid || isSubmitting"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>

<style scoped>
label {
  display: block;
}

input,
select,
textarea {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid var(--n-alpha-2);
  border-radius: 0.375rem;
  background-color: var(--n-solid-1);
  color: var(--n-slate-12);
  font-size: 0.875rem;
}

input:focus,
select:focus,
textarea:focus {
  outline: none;
  border-color: var(--n-blue-9);
}

textarea {
  resize: vertical;
}

h3 {
  border-bottom: 1px solid var(--n-alpha-2);
  padding-bottom: 0.5rem;
}
</style>

