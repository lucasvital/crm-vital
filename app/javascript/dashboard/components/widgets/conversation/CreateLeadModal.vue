<script setup>
import { ref, computed, watch } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PipelinesAPI from 'dashboard/api/pipelines';
import LeadsAPI from 'dashboard/api/leads';
import ContactAPI from 'dashboard/api/contacts';
import DealsAPI from 'dashboard/api/deals';

const props = defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['cancel', 'update:show', 'success']);

const { t } = useI18n();
const alert = useAlert;

// Contact search and selection
const searchQuery = ref('');
const searchResults = ref([]);
const selectedContact = ref(null);
const isSearching = ref(false);
const showCreateContactForm = ref(false);
const showContactDropdown = ref(false);

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

// Validações condicionais - só valida contato se estiver criando novo
const validations = computed(() => {
  const baseValidations = {
    dealTitle: { required, minLength: minLength(2) },
    amount: { required },
    currency: { required },
    selectedPipelineId: { required },
    selectedStageId: { required },
  };

  // Só adiciona validação de contato se não tiver contato selecionado
  if (!selectedContact.value && showCreateContactForm.value) {
    return {
      ...baseValidations,
      contactName: { required, minLength: minLength(2) },
      contactEmail: { required, email },
      contactPhone: { required, minLength: minLength(8) },
    };
  }

  return baseValidations;
});

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
  // Se tem contato selecionado, só precisa validar o deal
  if (selectedContact.value) {
    return (
      dealTitle.value &&
      amount.value &&
      currency.value &&
      selectedPipelineId.value &&
      selectedStageId.value
    );
  }
  // Se vai criar contato novo, valida tudo
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

// Debounce helper
const debounce = (func, wait) => {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
};

// Contact search
const performSearch = debounce(async (query) => {
  if (query.length < 2) {
    searchResults.value = [];
    showContactDropdown.value = false;
    return;
  }
  
  isSearching.value = true;
  try {
    const { data } = await ContactAPI.search(query);
    searchResults.value = data.payload || [];
    showContactDropdown.value = searchResults.value.length > 0;
  } catch (error) {
    console.error('Error searching contacts:', error);
    searchResults.value = [];
  } finally {
    isSearching.value = false;
  }
}, 300);

const searchContacts = (query) => {
  performSearch(query);
};

// Select existing contact
const selectContact = (contact) => {
  selectedContact.value = contact;
  searchQuery.value = contact.name;
  showContactDropdown.value = false;
  
  // Preencher campos com dados do contato
  contactName.value = contact.name;
  contactEmail.value = contact.email || '';
  contactPhone.value = contact.phone_number || '';
  companyName.value = contact.additional_attributes?.company_name || '';
  city.value = contact.additional_attributes?.city || '';
  country.value = contact.additional_attributes?.country || '';
  
  // Não mostrar form de criar contato
  showCreateContactForm.value = false;
};

// Create new contact
const createNewContact = () => {
  selectedContact.value = null;
  showCreateContactForm.value = true;
  showContactDropdown.value = false;
  
  // Limpar campos
  contactName.value = searchQuery.value;
  contactEmail.value = '';
  contactPhone.value = '';
  companyName.value = '';
  city.value = '';
  country.value = '';
};

// Clear contact selection
const clearContactSelection = () => {
  selectedContact.value = null;
  searchQuery.value = '';
  showCreateContactForm.value = false;
  searchResults.value = [];
  showContactDropdown.value = false;
  
  // Limpar campos
  contactName.value = '';
  contactEmail.value = '';
  contactPhone.value = '';
  companyName.value = '';
  city.value = '';
  country.value = '';
};

const onCancel = () => {
  resetForm();
  emit('cancel');
};

