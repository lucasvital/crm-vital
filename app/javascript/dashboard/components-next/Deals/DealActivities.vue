<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import MessageAPI from 'dashboard/api/inbox/message';
import ConversationApi from 'dashboard/api/inbox/conversation';
import DealActivitiesAPI from 'dashboard/api/dealActivities';
import DealsAPI from 'dashboard/api/deals';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  selectedDeal: {
    type: Object,
    required: true,
  },
  currentStage: {
    type: String,
    default: '',
  },
  pipelineStages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['stage-changed']);

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const getters = useStoreGetters();
const { accountScopedUrl } = useAccount();
const alert = useAlert;

const showConfirmModal = ref(false);
const selectedActivity = ref(null);
const isSending = ref(false);
const sendingProgress = ref('');
const completedActivities = ref([]);
const activities = ref([]);
const loadingActivities = ref(false);
const runningActivities = ref([]); // Atividades em execução em background
const shouldMoveStage = ref(false);
const selectedTargetStage = ref(null);

// Obter o stage_id atual do deal
const currentStageId = computed(() => {
  return props.selectedDeal?.pipeline_stage_id;
});

// Buscar atividades da API
const fetchActivities = async () => {
  if (!currentStageId.value) return;
  
  loadingActivities.value = true;
  try {
    const response = await DealActivitiesAPI.get({
      pipeline_stage_id: currentStageId.value,
    });
    activities.value = response.data || [];
  } catch (error) {
    console.error('Error fetching activities:', error);
  } finally {
    loadingActivities.value = false;
  }
};

const currentActivities = computed(() => {
  return activities.value;
});

const conversationId = computed(() => {
  return props.selectedDeal?._conversationId;
});

const hasConversation = computed(() => {
  return !!conversationId.value;
});

// Obter stages da pipeline atual (excluindo a etapa atual)
const availableStages = computed(() => {
  if (!props.pipelineStages || props.pipelineStages.length === 0) return [];
  return props.pipelineStages.filter(s => s.id !== currentStageId.value);
});

// Substituir variáveis nas mensagens
const replaceVariables = (message, contact) => {
  if (!message || !contact) return message;
  
  let result = message;
  
  // {{nomecompleto}}
  if (contact.name) {
    result = result.replace(/\{\{nomecompleto\}\}/gi, contact.name);
  }
  
  // {{primeironome}}
  if (contact.name) {
    const firstName = contact.name.split(' ')[0];
    result = result.replace(/\{\{primeironome\}\}/gi, firstName);
  }
  
  return result;
};

// Criar conversa para o deal (se não existir)
const createConversationForDeal = async () => {
  const contact = props.selectedDeal.contact;
  if (!contact) {
    throw new Error('Deal não possui contato associado');
  }
  
  // Buscar inboxes disponíveis
  const inboxes = getters['inboxes/getInboxes'].value || [];
  
  // Preferir WhatsApp se disponível, senão usar primeiro inbox
  const whatsappInbox = inboxes.find(i => i.channel_type === 'Channel::Whatsapp');
  const selectedInbox = whatsappInbox || inboxes[0];
  
  if (!selectedInbox) {
    throw new Error('Nenhum inbox disponível');
  }
  
  const isWhatsApp = selectedInbox.channel_type === 'Channel::Whatsapp';
  
  // Para WhatsApp, sourceId deve ser o número de telefone (apenas dígitos)
  let sourceId = `contact-${contact.id}-${Date.now()}`;
  if (isWhatsApp && contact.phone_number) {
    sourceId = contact.phone_number.replace(/\D/g, '');
  }
  
  const params = {
    inboxId: selectedInbox.id,
    contactId: contact.id,
    message: {
      content: ' ', // Mensagem inicial vazia (será enviada a primeira mensagem da atividade)
    },
    sourceId,
  };
  
  const response = await store.dispatch('contactConversations/create', {
    params,
    isFromWhatsApp: isWhatsApp,
  });
  
  return response.id;
};

// Carregar atividades completadas dos custom attributes
const loadCompletedActivities = () => {
  const ca = props.selectedDeal?.custom_attributes || {};
  const completed = ca.completed_activities || [];
  completedActivities.value = Array.isArray(completed) ? completed : [];
};

// Verificar se uma atividade já foi completada
const isActivityCompleted = activityId => {
  return completedActivities.value.some(a => a.id === activityId);
};

// Obter informação de quando foi completada
const getCompletedInfo = activityId => {
  return completedActivities.value.find(a => a.id === activityId);
};

