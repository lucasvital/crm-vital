<script setup>
import { watch, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAI } from 'dashboard/composables/useAI';
import { useAlert } from 'dashboard/composables';

import Editor from 'dashboard/components-next/Editor/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ContactNoteItem from 'next/Contacts/ContactsSidebar/components/ContactNoteItem.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  contactId: { type: [String, Number], required: true },
});

const { t } = useI18n();
const store = useStore();
const currentUser = useMapGetter('getCurrentUser');
const uiFlags = useMapGetter('contactNotes/getUIFlags');
const notesByContact = useMapGetter('contactNotes/getAllNotesByContactId');
const currentChat = useMapGetter('getSelectedChat');

const {
  processEvent,
  isAIIntegrationEnabled,
  fetchIntegrationsIfRequired,
  recordAnalytics,
} = useAI();

const isFetchingNotes = computed(() => uiFlags.value.isFetching);
const isCreatingNote = computed(() => uiFlags.value.isCreating);
const contactId = computed(() => props.contactId);
const noteContent = ref('');
const shouldShowCreateModal = ref(false);
const isAnalyzing = ref(false);
const notes = computed(() => {
  if (!contactId.value) {
    return [];
  }
  return notesByContact.value(contactId.value) || [];
});

const getWrittenBy = ({ user } = {}) => {
  const currentUserId = currentUser.value?.id;
  return user?.id === currentUserId
    ? t('CONTACTS_LAYOUT.SIDEBAR.NOTES.YOU')
    : user?.name || t('CONVERSATION.BOT');
};

const openCreateModal = () => {
  if (!contactId.value) {
    return;
  }

  noteContent.value = '';
  shouldShowCreateModal.value = true;
};

const closeCreateModal = () => {
  shouldShowCreateModal.value = false;
  noteContent.value = '';
};

const onAdd = async () => {
  if (!contactId.value || !noteContent.value || isCreatingNote.value) {
    return;
  }

  await store.dispatch('contactNotes/create', {
    content: noteContent.value,
    contactId: contactId.value,
  });
  noteContent.value = '';
  closeCreateModal();
};

const onDelete = noteId => {
  if (!contactId.value || !noteId) {
    return;
  }

  store.dispatch('contactNotes/delete', {
    noteId,
    contactId: contactId.value,
  });
};

const canAnalyzeWithAI = computed(
  () => isAIIntegrationEnabled.value && !!contactId.value
);

const analyzeButtonLabel = computed(() =>
  isAnalyzing.value
    ? t('CONTACTS_LAYOUT.SIDEBAR.NOTES.ANALYSIS_IN_PROGRESS')
    : t('CONTACTS_LAYOUT.SIDEBAR.NOTES.ANALYZE_WITH_AI')
);

const analyzeButtonTooltip = computed(() => {
  if (!isAIIntegrationEnabled.value) {
    return t('CONTACTS_LAYOUT.SIDEBAR.NOTES.ANALYZE_WITH_AI_DISABLED');
  }
  return '';
});

const analyzeConversationWithAI = async () => {
  if (
    !canAnalyzeWithAI.value ||
    isAnalyzing.value ||
    isFetchingNotes.value
  ) {
    return;
  }

  isAnalyzing.value = true;
  try {
    await fetchIntegrationsIfRequired();
    const analysis = await processEvent('conversation_analysis');

    if (!analysis || !analysis.trim()) {
      useAlert(t('CONTACTS_LAYOUT.SIDEBAR.NOTES.ANALYSIS_ERROR'));
      return;
    }

    const formattedContent = `${t(
      'CONTACTS_LAYOUT.SIDEBAR.NOTES.ANALYSIS_NOTE_TITLE'
    )}\n\n${analysis.trim()}`;

    await store.dispatch('contactNotes/create', {
      content: formattedContent,
      contactId: contactId.value,
    });

    recordAnalytics('conversation_analysis', {
      conversation_id: currentChat.value?.id,
    });

    useAlert(t('CONTACTS_LAYOUT.SIDEBAR.NOTES.ANALYSIS_SUCCESS'));
  } catch (error) {
    useAlert(t('CONTACTS_LAYOUT.SIDEBAR.NOTES.ANALYSIS_ERROR'));
  } finally {
    isAnalyzing.value = false;
  }
};

const keyboardEvents = {
  '$mod+Enter': {
    action: onAdd,
    allowOnFocusedInput: true,
  },
};

useKeyboardEvents(keyboardEvents);

watch(
  contactId,
  newContactId => {
    closeCreateModal();
    if (newContactId) {
      store.dispatch('contactNotes/get', { contactId: newContactId });
    }
  },
  { immediate: true }
);
</script>

<template>
  <div>
    <div class="px-4 pt-3 pb-2">
      <div class="flex flex-col gap-2 lg:flex-row">
        <NextButton
          ghost
          xs
          icon="i-lucide-plus"
          :label="$t('CONTACTS_LAYOUT.SIDEBAR.NOTES.ADD_NOTE')"
          :disabled="!contactId || isFetchingNotes"
          @click="openCreateModal"
        />
        <NextButton
          ghost
          xs
          icon="i-lucide-sparkles"
          :label="analyzeButtonLabel"
          :is-loading="isAnalyzing"
          :disabled="!canAnalyzeWithAI || isFetchingNotes || isAnalyzing"
          v-tooltip="analyzeButtonTooltip"
          @click="analyzeConversationWithAI"
        />
      </div>
    </div>

    <div
      v-if="isFetchingNotes"
      class="flex items-center justify-center py-8 text-n-slate-11"
    >
      <Spinner />
    </div>
    <div
      v-else-if="notes.length"
      class="flex flex-col max-h-[300px] overflow-y-auto"
    >
      <ContactNoteItem
        v-for="note in notes"
        :key="note.id"
        class="py-4 last-of-type:border-b-0 px-4"
        :note="note"
        :written-by="getWrittenBy(note)"
        allow-delete
        collapsible
        @delete="onDelete"
      />
    </div>
    <p v-else class="px-6 py-6 text-sm leading-6 text-center text-n-slate-11">
      {{ t('CONTACTS_LAYOUT.SIDEBAR.NOTES.CONVERSATION_EMPTY_STATE') }}
    </p>

    <woot-modal
      v-model:show="shouldShowCreateModal"
      :on-close="closeCreateModal"
      :close-on-backdrop-click="false"
      class="!items-start [&>div]:!top-12 [&>div]:sticky"
    >
      <div class="flex w-full flex-col gap-6 px-6 py-6">
        <h3 class="text-lg font-semibold text-n-slate-12">
          {{ t('CONTACTS_LAYOUT.SIDEBAR.NOTES.ADD_NOTE') }}
        </h3>
        <Editor
          v-model="noteContent"
          focus-on-mount
          :placeholder="t('CONTACTS_LAYOUT.SIDEBAR.NOTES.PLACEHOLDER')"
          class="[&>div]:!border-transparent [&>div]:px-4 [&>div]:py-4"
        />
        <div class="flex items-center justify-end gap-3">
          <NextButton
            solid
            blue
            :label="t('CONTACTS_LAYOUT.SIDEBAR.NOTES.SAVE')"
            :is-loading="isCreatingNote"
            :disabled="!noteContent || isCreatingNote"
            @click="onAdd"
          />
        </div>
      </div>
    </woot-modal>
  </div>
</template>
