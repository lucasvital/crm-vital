<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import ConversationApi from 'dashboard/api/inbox/conversation';
import wootConstants from 'dashboard/constants/globals';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'next/avatar/Avatar.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';

const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const alert = useAlert;
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');

// Pipeline de negócios (etapas do kanban)
const STAGES = ['new', 'qualified', 'proposal', 'won', 'lost'];

const state = reactive(
  STAGES.reduce((acc, stage) => {
    acc[stage] = {
      items: [],
      loading: false,
    };
    return acc;
  }, {})
);

const isAnyColumnLoading = computed(() =>
  STAGES.some(stage => state[stage].loading)
);

const fetchColumn = async stage => {
  state[stage].loading = true;
  try {
    // Busca apenas conversas com label "deal" (negócio)
    const { data } = await ConversationApi.get({
      labels: 'deal',
      page: 1,
      sortBy: wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC,
      assigneeType: wootConstants.ASSIGNEE_TYPE.ALL,
    });
    const payload = data?.data?.payload || data?.payload || [];
    // Filtra por etapa (custom_attributes.deal_stage)
    state[stage].items = payload.filter(conv => {
      const s = conv?.custom_attributes?.deal_stage || 'new';
      return s === stage;
    });
  } catch (e) {
    alert(t('KANBAN.ALERTS.FETCH_FAILED'));
    state[stage].items = [];
  } finally {
    state[stage].loading = false;
  }
};

const refreshBoard = async () => {
  await Promise.all(STAGES.map(stage => fetchColumn(stage)));
};

onMounted(async () => {
  await store.dispatch('inboxes/get');
  await refreshBoard();
});

const columnTitle = stage => {
  const map = {
    new: t('KANBAN.COLUMNS.NEW'),
    qualified: t('KANBAN.COLUMNS.QUALIFIED'),
    proposal: t('KANBAN.COLUMNS.PROPOSAL'),
    won: t('KANBAN.COLUMNS.WON'),
    lost: t('KANBAN.COLUMNS.LOST'),
  };
  return map[stage] || stage;
};

const getConversationRoute = conversationId =>
  accountScopedRoute('inbox_conversation', {
    conversation_id: conversationId,
  });

// DnD
const dragItem = ref(null); // { id, fromStage, index }
const dragOverStage = ref(null);
const isDropping = ref(false);
const movingConversation = ref(null);

const stageBadgeIconColor = stage => {
  switch (stage) {
    case 'new':
      return 'text-n-slate-11';
    case 'qualified':
      return 'text-n-amber-10';
    case 'proposal':
      return 'text-n-blue-10';
    case 'won':
      return 'text-n-green-10';
    case 'lost':
      return 'text-n-red-10';
    default:
      return 'text-n-slate-11';
  }
};

// Cores suaves por etapa (minimalista)
const stageHeaderBgClass = stage => {
  switch (stage) {
    case 'new':
      return 'bg-n-slate-2';
    case 'qualified':
      return 'bg-n-amber-2';
    case 'proposal':
      return 'bg-n-blue-2';
    case 'won':
      return 'bg-n-green-2';
    case 'lost':
      return 'bg-n-red-2';
    default:
      return 'bg-n-solid-2';
  }
};

const stageAccentBgClass = stage => {
  switch (stage) {
    case 'new':
      return 'bg-n-slate-7';
    case 'qualified':
      return 'bg-n-amber-8';
    case 'proposal':
      return 'bg-n-blue-8';
    case 'won':
      return 'bg-n-green-8';
    case 'lost':
      return 'bg-n-red-8';
    default:
      return 'bg-n-slate-7';
  }
};

const removeFromStage = (stage, id) => {
  const list = state[stage].items;
  const idx = list.findIndex(c => c.id === id);
  if (idx >= 0) list.splice(idx, 1);
};

const addToStage = (stage, conversation, atTop = true) => {
  const list = state[stage].items;
  if (atTop) list.unshift(conversation);
  else list.push(conversation);
};

