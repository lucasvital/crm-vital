<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import ConversationApi from 'dashboard/api/inbox/conversation';
import PipelinesAPI from 'dashboard/api/pipelines';
import DealsAPI from 'dashboard/api/deals';
import ContactAPI from 'dashboard/api/contacts';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import wootConstants from 'dashboard/constants/globals';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'next/avatar/Avatar.vue';
import CreateDealModal from 'dashboard/components/widgets/conversation/CreateDealModal.vue';
import CreateLeadModal from 'dashboard/components/widgets/conversation/CreateLeadModal.vue';
import ImportLeadsModal from 'dashboard/components/widgets/conversation/ImportLeadsModal.vue';
import PriorityMark from 'dashboard/components/widgets/conversation/PriorityMark.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import CardLabels from 'dashboard/components/widgets/conversation/conversationCardComponents/CardLabels.vue';
import ConversationsApi from 'dashboard/api/conversations';
import DealManageView from 'dashboard/routes/dashboard/conversation/DealManageView.vue';

const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const alert = useAlert;
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');

// Pipelines dinâmicos
const pipelines = ref([]);
const selectedPipelineId = ref(null);
const pipelineStages = ref([]); // [{id, name, key, position}]
const showPipelineMenu = ref(false);

const DEFAULT_STAGE_KEYS = ['new', 'qualified', 'proposal', 'won', 'lost'];
const STAGES = ref([...DEFAULT_STAGE_KEYS]);

const buildEmptyState = stages =>
  stages.reduce((acc, stage) => {
    acc[stage] = {
      items: [],
      loading: false,
    };
    return acc;
  }, {});

const state = reactive(buildEmptyState(STAGES.value));

const isAnyColumnLoading = computed(() =>
  STAGES.value.some(stage => state[stage].loading)
);

const showDealDetailsView = ref(false);

const fetchColumn = async stage => {
  state[stage].loading = true;
  try {
    // Busca deals do pipeline selecionado e mapeia para a estrutura usada na UI
    const pid = selectedPipelineId.value;
    const { data } = await DealsAPI.list({ pipelineId: pid });
    const deals = Array.isArray(data) ? data : [];
    // Buscar info recente de conversa/assignee por contato (cache por chamada)
    const contactIds = [
      ...new Set(deals.map(d => d?.contact?.id).filter(Boolean)),
    ];
    const contactInfoMap = {};
    await Promise.all(
      contactIds.map(async cid => {
        try {
          const resp = await ContactAPI.getConversations(cid);
          const convs = resp?.data?.payload || resp?.data?.data || resp?.data || [];
          // Pegar a conversa mais recente com mensagem não-atividade
          const sorted = (convs || []).slice().sort((a, b) => {
            const ax = a.last_activity_at || a.created_at || 0;
            const bx = b.last_activity_at || b.created_at || 0;
            return new Date(bx) - new Date(ax);
          });
          const recent = sorted[0] || null;
          const preview =
            recent?.last_non_activity_message?.content ||
            (Array.isArray(recent?.messages)
              ? (recent.messages.find(m => m.message_type !== 'activity')?.content || '')
              : '') ||
            '';
          const assigneeName = recent?.meta?.assignee?.name || '';
          const assigneeThumb = recent?.meta?.assignee?.thumbnail || '';
          const inboxId = recent?.inbox_id || null;
          const conversationId = recent?.id || null;
          contactInfoMap[cid] = {
            preview: String(preview || ''),
            assigneeName,
            assigneeThumb,
            inboxId,
            conversationId,
          };
        } catch (_) {
          contactInfoMap[cid] = { preview: '', assigneeName: '', assigneeThumb: '', inboxId: null, conversationId: null };
        }
      })
    );
    state[stage].items = deals
      .filter(d => d?.pipeline_stage?.key === stage)
      .map(d => {
        const cid = d?.contact?.id;
        const info = (cid && contactInfoMap[cid]) || {
          preview: '',
          assigneeName: '',
          assigneeThumb: '',
          inboxId: null,
          conversationId: null,
        };
        return {
          id: d.id, // deal id
          custom_attributes: {
            deal_stage: d.pipeline_stage?.key,
            deal_title: d.title,
            deal_amount: d.amount,
            deal_currency: d.currency,
            deal_close_date: d.close_date,
            deal_notes: d.notes,
          },
          meta: {
            sender: { name: d.contact?.name },
            assignee: { name: info.assigneeName, thumbnail: info.assigneeThumb },
          },
          _preview: info.preview,
          _inboxId: info.inboxId,
          _conversationId: info.conversationId,
        };
      });
  } catch (e) {
    alert(t('KANBAN.ALERTS.FETCH_FAILED'));
    state[stage].items = [];
  } finally {
    state[stage].loading = false;
  }
};

