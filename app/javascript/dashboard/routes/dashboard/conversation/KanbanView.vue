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

const nextStageOptions = stage =>
  STAGES.filter(item => item !== stage).map(s => ({
    value: s,
    label: columnTitle(s),
  }));

const movingConversation = ref(null);

const onChangeStage = async (conversation, targetStage) => {
  if (!targetStage) return;

  movingConversation.value = conversation.id;
  try {
    const currentAttrs = conversation.custom_attributes || {};
    await ConversationApi.updateCustomAttributes({
      conversationId: conversation.id,
      customAttributes: { ...currentAttrs, deal_stage: targetStage },
    });
    alert(t('KANBAN.ALERTS.STATUS_UPDATED'));
    await refreshBoard();
  } catch (err) {
    alert(t('KANBAN.ALERTS.STATUS_FAILED'));
  } finally {
    movingConversation.value = null;
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

    <div v-else class="flex flex-1 gap-4 overflow-x-auto pb-4">
      <div
        v-for="stage in STAGES"
        :key="stage"
        class="flex w-[320px] flex-col rounded-lg border border-n-border bg-n-solid-1"
      >
        <div class="flex items-center justify-between border-b border-n-border px-4 py-3">
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

        <ul class="flex flex-1 flex-col gap-3 overflow-y-auto px-4 py-3">
          <li
            v-for="conversation in state[stage].items"
            :key="conversation.id"
            class="flex flex-col gap-3 rounded-md border border-n-border bg-n-solid-2 p-3 shadow-sm transition hover:border-n-strong"
          >
            <div class="flex items-center gap-3">
              <Avatar
                :name="conversation.meta?.sender?.name"
                :src="conversation.meta?.sender?.thumbnail"
                size="32px"
              />
              <div class="flex flex-col">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ conversation.meta?.sender?.name || t('KANBAN.CARDS.NO_NAME') }}
                </span>
                <span class="text-xs text-n-slate-11">
                  {{ t('KANBAN.CARDS.INBOX', { inbox: inboxName(conversation.inbox_id) }) }}
                </span>
              </div>
            </div>

            <div class="rounded-md bg-n-solid-3 p-2 text-xs text-n-slate-12">
              <p class="line-clamp-3">
                {{
                  conversation.messages?.[0]?.content ||
                  conversation.last_non_activity_message?.content ||
                  t('KANBAN.CARDS.NO_PREVIEW')
                }}
              </p>
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

            <div class="flex flex-col gap-2">
              <label
                class="text-xs font-medium text-n-slate-11"
                :for="`kanban-status-${conversation.id}`"
              >
                {{ t('KANBAN.CARDS.MOVE_TO') }}
              </label>
              <select
                :id="`kanban-status-${conversation.id}`"
                class="w-full rounded-md border border-n-border bg-n-solid-1 px-2 py-1 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none focus:ring-1 focus:ring-n-brand"
                :disabled="movingConversation === conversation.id"
                @change="event => onChangeStage(conversation, event.target.value)"
              >
                <option selected disabled value="">
                  {{ t('KANBAN.CARDS.SELECT_STATUS') }}
                </option>
                <option
                  v-for="option in nextStageOptions(stage)"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </div>

            <div
              v-if="movingConversation === conversation.id"
              class="flex items-center justify-end text-xs text-n-slate-11"
            >
              <Spinner class="mr-2 size-3 text-n-brand" />
              {{ t('KANBAN.CARDS.UPDATING') }}
            </div>
          </li>

          <li
            v-if="!state[stage].items.length && !state[stage].loading"
            class="rounded-md border border-dashed border-n-border bg-n-solid-2 p-3 text-center text-xs text-n-slate-11"
          >
            {{ t('KANBAN.CARDS.EMPTY_STATE') }}
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