// Formatar data/hora
const formatDateTime = dateTimeStr => {
  if (!dateTimeStr) return '';
  try {
    const date = new Date(dateTimeStr);
    return new Intl.DateTimeFormat('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  } catch (_) {
    return dateTimeStr;
  }
};

// Watch para recarregar atividades quando o stage mudar
watch(
  () => [props.selectedDeal, currentStageId.value],
  () => {
    loadCompletedActivities();
    fetchActivities();
  },
  { immediate: true }
);

const openConfirmModal = activity => {
  selectedActivity.value = activity;
  showConfirmModal.value = true;
};

const closeConfirmModal = () => {
  showConfirmModal.value = false;
  selectedActivity.value = null;
  sendingProgress.value = '';
  shouldMoveStage.value = false;
  selectedTargetStage.value = null;
};

// Executar atividade em background
const executeActivityInBackground = async (activity, dealContact, currentConvId, shouldMoveToStage = false, targetStageId = null) => {
  const activityId = activity.id;
  let conversationWasCreated = false;
  
  try {
    // 1. Verificar/criar conversa
    let conversationIdToUse = currentConvId;
    
    if (!conversationIdToUse) {
      conversationIdToUse = await createConversationForDeal();
      conversationWasCreated = true;
      
      // Associar conversa ao deal
      await DealsAPI.update(props.selectedDeal.id, {
        deal: { conversation_id: conversationIdToUse }
      });
    }
    
    // 2. Processar cada mensagem sequencialmente
    const messages = activity.messages || [];
    
    for (const [index, msg] of messages.entries()) {
      // Substituir variáveis
      const content = replaceVariables(msg.content, dealContact);
      
      // Enviar mensagem
      await MessageAPI.create({
        conversationId: conversationIdToUse,
        message: content,
        private: false,
      });
      
      // Delay aleatório (exceto última mensagem)
      if (index < messages.length - 1) {
        const delay = Math.floor(Math.random() * 10000); // 0-10 segundos
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
    
    // 3. Marcar atividade como completada
    const completedActivity = {
      id: activity.id,
      title: activity.title,
      completedAt: new Date().toISOString(),
    };
    
    // Atualizar lista local
    const existingIndex = completedActivities.value.findIndex(
      a => a.id === activity.id
    );
    if (existingIndex >= 0) {
      completedActivities.value[existingIndex] = completedActivity;
    } else {
      completedActivities.value.push(completedActivity);
    }
    
    // Salvar no backend (custom attributes)
    const ca = props.selectedDeal?.custom_attributes || {};
    await ConversationApi.updateCustomAttributes({
      conversationId: conversationIdToUse,
      customAttributes: {
        ...ca,
        completed_activities: completedActivities.value,
      },
    });
    
    // 4. Mover para nova etapa se solicitado
    if (shouldMoveToStage && targetStageId) {
      try {
        const stageIdNumber = Number(targetStageId);
        if (isNaN(stageIdNumber)) {
          console.error('ID da etapa inválido:', targetStageId);
          useAlert('ID da etapa inválido');
          return;
        }
        
        console.log('=== MOVENDO ETAPA ===');
        console.log('Deal ID:', props.selectedDeal.id);
        console.log('Target Stage ID:', stageIdNumber);
        
        await DealsAPI.update(props.selectedDeal.id, {
          deal: { pipeline_stage_id: stageIdNumber }
        });
        
        useAlert(t('DEAL_ACTIVITIES.ALERTS.STAGE_MOVED'));
        
        // Emitir evento para atualizar a UI (ex.: recarregar Kanban)
        emit('stage-changed', { dealId: props.selectedDeal.id, newStageId: stageIdNumber });
      } catch (stageError) {
        console.error('=== ERRO AO MOVER ETAPA ===');
        console.error('Erro completo:', stageError);
        console.error('Response:', stageError.response?.data);
        console.error('Status:', stageError.response?.status);
        console.error('Deal ID:', props.selectedDeal.id);
        console.error('Target Stage ID:', targetStageId);
        useAlert(t('DEAL_ACTIVITIES.ALERTS.STAGE_MOVE_FAILED') + ': ' + (stageError.response?.data?.error || stageError.message));
      }
    }
    
    // Notificação de sucesso
    useAlert(t('DEAL_ACTIVITIES.ALERTS.ACTIVITY_COMPLETED_BACKGROUND', { title: activity.title }));
    
    // Redirecionar para a conversa se foi criada
    if (conversationWasCreated && conversationIdToUse) {
      router.push(accountScopedUrl(`conversations/${conversationIdToUse}`));
    }
  } catch (error) {
    console.error('Error executing activity in background:', error);
    useAlert(
      t('DEAL_ACTIVITIES.ALERTS.ACTIVITY_FAILED_BACKGROUND', { title: activity.title })
    );
  } finally {
    // Remover da lista de atividades em execução
    const index = runningActivities.value.findIndex(a => a.id === activityId);
    if (index >= 0) {
      runningActivities.value.splice(index, 1);
    }
  }
};

// Executar atividade (processar mensagens sequenciais)
const executeActivity = () => {
  if (!selectedActivity.value) return;
  
  const activity = { ...selectedActivity.value };
  const contact = props.selectedDeal.contact || {};
  const currentConvId = conversationId.value;
  const moveStage = shouldMoveStage.value;
  const targetStage = selectedTargetStage.value;
  
  // Adicionar à lista de atividades em execução
  runningActivities.value.push({
    id: activity.id,
    title: activity.title,
  });
  
  // Fechar modal imediatamente
  closeConfirmModal();
  
  // Mostrar notificação de início
  useAlert(t('DEAL_ACTIVITIES.ALERTS.ACTIVITY_STARTED', { title: activity.title }));
  
  // Executar em background (não aguardar)
  executeActivityInBackground(activity, contact, currentConvId, moveStage, targetStage);
};

onMounted(() => {
  fetchActivities();
});
</script>

<template>
  <div class="px-6 py-4">
    <!-- Indicador de atividades em execução -->
    <div
      v-if="runningActivities.length > 0"
      class="mb-4 rounded-lg bg-n-amber-2 border border-n-amber-6 p-3"
    >
      <div class="flex items-center gap-2">
        <woot-spinner size="small" />
        <div class="flex-1">
          <p class="text-xs font-medium text-n-amber-11">
            {{ runningActivities.length === 1 
              ? $t('DEAL_ACTIVITIES.RUNNING_SINGLE', { title: runningActivities[0].title })
              : $t('DEAL_ACTIVITIES.RUNNING_MULTIPLE', { count: runningActivities.length })
            }}
          </p>
        </div>
      </div>
    </div>
    
    <!-- Alerta informativo sobre criar conversa -->
    <div
      v-if="!hasConversation"
      class="mb-4 rounded-lg bg-n-blue-2 border border-n-blue-6 p-4"
    >
      <div class="flex items-start gap-3">
        <span class="i-lucide-info size-5 text-n-blue-11 flex-shrink-0 mt-0.5" />
        <div>
          <h3 class="text-sm font-medium text-n-blue-12 mb-1">
            {{ $t('DEAL_ACTIVITIES.NO_CONVERSATION_TITLE_NEW') }}
          </h3>
          <p class="text-xs text-n-blue-11">
            {{ $t('DEAL_ACTIVITIES.NO_CONVERSATION_DESC_NEW') }}
          </p>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loadingActivities" class="flex items-center justify-center py-8">
      <woot-spinner size="medium" />
    </div>

    <!-- Lista de atividades -->
    <div v-else-if="currentActivities.length > 0" class="space-y-3">
      <h3 class="text-sm font-semibold text-n-slate-12 mb-3">
        {{ $t('DEAL_ACTIVITIES.TITLE') }}
      </h3>
      <div
        v-for="activity in currentActivities"
        :key="activity.id"
        class="rounded-lg bg-n-solid-1 p-4 ring-1 transition-all"
        :class="isActivityCompleted(activity.id) ? 'ring-n-green-6 bg-n-green-1' : 'ring-n-alpha-2 hover:ring-n-strong'"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-1">
              <h4 class="text-sm font-medium text-n-slate-12">
                {{ activity.title }}
              </h4>
              <span
                v-if="isActivityCompleted(activity.id)"
                class="inline-flex items-center gap-1 rounded-full bg-n-green-3 px-2 py-0.5 text-[10px] font-medium text-n-green-11"
              >
                <span class="i-lucide-check size-3" />
                {{ $t('DEAL_ACTIVITIES.COMPLETED') }}
              </span>
              <span
                v-if="activity.messages?.length > 1"
                class="inline-flex items-center gap-1 rounded-full bg-n-alpha-2 px-2 py-0.5 text-[10px] text-n-slate-11"
                :title="$t('DEAL_ACTIVITIES.SEQUENTIAL_MESSAGES')"
              >
                <span class="i-lucide-layers size-3" />
                {{ activity.messages.length }}
              </span>
            </div>
            <p class="text-xs text-n-slate-11 mb-1">
              {{ activity.description }}
            </p>
            <p
              v-if="isActivityCompleted(activity.id)"
              class="text-[11px] text-n-slate-10"
            >
              {{ $t('DEAL_ACTIVITIES.COMPLETED_AT') }}: {{ formatDateTime(getCompletedInfo(activity.id)?.completedAt) }}
            </p>
          </div>
          <Button
            sm
            :label="isActivityCompleted(activity.id) ? $t('DEAL_ACTIVITIES.EXECUTE_AGAIN') : $t('DEAL_ACTIVITIES.EXECUTE')"
            @click="openConfirmModal(activity)"
          />
        </div>
      </div>
    </div>

    <!-- Mensagem quando não há atividades -->
    <div
      v-else
      class="rounded-lg border border-dashed border-n-border bg-n-solid-1 p-8 text-center"
    >
      <span class="i-lucide-inbox size-12 text-n-slate-11 mx-auto mb-3" />
      <p class="text-sm text-n-slate-11">
        {{ $t('DEAL_ACTIVITIES.NO_ACTIVITIES') }}
      </p>
    </div>

    <!-- Modal de confirmação -->
    <woot-modal v-if="showConfirmModal" :show="showConfirmModal" :on-close="closeConfirmModal">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('DEAL_ACTIVITIES.CONFIRM_MODAL.TITLE')"
          :header-content="selectedActivity?.title"
        />
        <div class="px-8 py-6">
          <!-- Descrição -->
          <p class="text-sm text-n-slate-11 mb-4">
            {{ selectedActivity?.description }}
          </p>

          <!-- Preview das mensagens -->
          <div class="mb-4">
            <label class="text-sm font-medium text-n-slate-12 block mb-2">
              {{ $t('DEAL_ACTIVITIES.CONFIRM_MODAL.MESSAGES_PREVIEW') }}
            </label>
            <div class="space-y-2">
              <div
                v-for="(msg, index) in selectedActivity?.messages || []"
                :key="index"
                class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3"
              >
                <div class="flex items-start gap-2 mb-1">
                  <span
                    class="inline-flex items-center justify-center size-5 rounded-full bg-n-brand text-white text-[10px] font-medium flex-shrink-0"
                  >
                    {{ index + 1 }}
                  </span>
                  <p class="text-xs text-n-slate-12 flex-1">
                    {{ msg.content }}
                  </p>
                </div>
                <div
                  v-if="index < (selectedActivity?.messages?.length || 0) - 1"
                  class="flex items-center gap-1 text-[10px] text-n-slate-10 mt-2 ml-7"
                >
                  <span class="i-lucide-timer size-3" />
                  {{ $t('DEAL_ACTIVITIES.CONFIRM_MODAL.DELAY_INFO') }}
                </div>
              </div>
            </div>
          </div>

          <!-- Info -->
          <div class="rounded-lg bg-n-blue-2 border border-n-blue-6 p-3 mb-4">
            <div class="flex items-start gap-2">
              <span class="i-lucide-info size-4 text-n-blue-11 flex-shrink-0 mt-0.5" />
              <div class="text-xs text-n-blue-11">
                <p class="mb-1">
                  {{ $t('DEAL_ACTIVITIES.CONFIRM_MODAL.INFO') }}
                </p>
                <p v-if="!hasConversation" class="font-medium">
                  {{ $t('DEAL_ACTIVITIES.CONFIRM_MODAL.WILL_CREATE_CONVERSATION') }}
                </p>
              </div>
            </div>
          </div>

          <!-- Opções adicionais -->
          <div v-if="availableStages.length > 0" class="mt-4 pt-4 border-t border-n-alpha-2">
            <label class="flex items-center gap-2 mb-3 cursor-pointer">
              <input
                type="checkbox"
                v-model="shouldMoveStage"
                class="form-checkbox h-4 w-4 rounded border-n-alpha-3 text-n-brand focus:ring-n-brand focus:ring-offset-0"
              />
              <span class="text-sm text-n-slate-12">
                {{ $t('DEAL_ACTIVITIES.CONFIRM_MODAL.MOVE_STAGE_AFTER') }}
              </span>
            </label>
            
            <div v-if="shouldMoveStage" class="ml-6">
              <label class="block text-xs text-n-slate-11 mb-2">
                {{ $t('DEAL_ACTIVITIES.CONFIRM_MODAL.SELECT_TARGET_STAGE') }}
              </label>
              <select
                v-model="selectedTargetStage"
                class="w-full rounded-md border border-n-alpha-3 bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 focus:border-n-brand focus:ring-1 focus:ring-n-brand"
              >
                <option :value="null">{{ $t('DEAL_ACTIVITIES.CONFIRM_MODAL.SELECT_STAGE') }}</option>
                <option
                  v-for="stage in availableStages"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </select>
            </div>
          </div>

        </div>
        <div class="flex flex-row justify-end w-full gap-2 px-8 py-4 border-t border-n-weak">
          <Button
            faded
            slate
            type="button"
            :label="$t('DEAL_ACTIVITIES.CONFIRM_MODAL.CANCEL')"
            @click="closeConfirmModal"
          />
          <Button
            type="button"
            :label="$t('DEAL_ACTIVITIES.CONFIRM_MODAL.EXECUTE')"
            @click="executeActivity"
          />
        </div>
      </div>
    </woot-modal>
  </div>
</template>