const refreshBoard = async () => {
  await Promise.all(STAGES.value.map(stage => fetchColumn(stage)));
};

onMounted(async () => {
  await store.dispatch('inboxes/get');
// Carrega pipelines e etapas do pipeline selecionado
  const { data: pipes } = await PipelinesAPI.get();
  pipelines.value = pipes || [];
  if (pipelines.value.length) {
    selectedPipelineId.value = pipelines.value[0].id;
    pipelineStages.value = (pipelines.value[0].pipeline_stages || []).sort((a, b) => a.position - b.position);
    const newStageKeys = pipelineStages.value.map(s => s.key);
    STAGES.value = newStageKeys.length ? newStageKeys : DEFAULT_STAGE_KEYS;
  } else {
    STAGES.value = DEFAULT_STAGE_KEYS;
  }
  Object.assign(state, buildEmptyState(STAGES.value));
  await refreshBoard();
});

const columnTitle = stageKey => {
  const found = pipelineStages.value.find(s => s.key === stageKey);
  if (found) return found.name;
  const map = {
    new: t('KANBAN.COLUMNS.NEW'),
    qualified: t('KANBAN.COLUMNS.QUALIFIED'),
    proposal: t('KANBAN.COLUMNS.PROPOSAL'),
    won: t('KANBAN.COLUMNS.WON'),
    lost: t('KANBAN.COLUMNS.LOST'),
  };
  return map[stageKey] || stageKey;
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
const showEditDealModal = ref(false);
const showCreateLeadModal = ref(false);
const showImportLeadsModal = ref(false);
const selectedConversation = ref(null);
const initialValues = ref({});

const stageBadgeIconColor = stage => {
  // Removido: cores específicas por etapa
  return 'text-n-slate-11';
};

// Removido: cores suaves por etapa
const stageHeaderBgClass = stage => {
  // Removido: cores específicas por etapa
  return 'bg-n-solid-2';
};

const getPriority = conversation => {
  const p = conversation?.priority;
  if (typeof p === 'number') {
    return ['low', 'medium', 'high', 'urgent'][p] || '';
  }
  return p || '';
};

const getConversationLabels = conversation => {
  return (
    conversation?.label_list ||
    conversation?.cached_label_list_array ||
    []
  );
};

const labelsWithoutDeal = labels => {
  return (labels || [])
    .map(l => (typeof l === 'string' ? l : l?.title || l?.name))
    .filter(Boolean)
    .filter(l => l !== 'deal');
};

const removeCardFromKanban = async (conversation, stage) => {
  try {
    // Update otimista: remove do UI primeiro
    removeFromStage(stage, conversation.id);
    const currentLabels = getConversationLabels(conversation);
    const nextLabels = labelsWithoutDeal(currentLabels);
    await ConversationsApi.updateLabels(conversation.id, nextLabels);
    alert(t('KANBAN.ALERTS.REMOVE_SUCCESS'));
  } catch (e) {
    alert(t('KANBAN.ALERTS.REMOVE_FAILED'));
    // Recarrega quadro para restaurar estado
    await refreshBoard();
  }
};

const formatCurrency = (amount, currency = 'BRL') => {
  try {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency,
      maximumFractionDigits: 2,
    }).format(Number(amount || 0));
  } catch (_) {
    return `R$ ${Number(amount || 0).toFixed(2)}`;
  }
};

