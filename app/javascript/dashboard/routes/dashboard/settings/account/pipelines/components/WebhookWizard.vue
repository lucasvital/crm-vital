<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PipelineWebhooksAPI from 'dashboard/api/pipelineWebhooks';
import AttributeAPI from 'dashboard/api/attributes';

const props = defineProps({
  pipeline: {
    type: Object,
    required: true,
  },
  webhook: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const alert = useAlert;

// Estado do wizard
const currentStep = ref(1);
const isSubmitting = ref(false);
const savedWebhook = ref(null);

// Passo 1: Informações Básicas
const webhookName = ref(props.webhook?.name || '');
const selectedStageId = ref(props.webhook?.pipeline_stage_id || null);
const isActive = ref(props.webhook?.active ?? true);

// Passo 2: Tags
const tagInput = ref('');
const selectedTags = ref(props.webhook?.tag_config?.labels || []);

// Passo 3: Mapeamento de Campos
const fieldMapping = ref({
  name: props.webhook?.field_mapping?.name || '',
  email: props.webhook?.field_mapping?.email || '',
  phone_number: props.webhook?.field_mapping?.phone_number || '',
  company_name: props.webhook?.field_mapping?.company_name || '',
  city: props.webhook?.field_mapping?.city || '',
  country: props.webhook?.field_mapping?.country || '',
  title: props.webhook?.field_mapping?.title || '',
  amount: props.webhook?.field_mapping?.amount || '',
  close_date: props.webhook?.field_mapping?.close_date || '',
  notes: props.webhook?.field_mapping?.notes || '',
});

// Atributos Personalizados
const availableCustomAttributes = ref([]);
const customAttributeMapping = ref([]);
const isLoadingAttributes = ref(false);

const stages = computed(() => {
  return props.pipeline?.pipeline_stages || [];
});

const isStep1Valid = computed(() => {
  return webhookName.value.trim() !== '' && selectedStageId.value !== null;
});

const isEditMode = computed(() => !!props.webhook);

const systemFields = [
  { key: 'name', label: 'Nome do Contato', required: true },
  { key: 'email', label: 'Email', required: false },
  { key: 'phone_number', label: 'Telefone', required: false },
  { key: 'company_name', label: 'Empresa', required: false },
  { key: 'city', label: 'Cidade', required: false },
  { key: 'country', label: 'País', required: false },
  { key: 'title', label: 'Título do Negócio', required: false },
  { key: 'amount', label: 'Valor', required: false },
  { key: 'close_date', label: 'Data de Fechamento', required: false },
  { key: 'notes', label: 'Observações', required: false },
];

const examplePayload = computed(() => {
  const obj = {};
  
  // Adicionar campos do sistema
  Object.entries(fieldMapping.value).forEach(([key, value]) => {
    if (value) {
      const keys = value.split('.');
      let current = obj;
      keys.forEach((k, i) => {
        if (i === keys.length - 1) {
          current[k] = `<valor_${key}>`;
        } else {
          current[k] = current[k] || {};
          current = current[k];
        }
      });
    }
  });
  
  // Adicionar campos personalizados
  customAttributeMapping.value.forEach(mapping => {
    if (mapping.attributeKey && mapping.mappingPath) {
      const keys = mapping.mappingPath.split('.');
      let current = obj;
      keys.forEach((k, i) => {
        if (i === keys.length - 1) {
          current[k] = `<valor_${mapping.attributeKey}>`;
        } else {
          current[k] = current[k] || {};
          current = current[k];
        }
      });
    }
  });
  
  return obj;
});

const nextStep = () => {
  if (currentStep.value === 1 && !isStep1Valid.value) {
    alert('Preencha todos os campos obrigatórios');
    return;
  }
  if (currentStep.value < 3) {
    currentStep.value++;
  }
};

const prevStep = () => {
  if (currentStep.value > 1) {
    currentStep.value--;
  }
};

const addTag = () => {
  const tag = tagInput.value.trim();
  if (tag && !selectedTags.value.includes(tag)) {
    selectedTags.value.push(tag);
    tagInput.value = '';
  }
};

const removeTag = tag => {
  selectedTags.value = selectedTags.value.filter(t => t !== tag);
};

const handleTagInputKeydown = e => {
  if (e.key === 'Enter') {
    e.preventDefault();
    addTag();
  }
};

const saveWebhook = async () => {
  if (!isStep1Valid.value) {
    alert('Preencha todos os campos obrigatórios');
    return;
  }

  // Validar que todos os campos personalizados estão preenchidos
  const hasInvalidCustomAttributes = customAttributeMapping.value.some(
    mapping => !mapping.attributeKey || !mapping.mappingPath
  );
  
  if (hasInvalidCustomAttributes) {
    alert('Preencha todos os campos personalizados ou remova-os');
    return;
  }

  isSubmitting.value = true;

  try {
    // Montar field_mapping com campos do sistema e personalizados
    const customAttributes = {};
    customAttributeMapping.value.forEach(mapping => {
      if (mapping.attributeKey && mapping.mappingPath) {
        customAttributes[mapping.attributeKey] = mapping.mappingPath;
      }
    });

    const finalFieldMapping = {
      ...fieldMapping.value,
    };

    // Adicionar custom_attributes apenas se houver algum
    if (Object.keys(customAttributes).length > 0) {
      finalFieldMapping.custom_attributes = customAttributes;
    }

    const payload = {
      name: webhookName.value,
      pipeline_stage_id: selectedStageId.value,
      active: isActive.value,
      field_mapping: finalFieldMapping,
      tag_config: {
        labels: selectedTags.value,
      },
    };

    let response;
    if (isEditMode.value) {
      response = await PipelineWebhooksAPI.update(
        props.pipeline.id,
        props.webhook.id,
        payload
      );
    } else {
      response = await PipelineWebhooksAPI.create(props.pipeline.id, payload);
    }

    savedWebhook.value = response.data;
    currentStep.value = 4; // Ir para tela de sucesso
    emit('saved', response.data);
  } catch (error) {
    const errorMessage =
      error.response?.data?.errors?.join(', ') || 'Erro ao salvar webhook';
    alert(errorMessage);
  } finally {
    isSubmitting.value = false;
  }
};

const copyToClipboard = text => {
  navigator.clipboard.writeText(text).then(() => {
    alert('URL copiada para a área de transferência!');
  });
};

const close = () => {
  emit('close');
};

// Carregar atributos personalizados de contato
const loadCustomAttributes = async () => {
  isLoadingAttributes.value = true;
  try {
    const response = await AttributeAPI.getAttributesByModel();
    // Filtrar apenas atributos de contato
    availableCustomAttributes.value = (response.data || []).filter(
      attr => attr.attribute_model === 1 // 1 = contact_attribute
    );
    
    // Se estiver editando, carregar atributos personalizados salvos
    if (props.webhook?.field_mapping?.custom_attributes) {
      const savedCustomAttrs = props.webhook.field_mapping.custom_attributes;
      customAttributeMapping.value = Object.entries(savedCustomAttrs).map(
        ([key, value]) => ({
          attributeKey: key,
          mappingPath: value,
        })
      );
    }
  } catch (error) {
    console.error('Erro ao carregar atributos personalizados:', error);
  } finally {
    isLoadingAttributes.value = false;
  }
};

// Funções para gerenciar campos personalizados
const addCustomAttributeField = () => {
  customAttributeMapping.value.push({
    attributeKey: '',
    mappingPath: '',
  });
};

const removeCustomAttributeField = index => {
  customAttributeMapping.value.splice(index, 1);
};

// Computed para filtrar atributos já selecionados
const getAvailableAttributesForIndex = index => {
  const selectedKeys = customAttributeMapping.value
    .map((m, i) => (i !== index ? m.attributeKey : null))
    .filter(Boolean);
  
  return availableCustomAttributes.value.filter(
    attr => !selectedKeys.includes(attr.attribute_key)
  );
};

onMounted(() => {
  loadCustomAttributes();
});
</script>

<template>
  <div class="flex flex-col h-auto">
    <woot-modal-header
      :header-title="
        isEditMode ? 'Editar Integração Webhook' : 'Nova Integração Webhook'
      "
    />

    <!-- Indicador de passos -->
    <div
      v-if="currentStep < 4"
      class="flex items-center justify-center gap-2 px-6 py-4 border-b border-n-alpha-2"
    >
      <div
        v-for="step in 3"
        :key="step"
        class="flex items-center"
      >
        <div
          class="flex items-center justify-center w-8 h-8 rounded-full text-sm font-medium"
          :class="
            step === currentStep
              ? 'bg-n-brand text-white'
              : step < currentStep
              ? 'bg-n-grass-9 text-white'
              : 'bg-n-solid-3 text-n-slate-11'
          "
        >
          <span v-if="step < currentStep" class="i-lucide-check size-4" />
          <span v-else>{{ step }}</span>
        </div>
        <div
          v-if="step < 3"
          class="w-12 h-0.5 mx-2"
          :class="step < currentStep ? 'bg-n-grass-9' : 'bg-n-solid-3'"
        />
      </div>
    </div>

    <!-- Conteúdo dos passos -->
    <div class="px-6 py-4 space-y-4 max-h-[500px] overflow-y-auto">
      <!-- Passo 1: Informações Básicas -->
      <div v-if="currentStep === 1" class="space-y-4">
        <h3 class="text-lg font-semibold text-n-slate-12">
          Informações Básicas
        </h3>

        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-1">
            Nome da Integração *
          </label>
          <input
            v-model="webhookName"
            type="text"
            class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
            placeholder="Ex: RD Station, Facebook Ads, etc."
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-1">
            Etapa Inicial *
          </label>
          <select
            v-model="selectedStageId"
            class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
          >
            <option :value="null" disabled>Selecione uma etapa</option>
            <option
              v-for="stage in stages"
              :key="stage.id"
              :value="stage.id"
            >
              {{ stage.name }}
            </option>
          </select>
          <p class="text-xs text-n-slate-11 mt-1">
            Os leads recebidos serão criados nesta etapa
          </p>
        </div>

        <div class="flex items-center gap-2">
          <input
            id="active-checkbox"
            v-model="isActive"
            type="checkbox"
            class="rounded border-n-alpha-2"
          />
          <label for="active-checkbox" class="text-sm text-n-slate-12">
            Webhook ativo
          </label>
        </div>
      </div>

      <!-- Passo 2: Tags -->
      <div v-if="currentStep === 2" class="space-y-4">
        <h3 class="text-lg font-semibold text-n-slate-12">Tags</h3>

        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-1">
            Adicionar Tags
          </label>
          <div class="flex gap-2">
            <input
              v-model="tagInput"
              type="text"
              class="flex-1 rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              placeholder="Digite uma tag e pressione Enter"
              @keydown="handleTagInputKeydown"
            />
            <button
              type="button"
              class="rounded-md border border-n-strong bg-n-solid-1 px-4 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-solid-2"
              @click="addTag"
            >
              Adicionar
            </button>
          </div>
          <p class="text-xs text-n-slate-11 mt-1">
            Tags serão aplicadas automaticamente aos leads recebidos
          </p>
        </div>

        <div v-if="selectedTags.length > 0" class="space-y-2">
          <label class="block text-sm font-medium text-n-slate-12">
            Tags Selecionadas
          </label>
          <div class="flex flex-wrap gap-2">
            <span
              v-for="tag in selectedTags"
              :key="tag"
              class="inline-flex items-center gap-1 rounded-md border border-n-alpha-2 bg-n-solid-2 px-2 py-1 text-sm"
            >
              {{ tag }}
              <button
                type="button"
                class="text-n-ruby-11 hover:text-n-ruby-12"
                @click="removeTag(tag)"
              >
                <span class="i-lucide-x size-3" />
              </button>
            </span>
          </div>
        </div>
      </div>

      <!-- Passo 3: Mapeamento de Campos -->
      <div v-if="currentStep === 3" class="space-y-4">
        <h3 class="text-lg font-semibold text-n-slate-12">
          Mapeamento de Campos
        </h3>

        <p class="text-sm text-n-slate-11">
          Configure como os campos do webhook serão mapeados para os campos do
          sistema. Use notação de ponto para campos aninhados (ex: lead.name,
          data.email).
        </p>

        <div class="space-y-3">
          <div
            v-for="field in systemFields"
            :key="field.key"
            class="grid grid-cols-2 gap-3 items-center"
          >
            <label class="text-sm font-medium text-n-slate-12">
              {{ field.label }}
              <span v-if="field.required" class="text-n-ruby-11">*</span>
            </label>
            <input
              v-model="fieldMapping[field.key]"
              type="text"
              class="rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              :placeholder="`Ex: ${field.key}`"
            />
          </div>
        </div>

        <!-- Separador -->
        <div class="flex items-center gap-3 my-4">
          <div class="flex-1 h-px bg-n-alpha-2" />
          <span class="text-xs font-medium text-n-slate-11">Campos Personalizados</span>
          <div class="flex-1 h-px bg-n-alpha-2" />
        </div>

        <!-- Campos Personalizados -->
        <div class="space-y-3">
          <div
            v-for="(mapping, index) in customAttributeMapping"
            :key="index"
            class="grid grid-cols-[1fr,1fr,auto] gap-2 items-start"
          >
            <div>
              <select
                v-model="mapping.attributeKey"
                class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              >
                <option value="" disabled>Selecione um atributo</option>
                <option
                  v-for="attr in getAvailableAttributesForIndex(index)"
                  :key="attr.attribute_key"
                  :value="attr.attribute_key"
                >
                  {{ attr.attribute_display_name }}
                </option>
              </select>
            </div>
            <div>
              <input
                v-model="mapping.mappingPath"
                type="text"
                class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
                placeholder="Ex: custom.campo"
              />
            </div>
            <button
              type="button"
              class="rounded-md border border-n-strong bg-n-solid-1 p-2 text-n-ruby-11 hover:bg-n-ruby-3"
              @click="removeCustomAttributeField(index)"
            >
              <span class="i-lucide-x size-4" />
            </button>
          </div>

          <button
            type="button"
            class="w-full rounded-md border border-dashed border-n-alpha-2 bg-n-solid-1 px-4 py-2 text-sm font-medium text-n-slate-11 hover:bg-n-solid-2 hover:text-n-slate-12 hover:border-n-alpha-3 transition-colors"
            @click="addCustomAttributeField"
          >
            <span class="i-lucide-plus size-4 inline-block mr-1" />
            Adicionar Campo Personalizado
          </button>
        </div>

        <div class="mt-4 p-3 rounded-md bg-n-solid-2 border border-n-alpha-2">
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            Exemplo de Payload JSON
          </label>
          <pre
            class="text-xs text-n-slate-11 overflow-auto max-h-40"
          >{{ JSON.stringify(examplePayload, null, 2) }}</pre>
        </div>
      </div>

      <!-- Passo 4: Sucesso -->
      <div v-if="currentStep === 4" class="space-y-4">
        <div class="flex items-center justify-center mb-4">
          <div
            class="flex items-center justify-center w-16 h-16 rounded-full bg-n-grass-3"
          >
            <span class="i-lucide-check size-8 text-n-grass-11" />
          </div>
        </div>

        <h3 class="text-lg font-semibold text-n-slate-12 text-center">
          Webhook Criado com Sucesso!
        </h3>

        <div class="space-y-3">
          <div>
            <label class="block text-sm font-medium text-n-slate-12 mb-2">
              URL do Webhook
            </label>
            <div class="space-y-2">
              <code
                class="block text-xs bg-n-solid-2 border border-n-alpha-2 rounded px-3 py-2 break-all"
              >
                {{ savedWebhook?.full_webhook_url }}
              </code>
              <button
                type="button"
                class="w-full rounded-md border border-n-strong bg-n-solid-1 px-4 py-2 text-sm font-medium text-n-blue-11 hover:bg-n-blue-3"
                @click="copyToClipboard(savedWebhook?.full_webhook_url)"
              >
                <span class="i-lucide-copy size-4 inline-block mr-1" />
                Copiar URL
              </button>
            </div>
          </div>

          <div
            class="p-3 rounded-md bg-n-blue-3 border border-n-blue-8 text-sm text-n-slate-12"
          >
            <p class="font-medium mb-1">Como usar:</p>
            <ol class="list-decimal list-inside space-y-1 text-xs">
              <li>Copie a URL acima</li>
              <li>Configure no seu sistema de origem (RD Station, etc.)</li>
              <li>Os leads serão criados automaticamente no CRM</li>
            </ol>
          </div>
        </div>
      </div>
    </div>

    <!-- Botões de navegação -->
    <div class="flex justify-end gap-2 px-6 pb-4 border-t border-n-alpha-2">
      <button
        v-if="currentStep > 1 && currentStep < 4"
        type="button"
        class="rounded-md border border-n-weak bg-n-solid-1 px-4 py-2 text-sm text-n-slate-12 hover:bg-n-solid-2"
        @click="prevStep"
      >
        Voltar
      </button>

      <button
        v-if="currentStep === 4"
        type="button"
        class="rounded-md border border-n-strong bg-n-solid-1 px-4 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-solid-2"
        @click="close"
      >
        Fechar
      </button>

      <button
        v-if="currentStep < 3"
        type="button"
        class="rounded-md border border-n-strong bg-n-brand px-4 py-2 text-sm font-medium text-white hover:brightness-110"
        :disabled="!isStep1Valid && currentStep === 1"
        @click="nextStep"
      >
        Próximo
      </button>

      <button
        v-if="currentStep === 3"
        type="button"
        class="rounded-md border border-n-strong bg-n-brand px-4 py-2 text-sm font-medium text-white hover:brightness-110"
        :disabled="isSubmitting"
        @click="saveWebhook"
      >
        {{ isSubmitting ? 'Salvando...' : 'Salvar' }}
      </button>
    </div>
  </div>
</template>