const onDragStart = (conversation, stage, index, event) => {
  dragItem.value = { id: conversation.id, fromStage: stage, index };
  event.dataTransfer.setData(
    'text/plain',
    JSON.stringify({ id: conversation.id, fromStage: stage })
  );
  event.dataTransfer.effectAllowed = 'move';
};

const onDragOver = (stage, event) => {
  event.preventDefault();
  dragOverStage.value = stage;
  event.dataTransfer.dropEffect = 'move';
};

const onDragEnd = () => {
  dragItem.value = null;
  dragOverStage.value = null;
};

const onDrop = async (toStage, event) => {
  event.preventDefault();
  if (!dragItem.value) return;

  try {
    isDropping.value = true;
    const { id, fromStage } = dragItem.value;
    if (fromStage === toStage) return;

    const sourceList = state[fromStage].items;
    const conv = sourceList.find(c => c.id === id);
    if (!conv) return;

    // Update otimista
    removeFromStage(fromStage, id);
    addToStage(toStage, {
      ...conv,
      custom_attributes: { ...conv.custom_attributes, deal_stage: toStage },
    });

    // Persistência
    movingConversation.value = id;
    const currentAttrs = conv.custom_attributes || {};
    await ConversationApi.updateCustomAttributes({
      conversationId: id,
      customAttributes: { ...currentAttrs, deal_stage: toStage },
    });
    alert(t('KANBAN.ALERTS.STATUS_UPDATED'));
  } catch (e) {
    alert(t('KANBAN.ALERTS.STATUS_FAILED'));
    await refreshBoard();
  } finally {
    movingConversation.value = null;
    isDropping.value = false;
    onDragEnd();
  }
};

const hasNoData = computed(() =>
  STAGES.every(stage => state[stage].items.length === 0)
);

const inboxName = id => {
  const list = inboxes.value || [];
  const match = list.find(inbox => Number(inbox.id) === Number(id));
  return match?.name || t('KANBAN.CARDS.UNKNOWN_INBOX');
};

const getPreviewText = conversation => {
  const msg =
    conversation?.messages?.[0]?.content ||
    conversation?.last_non_activity_message?.content ||
    '';
  // garante que imagens/HTML não quebrem o layout
  return String(msg || '').replace(/<[^>]+>/g, '');
};
</script>

