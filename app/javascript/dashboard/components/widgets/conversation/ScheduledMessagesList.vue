<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import ScheduledMessagesAPI from 'dashboard/api/scheduledMessages';

const props = defineProps({
  conversationId: { type: Number, required: true },
});

const { t } = useI18n();
const scheduledMessages = ref([]);
const loading = ref(false);

const loadScheduledMessages = async () => {
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
  try {
    await ScheduledMessagesAPI.cancel(props.conversationId, id);
    await loadScheduledMessages();
  } catch (error) {
    console.error('Failed to cancel scheduled message:', error);
  }
};

onMounted(loadScheduledMessages);
</script>

<template>
  <div
    v-if="scheduledMessages.length > 0"
    class="p-4 bg-n-amber-2 border-b border-n-alpha-2"
  >
    <div class="flex items-center gap-2 mb-2">
      <span class="i-ph-clock size-4 text-n-amber-11" />
      <h4 class="text-sm font-semibold text-n-slate-12">
        {{ $t('SCHEDULED_MESSAGES.PENDING_TITLE') }}
      </h4>
    </div>

    <div class="space-y-2">
      <div
        v-for="msg in scheduledMessages"
        :key="msg.id"
        class="p-2 bg-white rounded-md border border-n-alpha-2"
      >
        <p class="text-xs text-n-slate-11 truncate">{{ msg.content }}</p>
        <div class="flex items-center justify-between mt-1">
          <span class="text-xs text-n-slate-10">
            {{ new Date(msg.scheduled_at).toLocaleString() }}
          </span>
          <button
            class="text-xs text-n-ruby-11 hover:text-n-ruby-12"
            @click="cancelScheduledMessage(msg.id)"
          >
            {{ $t('SCHEDULED_MESSAGES.CANCEL') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
