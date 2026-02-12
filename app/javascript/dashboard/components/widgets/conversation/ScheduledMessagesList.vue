<script setup>
import { ref, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ScheduledMessagesAPI from 'dashboard/api/scheduledMessages';

const props = defineProps({
  conversationId: { type: Number, required: true },
});

const { t } = useI18n();
const scheduledMessages = ref([]);
const loading = ref(false);

const loadScheduledMessages = async () => {
  if (!props.conversationId) return;
  
  loading.value = true;
  try {
    const { data } = await ScheduledMessagesAPI.list(props.conversationId);
    scheduledMessages.value = data.filter(m => m.status === 'pending');
  } catch (error) {
    console.error('Failed to load scheduled messages:', error);
  } finally {
    loading.value = false;
  }
};

const cancelScheduledMessage = async id => {
  if (!confirm(t('SCHEDULED_MESSAGES.CONFIRM_CANCEL'))) {
    return;
  }
  
  try {
    await ScheduledMessagesAPI.cancel(props.conversationId, id);
    useAlert(t('SCHEDULED_MESSAGES.CANCEL_SUCCESS'));
    await loadScheduledMessages();
  } catch (error) {
    useAlert(t('SCHEDULED_MESSAGES.CANCEL_ERROR'));
    console.error('Failed to cancel scheduled message:', error);
  }
};

// Watch for conversation changes
watch(() => props.conversationId, () => {
  loadScheduledMessages();
}, { immediate: true });

// Expose reload method for parent component
defineExpose({
  reload: loadScheduledMessages,
});
</script>

<template>
  <div
    v-if="scheduledMessages.length > 0"
    class="p-4 bg-n-amber-2 border-b border-n-alpha-2"
  >
    <div class="flex items-center gap-2 mb-3">
      <span class="i-ph-clock size-5 text-n-amber-11" />
      <h4 class="text-sm font-semibold text-n-slate-12">
        {{ $t('SCHEDULED_MESSAGES.PENDING_TITLE') }}
        <span class="ml-1 text-xs font-normal text-n-amber-11">
          ({{ scheduledMessages.length }})
        </span>
      </h4>
    </div>

    <div class="space-y-2">
      <div
        v-for="msg in scheduledMessages"
        :key="msg.id"
        class="p-3 bg-white dark:bg-n-slate-2 rounded-lg border border-n-alpha-2 shadow-sm hover:shadow-md transition-shadow"
      >
        <p class="text-sm text-n-slate-12 mb-2 line-clamp-2">
          {{ msg.content }}
        </p>
        <div class="flex items-center justify-between gap-2">
          <div class="flex items-center gap-1 text-xs text-n-slate-10">
            <span class="i-ph-calendar size-3" />
            <span>{{ new Date(msg.scheduled_at).toLocaleString('pt-BR', {
              day: '2-digit',
              month: '2-digit',
              year: 'numeric',
              hour: '2-digit',
              minute: '2-digit'
            }) }}</span>
          </div>
          <button
            class="px-2 py-1 text-xs font-medium text-n-ruby-11 hover:text-n-ruby-12 hover:bg-n-ruby-3 rounded transition-colors"
            @click="cancelScheduledMessage(msg.id)"
          >
            {{ $t('SCHEDULED_MESSAGES.CANCEL') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