<template>
  <div class="flex h-full flex-col space-y-4 overflow-hidden px-6 py-4">
    <header class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('KANBAN.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('KANBAN.DESCRIPTION') }}
        </p>
      </div>
      <button
        class="inline-flex items-center justify-center rounded-md border border-n-strong bg-n-solid-1 px-3 py-2 text-sm font-medium text-n-slate-12 transition hover:bg-n-solid-2"
        type="button"
        :disabled="isAnyColumnLoading"
        @click="refreshBoard"
      >
        <span class="i-lucide-refresh-cw mr-2 size-4" />
        {{ t('KANBAN.CTA.REFRESH') }}
      </button>
    </header>

    <div
      v-if="isAnyColumnLoading && hasNoData"
      class="flex flex-1 items-center justify-center rounded-lg border border-dashed border-n-border bg-n-solid-1"
    >
      <Spinner class="text-n-brand" />
    </div>

    <div v-else class="flex flex-1 gap-6 overflow-x-auto pb-4">
      <div
        v-for="stage in STAGES"
        :key="stage"
        class="flex w-[320px] flex-col rounded-xl bg-n-solid-1/60 shadow-sm hover:shadow-md transition-shadow"
        :class="[dragOverStage === stage ? 'ring-1 ring-n-brand' : 'ring-1 ring-transparent hover:ring-n-alpha-2']"
        role="list"
        :aria-label="columnTitle(stage)"
        :aria-dropeffect="'move'"
        @dragover="onDragOver(stage, $event)"
        @drop="onDrop(stage, $event)"
      >
        <div :class="['sticky top-0 z-10 flex items-center justify-between border-b border-n-alpha-2 px-3 py-2 rounded-t-xl relative backdrop-blur-sm', stageHeaderBgClass(stage)]">
          <!-- Accent discreto no topo da coluna -->
          <span :class="['absolute left-0 top-0 h-0.5 w-full rounded-t-xl', stageAccentBgClass(stage)]" />
          <div class="flex items-center gap-2">
            <span class="text-sm font-semibold text-n-slate-12">
              {{ columnTitle(stage) }}
            </span>
            <span
              class="inline-flex items-center justify-center rounded-full bg-n-solid-2 px-2 py-0.5 text-xs font-medium text-n-slate-11"
            >
              {{ state[stage].items.length }}
            </span>
          </div>
          <Spinner
            v-if="state[stage].loading"
            class="size-4 text-n-brand"
          />
        </div>

        <transition-group name="kanban" tag="ul" class="flex flex-1 min-h-0 flex-col gap-3 overflow-y-auto px-3 py-3 scroll-smooth">
          <li
            v-for="conversation in state[stage].items"
            :key="conversation.id"
            class="flex flex-col gap-2 rounded-lg bg-n-solid-2 p-3 ring-1 ring-n-alpha-2 hover:ring-n-strong shadow-sm hover:shadow-md transition"
            draggable="true"
            role="listitem"
            :aria-grabbed="movingConversation === conversation.id"
            :title="t('KANBAN_A11Y.DRAG_HINT')"
            @dragstart="onDragStart(conversation, stage, $index, $event)"
            @dragend="onDragEnd"
          >
            <!-- Header do card: tag da etapa + avatar fantasma à direita -->
            <div class="flex items-center justify-between">
              <span
                class="inline-flex items-center gap-1 rounded-md bg-n-solid-1 px-2 py-0.5 text-[11px] font-medium text-n-slate-11 ring-1 ring-n-alpha-1"
                :aria-label="t('KANBAN.BADGE_STAGE', { stage: columnTitle(stage) })"
              >
                <span :class="['i-lucide-flag', 'size-3', stageBadgeIconColor(stage)]" />
                {{ columnTitle(stage) }}
              </span>
              <span
                class="i-lucide-user size-5 rounded-full bg-n-solid-2 text-n-slate-10 inline-flex items-center justify-center"
                aria-hidden="true"
              />
            </div>

            <!-- Linha com avatar pequeno e nome (mesmo padrão dos chips pequenos) -->
            <div class="mt-2 flex items-center gap-2 h-7">
              <Avatar
                :name="conversation.meta?.sender?.name"
                :src="conversation.meta?.sender?.thumbnail"
                :size="20"
                rounded-full
              />
              <div class="flex min-w-0 flex-col">
                <span class="text-sm leading-7 font-medium text-n-slate-12 truncate max-w-[180px]">
                  {{ conversation.meta?.sender?.name || t('KANBAN.CARDS.NO_NAME') }}
                </span>
                <span class="text-[11px] -mt-1 text-n-slate-11 truncate max-w-[180px]">
                  {{ t('KANBAN.CARDS.INBOX', { inbox: inboxName(conversation.inbox_id) }) }}
                </span>
              </div>
            </div>

            <div class="rounded-md bg-n-solid-3 p-2 text-xs text-n-slate-12">
              <p class="truncate">{{ getPreviewText(conversation) || t('KANBAN.CARDS.NO_PREVIEW') }}</p>
            </div>

            <div class="flex items-center justify-between text-xs text-n-slate-11">
              <TimeAgo
                :timestamp="conversation.last_activity_at"
                :tooltip="true"
              />
              <router-link
                class="font-medium text-n-brand hover:underline"
                :to="getConversationRoute(conversation.id)"
              >
                {{ t('KANBAN.CARDS.OPEN_CONVERSATION') }}
              </router-link>
            </div>
          </li>

          <li
            v-if="!state[stage].items.length && !state[stage].loading"
            class="rounded-md border border-dashed border-n-border bg-n-solid-2 p-3 text-center text-xs text-n-slate-11"
            :title="t('KANBAN_A11Y.DROP_TO', { stage: columnTitle(stage) })"
          >
            {{ t('KANBAN.CARDS.EMPTY_STATE') }}
          </li>
        </transition-group>
      </div>
    </div>
  </div>
</template>

