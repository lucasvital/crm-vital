<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import DealsAPI from 'dashboard/api/deals';

const props = defineProps({
  show: {
    type: Boolean,
    required: true,
  },
  contactId: {
    type: String,
    default: null,
  },
  contact: {
    type: Object,
    default: null,
  },
  dealId: {
    type: [String, Number],
    default: null,
  },
});

const emit = defineEmits(['close', 'conversation-created']);

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const inboxesList = useMapGetter('inboxes/getInboxes');
const selectedInbox = ref(null);
const message = ref('');
const isSending = ref(false);

// Buscar inboxes disponíveis para o contato
const availableInboxes = computed(() => {
  // Por enquanto, retorna todos os inboxes ativos
  return inboxesList.value.filter(inbox => inbox.channel_type);
});

const canSend = computed(() => {
  return selectedInbox.value && message.value.trim().length > 0;
});

const handleClose = () => {
  selectedInbox.value = null;
  message.value = '';
  emit('close');
};

const handleSend = async () => {
  if (!canSend.value) return;
  
  if (!props.contactId || !props.contact) {
    useAlert('Erro: Contato não encontrado');
    return;
  }
  
  isSending.value = true;
  try {
    // Verificar se é WhatsApp para usar o payload correto
    const isWhatsApp = selectedInbox.value.channel_type === 'Channel::Whatsapp';
    
    // Para WhatsApp, sourceId deve ser o número de telefone (apenas dígitos)
    let sourceId = `contact-${props.contactId}-${Date.now()}`;
    if (isWhatsApp && props.contact.phone_number) {
      // Limpar tudo exceto dígitos
      sourceId = props.contact.phone_number.replace(/\D/g, '');
      console.log('WhatsApp sourceId (phone):', sourceId);
    }
    
    console.log('Creating conversation with params:', {
      inboxId: selectedInbox.value.id,
      contactId: props.contactId,
      sourceId,
      isWhatsApp,
    });
    
    const params = {
      inboxId: selectedInbox.value.id,
      contactId: props.contactId,
      message: {
        content: message.value,
      },
      sourceId,
    };
    
    const response = await store.dispatch('contactConversations/create', {
      params,
      isFromWhatsApp: isWhatsApp,
    });
    
    if (response && response.id) {
      // Se tiver um dealId, atualizar o deal com a conversa
      if (props.dealId) {
        try {
          await DealsAPI.update(props.dealId, { deal: { conversation_id: response.id } });
        } catch (error) {
          console.error('Error updating deal with conversation:', error);
        }
      }

      useAlert(t('KANBAN.CONVERSATION_STARTED'));
      emit('conversation-created', response.id);
      handleClose();

      // Redirecionar para a conversa
      router.push(accountScopedRoute(`conversations/${response.id}`));
    }
  } catch (error) {
    console.error('Error creating conversation:', error);
    console.error('Error response:', error?.response?.data);
    const errorMsg = error?.response?.data?.message || 'Erro ao criar conversa. Tente novamente.';
    useAlert(errorMsg);
  } finally {
    isSending.value = false;
  }
};

onMounted(() => {
  // Seleciona o primeiro inbox por padrão se houver
  if (availableInboxes.value.length > 0) {
    selectedInbox.value = availableInboxes.value[0];
  }
});
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition-opacity duration-200"
      leave-active-class="transition-opacity duration-200"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="show"
        class="fixed inset-0 z-[9999] flex items-center justify-center bg-n-alpha-black1 backdrop-blur-[4px]"
        @click.self="handleClose"
      >
        <!-- Modal Card -->
        <div
          class="relative w-full max-w-lg mx-4 bg-n-background rounded-xl shadow-xl ring-1 ring-n-alpha-2"
          @click.stop
        >
          <!-- Header -->
          <div class="flex items-center justify-between p-4 border-b border-n-alpha-2">
            <h2 class="text-lg font-semibold text-n-slate-12">
              {{ t('KANBAN.START_CONVERSATION') }}
            </h2>
            <button
              type="button"
              class="rounded-md p-1 text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
              @click="handleClose"
            >
              <span class="i-lucide-x size-5" />
            </button>
          </div>

          <!-- Body -->
          <div class="p-4 space-y-4">
            <!-- Inbox Selector -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                Canal de comunicação
              </label>
              <select
                v-model="selectedInbox"
                class="w-full rounded-lg border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              >
                <option
                  v-for="inbox in availableInboxes"
                  :key="inbox.id"
                  :value="inbox"
                >
                  {{ inbox.name }} ({{ inbox.channel_type }})
                </option>
              </select>
              <p
                v-if="availableInboxes.length === 0"
                class="mt-2 text-sm text-n-slate-11"
              >
                Nenhum inbox disponível. Configure um inbox primeiro.
              </p>
            </div>

            <!-- Message Input -->
            <div>
              <label class="block text-sm font-medium text-n-slate-12 mb-2">
                Mensagem inicial
              </label>
              <textarea
                v-model="message"
                rows="4"
                class="w-full rounded-lg border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand resize-none"
                placeholder="Digite sua mensagem..."
              />
            </div>
          </div>

          <!-- Footer -->
          <div class="flex items-center justify-end gap-2 p-4 border-t border-n-alpha-2">
            <ButtonV4
              variant="ghost"
              color="slate"
              @click="handleClose"
            >
              Cancelar
            </ButtonV4>
            <ButtonV4
              variant="solid"
              color="primary"
              :disabled="!canSend || isSending"
              :loading="isSending"
              @click="handleSend"
            >
              {{ isSending ? 'Enviando...' : 'Enviar Mensagem' }}
            </ButtonV4>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