const resetForm = () => {
  // Reset contact search
  searchQuery.value = '';
  searchResults.value = [];
  selectedContact.value = null;
  isSearching.value = false;
  showCreateContactForm.value = false;
  showContactDropdown.value = false;
  
  // Reset contact fields
  contactName.value = '';
  contactEmail.value = '';
  contactPhone.value = '';
  companyName.value = '';
  city.value = '';
  country.value = '';
  
  // Reset deal fields
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
    if (selectedContact.value) {
      // Criar apenas o deal, usando contato existente
      await DealsAPI.create({
        deal: {
          contact_id: selectedContact.value.id,
          title: dealTitle.value,
          amount: Number(amount.value),
          currency: currency.value,
          close_date: closeDate.value || null,
          notes: notes.value || null,
          pipeline_id: Number(selectedPipelineId.value),
          pipeline_stage_id: Number(selectedStageId.value),
        },
      });
    } else {
      // Criar contato + deal (fluxo atual via LeadsAPI)
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
    }

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
        <!-- NOVA SEÇÃO: Busca de Contato -->
        <div class="mb-4">
          <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ $t('LEADS.CREATE.SELECT_CONTACT') }}
          </h3>
          
          <!-- Campo de busca -->
          <div class="relative">
            <label>
              <span class="block text-sm mb-1">
                {{ $t('LEADS.CREATE.SEARCH_CONTACT') }}
                <span class="text-red-500">*</span>
              </span>
              <div class="relative">
                <input
                  v-model="searchQuery"
                  type="text"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.SEARCH_CONTACT')"
                  :disabled="selectedContact !== null"
                  @input="searchContacts(searchQuery)"
                  @focus="showContactDropdown = searchResults.length > 0"
                />
                <button
                  v-if="selectedContact"
                  type="button"
                  class="absolute right-2 top-1/2 -translate-y-1/2 text-n-slate-10 hover:text-n-slate-12"
                  @click="clearContactSelection"
                >
                  <span class="i-lucide-x size-4" />
                </button>
                <span v-if="isSearching" class="absolute right-2 top-1/2 -translate-y-1/2">
                  <span class="i-lucide-loader-2 size-4 animate-spin text-n-slate-10" />
                </span>
              </div>
            </label>
            
            <!-- Dropdown de resultados -->
            <div
              v-if="showContactDropdown && searchResults.length > 0"
              class="absolute z-10 w-full mt-1 bg-n-solid-1 border border-n-alpha-2 rounded-md shadow-lg max-h-60 overflow-auto"
            >
              <button
                v-for="contact in searchResults"
                :key="contact.id"
                type="button"
                class="w-full px-3 py-2 text-left hover:bg-n-alpha-2 flex items-center gap-2"
                @click="selectContact(contact)"
              >
                <span class="i-lucide-user size-4 text-n-slate-10" />
                <div class="flex-1 min-w-0">
                  <div class="text-sm font-medium text-n-slate-12 truncate">
                    {{ contact.name }}
                  </div>
                  <div class="text-xs text-n-slate-10 truncate">
                    {{ contact.email || contact.phone_number }}
                  </div>
                </div>
              </button>
            </div>
            
            <!-- Opção "Criar novo contato" -->
            <button
              v-if="searchQuery.length >= 2 && !isSearching && searchResults.length === 0 && !selectedContact"
              type="button"
              class="mt-2 text-sm text-n-blue-9 hover:text-n-blue-10 flex items-center gap-1"
              @click="createNewContact"
            >
              <span class="i-lucide-plus size-4" />
              {{ $t('LEADS.CREATE.CREATE_NEW_CONTACT') }}
            </button>
          </div>
        </div>

        <!-- Formulário de contato (só aparece se criar novo) -->
        <div v-if="showCreateContactForm" class="mb-4">
          <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
            {{ $t('LEADS.CREATE.CONTACT_INFO') }}
          </h3>
          <div class="grid grid-cols-2 gap-4">
            <div class="col-span-2">
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.NAME') }}
                  <span v-if="showCreateContactForm" class="text-red-500">*</span>
                </span>
                <input
                  v-model="contactName"
                  type="text"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.NAME')"
                  :required="showCreateContactForm"
                />
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.EMAIL') }}
                  <span v-if="showCreateContactForm" class="text-red-500">*</span>
                </span>
                <input
                  v-model="contactEmail"
                  type="email"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.EMAIL')"
                  :required="showCreateContactForm"
                />
              </label>
            </div>
            <div>
              <label>
                <span class="block text-sm mb-1">
                  {{ $t('LEADS.CREATE.FIELDS.PHONE') }}
                  <span v-if="showCreateContactForm" class="text-red-500">*</span>
                </span>
                <input
                  v-model="contactPhone"
                  type="tel"
                  :placeholder="$t('LEADS.CREATE.PLACEHOLDERS.PHONE')"
                  :required="showCreateContactForm"
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

        <!-- Informações do contato selecionado (readonly) -->
        <div v-else-if="selectedContact" class="mb-4 p-3 bg-n-alpha-1 rounded-md border border-n-alpha-2">
          <h3 class="text-sm font-semibold text-n-slate-12 mb-2">
            {{ $t('LEADS.CREATE.SELECTED_CONTACT') }}
          </h3>
          <div class="text-sm text-n-slate-11 space-y-1">
            <div><strong>Nome:</strong> {{ selectedContact.name }}</div>
            <div v-if="selectedContact.email"><strong>Email:</strong> {{ selectedContact.email }}</div>
            <div v-if="selectedContact.phone_number"><strong>Telefone:</strong> {{ selectedContact.phone_number }}</div>
            <div v-if="selectedContact.additional_attributes?.company_name"><strong>Empresa:</strong> {{ selectedContact.additional_attributes.company_name }}</div>
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