const stageTotal = stage => {
  const items = state[stage]?.items || [];
  const totalsByCurrency = items.reduce((acc, c) => {
    const ca = c?.custom_attributes || {};
    const amt = Number(ca.deal_amount || 0);
    const cur = ca.deal_currency || 'BRL';
    if (!acc[cur]) acc[cur] = 0;
    acc[cur] += isNaN(amt) ? 0 : amt;
    return acc;
  }, {});
  const [currency, amount] = Object.entries(totalsByCurrency)[0] || ['BRL', 0];
  return formatCurrency(amount, currency);
};

const getDealAmountText = conversation => {
  const ca = conversation?.custom_attributes || {};
  const amt = Number(ca.deal_amount || 0);
  if (!amt || isNaN(amt)) return '';
  const cur = ca.deal_currency || 'BRL';
  return formatCurrency(amt, cur);
};

const getDealTitle = conversation => {
  const ca = conversation?.custom_attributes || {};
  return ca.deal_title || '';
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

const removeDealFromKanban = async (deal, stage) => {
  try {
    removeFromStage(stage, deal.id);
    await DealsAPI.delete(deal.id);
    alert(t('KANBAN.ALERTS.REMOVE_SUCCESS'));
  } catch (e) {
    alert(t('KANBAN.ALERTS.REMOVE_FAILED'));
    await refreshBoard();
  }
};

const onDrop = async (toStage, event) => {
  event.preventDefault();
  if (!dragItem.value) return;

  try {
    isDropping.value = true;
    const { id, fromStage } = dragItem.value;
    if (fromStage === toStage) return;

    const sourceList = state[fromStage].items;
    const dealLike = sourceList.find(c => c.id === id);
    if (!dealLike) return;

    // Update otimista
    removeFromStage(fromStage, id);
    addToStage(toStage, {
      ...dealLike,
      custom_attributes: { ...dealLike.custom_attributes, deal_stage: toStage },
    });

    // Persistência
    movingConversation.value = id;
    // Atualiza Deal (pipeline_stage)
    const stage = pipelineStages.value.find(s => s.key === toStage);
    if (stage) {
      await DealsAPI.update(id, { deal: { pipeline_stage_id: stage.id } });
    }
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
  STAGES.value.every(stage => state[stage].items.length === 0)
);

const inboxName = id => {
  const list = inboxes.value || [];
  const match = list.find(inbox => Number(inbox.id) === Number(id));
  return match?.name || t('KANBAN.CARDS.UNKNOWN_INBOX');
};

const getPreviewText = conversation => {
  const msg =
    conversation?.last_non_activity_message?.content ||
    (Array.isArray(conversation?.messages)
      ? (conversation.messages.find(m => m.message_type !== 'activity')?.content || '')
      : '');
  return String(msg || '').replace(/<[^>]+>/g, '');
};

const onCardClick = (conversation, event) => {
  const anchor = event?.target?.closest('a');
  if (anchor) return;
  selectedConversation.value = conversation;
  const ca = conversation?.custom_attributes || {};
  initialValues.value = {
    title: ca.deal_title || '',
    amount: ca.deal_amount || '',
    currency: ca.deal_currency || 'BRL',
    closeDate: ca.deal_close_date || '',
    notes: ca.deal_notes || '',
  };
  showDealDetailsView.value = true;
};

const onEditSubmit = async payload => {
  if (!selectedConversation.value) return;
  const id = selectedConversation.value.id;
  const ca = selectedConversation.value.custom_attributes || {};
  await ConversationApi.updateCustomAttributes({
    conversationId: id,
    customAttributes: {
      ...ca,
      deal_title: payload.title,
      deal_amount: payload.amount,
      deal_currency: payload.currency,
      deal_close_date: payload.closeDate,
      deal_notes: payload.notes,
    },
  });
  const stage = ca.deal_stage || 'new';
  const list = state[stage]?.items || [];
  const idx = list.findIndex(c => c.id === id);
  if (idx >= 0) {
    list[idx] = {
      ...list[idx],
      custom_attributes: {
        ...list[idx].custom_attributes,
        deal_title: payload.title,
        deal_amount: payload.amount,
        deal_currency: payload.currency,
        deal_close_date: payload.closeDate,
        deal_notes: payload.notes,
      },
    };
  }
  showEditDealModal.value = false;
  alert(t('KANBAN.ALERTS.STATUS_UPDATED'));
};

const handleLeadCreated = async () => {
  showCreateLeadModal.value = false;
  await refreshBoard();
};

const handleImportCompleted = async () => {
  showImportLeadsModal.value = false;
  await refreshBoard();
};

const closeDealDetailsView = () => {
  showDealDetailsView.value = false;
  selectedConversation.value = null;
};

const handleDealUpdate = async updatedData => {
  // Atualiza o deal no estado local
  const oldStage = selectedConversation.value?.custom_attributes?.deal_stage || '';
  const newStageKey = updatedData.stageKey || oldStage;
  
  // Remove da coluna antiga se mudou de etapa
  if (oldStage && oldStage !== newStageKey) {
    removeFromStage(oldStage, selectedConversation.value.id);
  }
  
  // Atualiza ou adiciona na nova coluna
  const updatedDeal = {
    ...selectedConversation.value,
    custom_attributes: {
      ...selectedConversation.value.custom_attributes,
      deal_title: updatedData.title,
      deal_amount: updatedData.amount,
      deal_currency: updatedData.currency,
      deal_close_date: updatedData.closeDate,
      deal_notes: updatedData.notes,
      deal_stage: newStageKey,
    },
  };
  
  if (oldStage !== newStageKey) {
    addToStage(newStageKey, updatedDeal, true);
  } else {
    // Atualiza na mesma coluna
    const list = state[oldStage]?.items || [];
    const idx = list.findIndex(c => c.id === selectedConversation.value.id);
    if (idx >= 0) {
      list[idx] = updatedDeal;
    }
  }
  
  selectedConversation.value = updatedDeal;
  closeDealDetailsView();
  alert(t('KANBAN.ALERTS.STATUS_UPDATED'));
};
</script>

<template>
  <div class="flex h-full flex-col space-y-4 overflow-hidden px-6 py-4">
    <header class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ pipelines.length && selectedPipelineId ? (pipelines.find(p => p.id === selectedPipelineId)?.name) || t('KANBAN.TITLE') : t('KANBAN.TITLE') }}
        </h1>
        <p class="text-sm text-n-slate-11">
          {{ t('KANBAN.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <div v-if="pipelines.length" class="relative">
          <NextButton
            sm
            slate
            type="button"
            class="!h-9"
            :trailing-icon="'i-lucide-chevron-down'"
            label="Selecione pipeline"
            @click="showPipelineMenu = !showPipelineMenu"
          />
          <DropdownMenu
            v-if="showPipelineMenu"
            class="absolute z-50 mt-1 min-w-40"
            :menu-items="(pipelines || []).map(p => ({ label: p.name, action: 'select', value: p.id }))"
            @action="async ({ value }) => {
              showPipelineMenu = false;
              if (!value || value === selectedPipelineId) return;
              selectedPipelineId = Number(value);
              const pipe = pipelines.find(p => p.id === selectedPipelineId) || {};
              pipelineStages = (pipe.pipeline_stages || []).slice().sort((a,b) => a.position - b.position);
              const newStageKeys = (pipelineStages || []).map(s => s.key);
              STAGES = newStageKeys.length ? newStageKeys : DEFAULT_STAGE_KEYS;
              Object.keys(state).forEach(k => delete state[k]);
              Object.assign(state, buildEmptyState(STAGES));
              await refreshBoard();
            }"
          />
        </div>
        <button
          class="inline-flex items-center justify-center rounded-md border border-n-strong bg-n-blue-9 px-3 py-2 h-9 text-sm font-medium text-white transition hover:bg-n-blue-10"
          type="button"
          @click="showCreateLeadModal = true"
        >
          <span class="i-lucide-plus mr-2 size-4" />
          {{ t('LEADS.CREATE.TITLE') }}
        </button>
        <button
          class="inline-flex items-center justify-center rounded-md border border-n-strong bg-n-solid-1 px-3 py-2 h-9 text-sm font-medium text-n-slate-12 transition hover:bg-n-solid-2"
          type="button"
          @click="showImportLeadsModal = true"
        >
          <span class="i-lucide-file-up mr-2 size-4" />
          {{ t('LEADS.IMPORT.TITLE') }}
        </button>
        <button
          class="inline-flex items-center justify-center rounded-md border border-n-strong bg-n-solid-1 px-3 py-2 h-9 text-sm font-medium text-n-slate-12 transition hover:bg-n-solid-2"
          type="button"
          :disabled="isAnyColumnLoading"
          @click="refreshBoard"
        >
          <span class="i-lucide-refresh-cw mr-2 size-4" />
          {{ t('KANBAN.CTA.REFRESH') }}
        </button>
      </div>
    </header>

    <div
      v-if="isAnyColumnLoading && hasNoData"
      class="flex flex-1 items-center justify-center rounded-lg border border-dashed border-n-border bg-n-solid-1"
    >
      <Spinner class="text-n-brand" />
    </div>

    <div v-else class="flex flex-1 gap-6 overflow-x-auto pb-4 px-1">
      <div
        v-for="stage in STAGES"
        :key="stage"
        class="flex flex-1 min-w-[320px] max-w-[400px] flex-col rounded-2xl bg-n-solid-1/70 shadow-sm hover:shadow-md transition-shadow"
        :class="[dragOverStage === stage ? 'ring-1 ring-n-brand' : 'ring-1 ring-transparent hover:ring-n-alpha-2']"
        role="list"
        :aria-label="columnTitle(stage)"
        :aria-dropeffect="'move'"
        @dragover="onDragOver(stage, $event)"
        @drop="onDrop(stage, $event)"
      >
        <!-- Header minimalista da coluna -->
        <div :class="['sticky top-0 z-10 relative backdrop-blur-sm rounded-t-2xl border-b border-n-alpha-2', stageHeaderBgClass(stage)]">
          <div class="flex items-center justify-between px-4 pt-3 pb-2">
            <div class="flex items-center gap-2">
              <span class="text-sm font-semibold text-n-slate-12">
                {{ columnTitle(stage) }}
              </span>
              <span class="text-[11px] text-n-slate-11">{{ stageTotal(stage) }}</span>
            </div>
            <div class="inline-flex items-center justify-center rounded-full bg-n-solid-2 text-n-slate-12 size-6 text-xs font-semibold">
              {{ state[stage].items.length }}
            </div>
          </div>
        </div>

        <transition-group name="kanban" tag="ul" class="flex flex-1 min-h-0 flex-col gap-3 overflow-y-auto px-3 py-3 scroll-smooth">
          <li
            v-for="deal in state[stage].items"
            :key="deal.id"
            class="flex flex-col gap-2 rounded-xl bg-n-solid-2 p-3 ring-1 ring-n-alpha-2 hover:ring-n-strong shadow-sm hover:shadow-md transition"
            draggable="true"
            role="listitem"
            :aria-grabbed="movingConversation === deal.id"
            :title="t('KANBAN_A11Y.DRAG_HINT')"
            @dragstart="onDragStart(deal, stage, $index, $event)"
            @dragend="onDragEnd"
            @click.stop="onCardClick(deal, $event)"
          >
            <!-- Linha superior: tag de etapa + avatar fantasma -->
            <div class="flex items-center justify-between">
              <div class="inline-flex items-center gap-1 rounded-full bg-n-solid-1 px-2 py-0.5 text-[11px] font-medium text-n-slate-11 ring-1 ring-n-alpha-1">
                <span :class="['i-lucide-flag', 'size-3', stageBadgeIconColor(stage)]" />
                {{ columnTitle(stage) }}
              </div>
              <div class="inline-flex items-center gap-2">
                <button
                  type="button"
                  class="rounded-md p-1 hover:bg-n-alpha-2 text-n-slate-11"
                  :title="t('KANBAN.CARDS.REMOVE')"
                  @click.stop="removeDealFromKanban(deal, stage)"
                >
                  <span class="i-lucide-trash-2 size-4" />
                </button>
                <PriorityMark :priority="getPriority(conversation)" />
              </div>
            </div>

            <!-- Título do negócio como título do card -->
            <div
              v-if="getDealTitle(deal)"
              class="mt-1 text-sm font-semibold text-n-slate-12 line-clamp-1"
            >
              {{ getDealTitle(deal) }}
            </div>

            <!-- Linha com avatar pequeno e nome (mesmo padrão dos chips pequenos) -->
            <div class="mt-1 flex items-center gap-2 h-7">
              <Avatar
                :name="deal.meta?.sender?.name"
                :src="deal.meta?.sender?.thumbnail"
                :size="20"
                rounded-full
              />
              <div class="flex min-w-0 flex-col">
                <span class="text-sm leading-7 font-medium text-n-slate-12 truncate">
                  {{ deal.meta?.sender?.name || t('KANBAN.CARDS.NO_NAME') }}
                </span>
                <span v-if="deal._inboxId" class="text-[11px] -mt-1 text-n-slate-11 truncate">
                  {{ t('KANBAN.CARDS.INBOX', { inbox: inboxName(deal._inboxId) }) }}
                </span>
              </div>
            </div>

            <div class="rounded-md bg-n-solid-3 p-2 text-xs text-n-slate-12">
              <p class="line-clamp-2">
                {{ deal._preview || deal.custom_attributes?.deal_notes || t('KANBAN.CARDS.NO_PREVIEW') }}
              </p>
              <p v-if="getDealAmountText(deal)" class="mt-1 font-medium text-n-slate-12">
                {{ getDealAmountText(deal) }}
              </p>
            </div>

            <!-- Controle de mover etapa: visível apenas em mobile -->
            <div class="md:hidden">
              <label class="text-[11px] text-n-slate-11 mr-2">{{ t('KANBAN.CARDS.MOVE_TO') }}</label>
              <select
                class="rounded-md border border-n-alpha-2 bg-n-solid-1 text-[11px] text-n-slate-12 px-2 py-1"
                :value="stage"
                @change="moveStageMobile(deal, stage, $event.target.value)"
              >
                <option v-for="opt in STAGES" :key="opt" :value="opt">
                  {{ columnTitle(opt) }}
                </option>
              </select>
            </div>

            <div class="flex items-center justify-between text-xs text-n-slate-11">
              <div class="flex items-center gap-2 min-w-0">
                <Avatar
                  v-if="deal.meta?.assignee?.name"
                  :name="deal.meta.assignee.name"
                  :src="deal.meta.assignee.thumbnail"
                  :size="18"
                  rounded-full
                />
                <span class="truncate">{{ deal.meta?.assignee?.name || t('KANBAN.CARDS.UNKNOWN_ASSIGNEE') }}</span>
              </div>
              <div class="flex items-center gap-2">
                <router-link
                  v-if="deal._conversationId"
                  class="font-medium text-n-brand hover:underline"
                  :to="getConversationRoute(deal._conversationId)"
                >
                  {{ t('KANBAN.CARDS.OPEN_CONVERSATION') }}
                </router-link>
                <span class="text-n-slate-10">{{ deal.close_date || '' }}</span>
              </div>
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
    <CreateLeadModal
      :show="showCreateLeadModal"
      @cancel="() => (showCreateLeadModal = false)"
      @success="handleLeadCreated"
    />
    <ImportLeadsModal
      :show="showImportLeadsModal"
      @cancel="() => (showImportLeadsModal = false)"
      @success="handleImportCompleted"
    />
    <CreateDealModal
      v-if="showEditDealModal"
      :show="showEditDealModal"
      :current-chat="selectedConversation"
      :initial-values="initialValues"
      title-key="KANBAN.FORM.EDIT_TITLE"
      desc-key="KANBAN.FORM.EDIT_DESC"
      submit-key="KANBAN.FORM.UPDATE"
      @cancel="() => (showEditDealModal = false)"
      @submit="onEditSubmit"
    />
    
    <!-- Deal Details View em tela cheia -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition-opacity duration-200 ease-in-out"
        leave-active-class="transition-opacity duration-200 ease-in-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div
          v-if="showDealDetailsView"
          class="fixed inset-0 z-[9999] bg-n-background"
        >
          <DealManageView
            :selected-deal="selectedConversation"
            :pipeline-stages="pipelineStages"
            :show-back-button="false"
            @close="closeDealDetailsView"
            @update-deal="handleDealUpdate"
          />
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

