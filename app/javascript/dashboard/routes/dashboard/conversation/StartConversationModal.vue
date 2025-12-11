<script setup>
import { ref, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

const props = defineProps({
  show: {
    type: Boolean,
    required: true,
  },
  contactId: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(['close', 'conversation-created']);

const store = useStore();
const conversationCreated = ref(false);

// Watch for new conversations being created in the store
// This is a workaround since ComposeConversation doesn't emit conversation-created
const unwatchConversations = watch(
  () => store.getters['contactConversations/getUIFlags'].isCreating,
  (isCreating, wasCreating) => {
    // When isCreating transitions from true to false, a conversation was created
    if (wasCreating && !isCreating && !conversationCreated.value) {
      conversationCreated.value = true;
      
      // Get the most recently created conversation
      const conversations = store.getters['contactConversations/getContactConversation'](props.contactId);
      if (conversations && conversations.length > 0) {
        const latestConversation = conversations[conversations.length - 1];
        emit('conversation-created', latestConversation.id);
      }
    }
  }
);

const handleClose = () => {
  conversationCreated.value = false;
  emit('close');
};

// Clean up watcher when component is unmounted
import { onUnmounted } from 'vue';
onUnmounted(() => {
  unwatchConversations();
});
</script>

<template>
  <div
    v-if="show"
    class="fixed inset-0 z-[9999] flex items-center justify-center"
    @click.self="handleClose"
  >
    <!-- Backdrop -->
    <div
      class="absolute inset-0 bg-n-alpha-black1 backdrop-blur-[4px]"
      @click="handleClose"
    />
    
    <!-- Modal Content -->
    <div
      class="relative z-10 w-full max-w-2xl mx-4"
      @click.stop
    >
      <ComposeConversation
        :contact-id="contactId"
        :is-modal="true"
        @close="handleClose"
      />
    </div>
  </div>
</template>

