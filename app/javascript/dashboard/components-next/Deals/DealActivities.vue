<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import MessageAPI from 'dashboard/api/inbox/message';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { useAlert } from 'dashboard/composables';
import { watch } from 'vue';

const props = defineProps({
  selectedDeal: {
    type: Object,
    required: true,
  },
  currentStage: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const alert = useAlert;

const showConfirmModal = ref(false);
const selectedActivity = ref(null);
const isSending = ref(false);
const editableMessage = ref('');
const completedActivities = ref([]);

// Definir atividades padrão para cada etapa do pipeline
const stageActivities = {
  base: [
    {
      id: 'base_greeting',
      title: 'Enviar mensagem de saudação',
      description: 'Envie uma mensagem inicial de boas-vindas ao lead',
      messageTemplate: 'Olá! 👋 Obrigado por entrar em contato conosco. Como posso ajudá-lo hoje?',
    },
    {
      id: 'base_qualify',
      title: 'Qualificar lead',
      description: 'Envie perguntas para entender melhor as necessidades',
      messageTemplate: 'Para que eu possa te ajudar da melhor forma, pode me contar um pouco mais sobre o que você está procurando?',
    },
  ],
  prospeccao: [
    {
      id: 'prospeccao_intro',
      title: 'Apresentar produtos/serviços',
      description: 'Apresente seus produtos ou serviços ao lead',
      messageTemplate: 'Temos soluções que podem te ajudar! Deixa eu te mostrar o que podemos oferecer...',
    },
    {
      id: 'prospeccao_followup',
      title: 'Follow-up inicial',
      description: 'Acompanhe o interesse do lead',
      messageTemplate: 'Olá! Gostaria de saber se você teve chance de pensar sobre nossa conversa anterior? 😊',
    },
  ],
  conexao: [
    {
      id: 'conexao_schedule',
      title: 'Agendar reunião',
      description: 'Convide para uma conversa mais detalhada',
      messageTemplate: 'Que tal agendarmos uma conversa mais detalhada? Quando seria um bom horário para você?',
    },
    {
      id: 'conexao_demo',
      title: 'Oferecer demonstração',
      description: 'Ofereça uma demonstração do produto/serviço',
      messageTemplate: 'Posso te mostrar como nossa solução funciona na prática! Que tal uma demonstração rápida?',
    },
  ],
  possibilidade: [
    {
      id: 'possibilidade_proposal',
      title: 'Enviar proposta',
      description: 'Envie uma proposta comercial',
      messageTemplate: 'Preparei uma proposta personalizada para você! Vou enviar os detalhes agora...',
    },
    {
      id: 'possibilidade_answer',
      title: 'Responder dúvidas',
      description: 'Esclareça dúvidas sobre a proposta',
      messageTemplate: 'Tem alguma dúvida sobre a proposta que enviei? Estou aqui para esclarecer tudo! 😊',
    },
  ],
  possibilidade_quente: [
    {
      id: 'quente_negotiate',
      title: 'Negociar condições',
      description: 'Discuta condições comerciais',
      messageTemplate: 'Vamos conversar sobre as condições? Podemos encontrar o melhor formato para você!',
    },
    {
      id: 'quente_urgency',
      title: 'Criar senso de urgência',
      description: 'Incentive o fechamento',
      messageTemplate: 'Temos uma condição especial válida até o final desta semana! Seria um ótimo momento para fecharmos. 🎯',
    },
  ],
  aguardando_compra: [
    {
      id: 'aguardando_confirm',
      title: 'Confirmar interesse',
      description: 'Confirme o interesse em finalizar',
      messageTemplate: 'Tudo pronto para finalizarmos? Se tiver alguma última dúvida, estou à disposição!',
    },
    {
      id: 'aguardando_docs',
      title: 'Solicitar documentos',
      description: 'Solicite documentação necessária',
      messageTemplate: 'Para finalizar, vou precisar de alguns documentos. Pode me enviar [listar documentos]?',
    },
  ],
  ganho: [
    {
      id: 'ganho_welcome',
      title: 'Mensagem de boas-vindas',
      description: 'Agradeça e dê boas-vindas ao cliente',
      messageTemplate: '🎉 Seja bem-vindo! Estamos muito felizes em tê-lo conosco. Vamos começar?',
    },
    {
      id: 'ganho_onboarding',
      title: 'Iniciar onboarding',
      description: 'Inicie o processo de onboarding',
      messageTemplate: 'Vou te guiar nos primeiros passos para você aproveitar ao máximo nossa solução!',
    },
  ],
};

const currentActivities = computed(() => {
  return stageActivities[props.currentStage] || [];
});

const conversationId = computed(() => {
  return props.selectedDeal?._conversationId;
});

const hasConversation = computed(() => {
  return !!conversationId.value;
});

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

// Watch para carregar atividades quando o deal mudar
watch(
  () => props.selectedDeal,
  () => {
    loadCompletedActivities();
  },
  { immediate: true }
);

const openConfirmModal = activity => {
  selectedActivity.value = activity;
  editableMessage.value = activity.messageTemplate;
  showConfirmModal.value = true;
};

const closeConfirmModal = () => {
  showConfirmModal.value = false;
  selectedActivity.value = null;
  editableMessage.value = '';
};

const sendMessage = async () => {
  if (!editableMessage.value.trim() || !conversationId.value) return;

  try {
    isSending.value = true;
    
    // Enviar mensagem
    await MessageAPI.create({
      conversationId: conversationId.value,
      message: editableMessage.value,
      private: false,
    });
    
    // Marcar atividade como completada
    const completedActivity = {
      id: selectedActivity.value.id,
      title: selectedActivity.value.title,
      completedAt: new Date().toISOString(),
      message: editableMessage.value,
    };
    
    // Atualizar lista local
    const existingIndex = completedActivities.value.findIndex(
      a => a.id === selectedActivity.value.id
    );
    if (existingIndex >= 0) {
      completedActivities.value[existingIndex] = completedActivity;
    } else {
      completedActivities.value.push(completedActivity);
    }
    
    // Salvar no backend (custom attributes)
    const ca = props.selectedDeal?.custom_attributes || {};
    await ConversationApi.updateCustomAttributes({
      conversationId: conversationId.value,
      customAttributes: {
        ...ca,
        completed_activities: completedActivities.value,
      },
    });
    
    alert(t('DEAL_ACTIVITIES.ALERTS.MESSAGE_SENT'));
    closeConfirmModal();
  } catch (error) {
    console.error('Error sending message:', error);
    alert(t('DEAL_ACTIVITIES.ALERTS.MESSAGE_FAILED'));
  } finally {
    isSending.value = false;
  }
};
</script>

<template>
  <div class="px-6 py-4">
    <!-- Alerta se não houver conversa -->
    <div
      v-if="!hasConversation"
      class="mb-4 rounded-lg bg-n-amber-2 border border-n-amber-6 p-4"
    >
      <div class="flex items-start gap-3">
        <span class="i-lucide-alert-triangle size-5 text-n-amber-11 flex-shrink-0 mt-0.5" />
        <div>
          <h3 class="text-sm font-medium text-n-amber-12 mb-1">
            {{ $t('DEAL_ACTIVITIES.NO_CONVERSATION_TITLE') }}
          </h3>
          <p class="text-xs text-n-amber-11">
            {{ $t('DEAL_ACTIVITIES.NO_CONVERSATION_DESC') }}
          </p>
        </div>
      </div>
    </div>

    <!-- Lista de atividades -->
    <div v-if="currentActivities.length > 0" class="space-y-3">
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
            :disabled="!hasConversation"
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
          <div class="mb-4">
            <label class="text-sm font-medium text-n-slate-12 block mb-2">
              {{ $t('DEAL_ACTIVITIES.CONFIRM_MODAL.MESSAGE_LABEL') }}
            </label>
            <textarea
              v-model="editableMessage"
              rows="6"
              class="w-full rounded-lg border border-n-strong bg-n-solid-2 p-3 text-sm text-n-slate-12 placeholder-n-slate-11 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent resize-none"
              :placeholder="$t('DEAL_ACTIVITIES.CONFIRM_MODAL.MESSAGE_PLACEHOLDER')"
            />
          </div>
          <div class="rounded-lg bg-n-blue-2 border border-n-blue-6 p-3">
            <div class="flex items-start gap-2">
              <span class="i-lucide-info size-4 text-n-blue-11 flex-shrink-0 mt-0.5" />
              <p class="text-xs text-n-blue-11">
                {{ $t('DEAL_ACTIVITIES.CONFIRM_MODAL.INFO') }}
              </p>
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
            :label="$t('DEAL_ACTIVITIES.CONFIRM_MODAL.SEND')"
            :is-loading="isSending"
            :disabled="isSending || !editableMessage.trim()"
            @click="sendMessage"
          />
        </div>
      </div>
    </woot-modal>
  </div>
</template>

