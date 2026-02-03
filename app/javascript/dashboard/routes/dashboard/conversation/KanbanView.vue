<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
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
import StartConversationModal from './StartConversationModal.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const router = useRouter();
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

    // Agora usamos conversation_id que vem do deal (sem N+1 queries!)
    state[stage].items = deals
      .filter(d => d?.pipeline_stage?.key === stage)
      .map(d => {
        // Priorizar assignee do deal
        const dealAssignee = d.assignee;
        const assigneeName = dealAssignee?.name || '';
        const assigneeThumb = dealAssignee?.thumbnail || '';

        return {
          id: d.id, // deal id
          pipeline_stage_id: d.pipeline_stage_id,
          assignee_id: d.assignee_id,
          contact: d.contact,
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
            assignee: { name: assigneeName, thumbnail: assigneeThumb },
          },
          _preview: d.notes || '',
          _inboxId: null,
          _conversationId: d.conversation_id || null,
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
  // Buscar TODOS os deals do pipeline UMA VEZ (otimização de performance)
  const pid = selectedPipelineId.value;
  
  try {
    // Marcar todas as colunas como loading
    STAGES.value.forEach(stage => {
      state[stage].loading = true;
    });

    const { data } = await DealsAPI.list({ pipelineId: pid });
    const deals = Array.isArray(data) ? data : [];

    // Distribuir deals entre as stages (uma passada no array)
    const dealsByStage = deals.reduce((acc, deal) => {
      const stageKey = deal?.pipeline_stage?.key;
      if (stageKey && !acc[stageKey]) {
        acc[stageKey] = [];
      }
      if (stageKey) {
        acc[stageKey].push(deal);
      }
      return acc;
    }, {});

    // Mapear deals para cada stage
    STAGES.value.forEach(stage => {
      const stageDeals = dealsByStage[stage] || [];
      state[stage].items = stageDeals.map(d => {
        const dealAssignee = d.assignee;
        const assigneeName = dealAssignee?.name || '';
        const assigneeThumb = dealAssignee?.thumbnail || '';

        return {
          id: d.id,
          pipeline_stage_id: d.pipeline_stage_id,
          assignee_id: d.assignee_id,
          contact: d.contact,
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
            assignee: { name: assigneeName, thumbnail: assigneeThumb },
          },
          _preview: d.notes || '',
          _inboxId: null,
          _conversationId: d.conversation_id || null,
        };
      });
      state[stage].loading = false;
    });
  } catch (e) {
    alert(t('KANBAN.ALERTS.FETCH_FAILED'));
    STAGES.value.forEach(stage => {
      state[stage].items = [];
      state[stage].loading = false;
    });
  }
};

onMounted(async () => {
  await store.dispatch('inboxes/get');
  await store.dispatch('agents/get');
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
const showStartConversationModal = ref(false);
const selectedDealForConversation = ref(null);

// Seleção em lote
const selectionMode = ref(false);
const selectedDeals = ref(new Set());
const isDeletingBatch = ref(false);

const selectedDealsCount = computed(() => selectedDeals.value.size);

const allDealsCount = computed(() => {
  return STAGES.value.reduce((acc, stage) => acc + (state[stage]?.items?.length || 0), 0);
});

const isAllSelected = computed(() => {
  return allDealsCount.value > 0 && selectedDealsCount.value === allDealsCount.value;
});

const toggleSelectionMode = () => {
  selectionMode.value = !selectionMode.value;
  if (!selectionMode.value) {
    selectedDeals.value = new Set();
  }
};

const toggleDealSelection = (dealId, event) => {
  event.stopPropagation();
  const newSet = new Set(selectedDeals.value);
  if (newSet.has(dealId)) {
    newSet.delete(dealId);
  } else {
    newSet.add(dealId);
  }
  selectedDeals.value = newSet;
};

const isDealSelected = (dealId) => selectedDeals.value.has(dealId);

const selectAllDeals = () => {
  const newSet = new Set();
  STAGES.value.forEach(stage => {
    (state[stage]?.items || []).forEach(deal => {
      newSet.add(deal.id);
    });
  });
  selectedDeals.value = newSet;
};

const deselectAllDeals = () => {
  selectedDeals.value = new Set();
};

const deleteSelectedDeals = async () => {
  if (selectedDealsCount.value === 0) return;

  const confirmed = window.confirm(
    t('KANBAN.BATCH.CONFIRM_DELETE', { count: selectedDealsCount.value })
  );
  if (!confirmed) return;

  isDeletingBatch.value = true;
  const idsToDelete = Array.from(selectedDeals.value);
  const errors = [];

  for (const dealId of idsToDelete) {
    try {
      await DealsAPI.delete(dealId);
      // Remove do estado local
      STAGES.value.forEach(stage => {
        const idx = state[stage].items.findIndex(d => d.id === dealId);
        if (idx >= 0) state[stage].items.splice(idx, 1);
      });
    } catch (e) {
      errors.push(dealId);
    }
  }

  selectedDeals.value = new Set();
  isDeletingBatch.value = false;

  if (errors.length > 0) {
    alert(t('KANBAN.BATCH.DELETE_PARTIAL', { success: idsToDelete.length - errors.length, failed: errors.length }));
  } else {
    alert(t('KANBAN.BATCH.DELETE_SUCCESS', { count: idsToDelete.length }));
  }
};

// Agentes e distribuição
const agents = useMapGetter('agents/getAgents');
const showDistributeModal = ref(false);
const isDistributing = ref(false);
const selectedStageForSelection = ref('all');
const distributionConfig = ref([]);

const getDealsFromStage = (stageKey) => {
  if (stageKey === 'all') {
    return STAGES.value.flatMap(stage => state[stage]?.items || []);
  }
  return state[stageKey]?.items || [];
};

const getStageDealsCount = (stageKey) => {
  return getDealsFromStage(stageKey).length;
};

const selectByPercentage = (percentage, stageKey = 'all') => {
  const deals = getDealsFromStage(stageKey);
  const count = Math.ceil(deals.length * (percentage / 100));
  const shuffled = [...deals].sort(() => Math.random() - 0.5);
  const toSelect = shuffled.slice(0, count);

  const newSet = new Set(selectedDeals.value);
  toSelect.forEach(deal => newSet.add(deal.id));
  selectedDeals.value = newSet;
};

const selectAllFromStage = (stageKey) => {
  const deals = getDealsFromStage(stageKey);
  const newSet = new Set(selectedDeals.value);
  deals.forEach(deal => newSet.add(deal.id));
  selectedDeals.value = newSet;
};

const deselectAllFromStage = (stageKey) => {
  const deals = getDealsFromStage(stageKey);
  const dealIds = new Set(deals.map(d => d.id));
  const newSet = new Set([...selectedDeals.value].filter(id => !dealIds.has(id)));
  selectedDeals.value = newSet;
};

const openDistributeModal = () => {
  if (selectedDealsCount.value === 0) return;
  distributionConfig.value = [];
  showDistributeModal.value = true;
};

const addAgentToDistribution = (agentId) => {
  if (!agentId || distributionConfig.value.find(d => d.agentId === agentId)) return;
  const agent = (agents.value || []).find(a => a.id === Number(agentId));
  if (agent) {
    distributionConfig.value.push({
      agentId: agent.id,
      agentName: agent.name,
      percentage: 0,
    });
    recalculatePercentages();
  }
};

const removeAgentFromDistribution = (agentId) => {
  distributionConfig.value = distributionConfig.value.filter(d => d.agentId !== agentId);
  recalculatePercentages();
};

const recalculatePercentages = () => {
  const count = distributionConfig.value.length;
  if (count === 0) return;
  const each = Math.floor(100 / count);
  const remainder = 100 - (each * count);
  distributionConfig.value.forEach((config, idx) => {
    config.percentage = each + (idx < remainder ? 1 : 0);
  });
};

const updateAgentPercentage = (agentId, percentage) => {
  const config = distributionConfig.value.find(d => d.agentId === agentId);
  if (config) {
    config.percentage = Math.max(0, Math.min(100, Number(percentage) || 0));
  }
};

const totalDistributionPercentage = computed(() => {
  return distributionConfig.value.reduce((acc, d) => acc + d.percentage, 0);
});

const distributeToAgents = async () => {
  if (distributionConfig.value.length === 0) {
    alert(t('KANBAN.DISTRIBUTE.NO_AGENTS'));
    return;
  }

  if (totalDistributionPercentage.value !== 100) {
    alert(t('KANBAN.DISTRIBUTE.INVALID_PERCENTAGE'));
    return;
  }

  isDistributing.value = true;

  // Pegar todos os deals selecionados
  const selectedDealsList = [];
  STAGES.value.forEach(stage => {
    (state[stage]?.items || []).forEach(deal => {
      if (selectedDeals.value.has(deal.id)) {
        selectedDealsList.push(deal);
      }
    });
  });

  if (selectedDealsList.length === 0) {
    alert(t('KANBAN.DISTRIBUTE.NO_DEALS'));
    isDistributing.value = false;
    return;
  }

  // Embaralhar para distribuição aleatória
  const shuffled = [...selectedDealsList].sort(() => Math.random() - 0.5);

  // Calcular quantos deals para cada agente
  const distribution = [];
  let startIdx = 0;

  distributionConfig.value.forEach((config, idx) => {
    const count = idx === distributionConfig.value.length - 1
      ? shuffled.length - startIdx
      : Math.round(shuffled.length * (config.percentage / 100));

    const dealsForAgent = shuffled.slice(startIdx, startIdx + count);
    distribution.push({
      agentId: config.agentId,
      agentName: config.agentName,
      deals: dealsForAgent,
    });
    startIdx += count;
  });

  // Atribuir agentes aos deals
  let successCount = 0;
  let errorCount = 0;

  for (const group of distribution) {
    for (const deal of group.deals) {
      try {
        await DealsAPI.update(deal.id, { deal: { assignee_id: group.agentId } });

        // Atualizar o assignee no estado local
        STAGES.value.forEach(stage => {
          const dealInState = state[stage].items.find(d => d.id === deal.id);
          if (dealInState) {
            dealInState.meta = {
              ...dealInState.meta,
              assignee: {
                name: group.agentName,
                thumbnail: '',
              },
            };
          }
        });

        successCount++;
      } catch (e) {
        errorCount++;
      }
    }
  }

  selectedDeals.value = new Set();
  showDistributeModal.value = false;
  isDistributing.value = false;

  if (errorCount > 0) {
    alert(t('KANBAN.DISTRIBUTE.PARTIAL_SUCCESS', { success: successCount, failed: errorCount }));
  } else {
    alert(t('KANBAN.DISTRIBUTE.SUCCESS', { count: successCount }));
  }
};

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

const openStartConversationModal = (deal, event) => {
  event.stopPropagation(); // Prevenir que abra os detalhes do deal
  console.log('=== DEBUG CONTACT ===');
  console.log('Deal completo:', deal);
  console.log('Deal.contact:', deal.contact);
  console.log('Deal.contact.id:', deal.contact?.id);
  
  if (!deal.contact?.id) {
    alert('Erro: Contato não encontrado no deal');
    return;
  }
  
  selectedDealForConversation.value = deal;
  showStartConversationModal.value = true;
};

const openContactView = (deal, event) => {
  event.stopPropagation(); // Prevenir que abra os detalhes do deal
  
  if (!deal.contact?.id) {
    alert(t('KANBAN.ALERTS.CONTACT_NOT_FOUND'));
    return;
  }
  
  // Redirecionar para a página de contatos com o contato específico aberto
  router.push(`/app/accounts/${store.getters.getCurrentAccountId}/contacts/${deal.contact.id}`);
};

const handleConversationCreated = (conversationId) => {
  // Atualizar o _conversationId no estado local do deal
  if (selectedDealForConversation.value) {
    const dealId = selectedDealForConversation.value.id;
    const stageKey = selectedDealForConversation.value.custom_attributes?.deal_stage;

    if (stageKey && state[stageKey]) {
      const dealIndex = state[stageKey].items.findIndex(d => d.id === dealId);
      if (dealIndex !== -1) {
        state[stageKey].items[dealIndex]._conversationId = conversationId;
      }
    }
  }

  showStartConversationModal.value = false;
  selectedDealForConversation.value = null;
  // Redirecionar para a nova conversa
  router.push(accountScopedRoute(`conversations/${conversationId}`));
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
        <button
          class="inline-flex items-center justify-center rounded-md border px-3 py-2 h-9 text-sm font-medium transition"
          :class="selectionMode
            ? 'border-n-blue-9 bg-n-blue-9 text-white hover:bg-n-blue-10'
            : 'border-n-strong bg-n-solid-1 text-n-slate-12 hover:bg-n-solid-2'"
          type="button"
          @click="toggleSelectionMode"
        >
          <span class="i-lucide-check-square mr-2 size-4" />
          {{ selectionMode ? t('KANBAN.BATCH.EXIT_SELECTION') : t('KANBAN.BATCH.SELECT') }}
        </button>
      </div>
    </header>

    <!-- Barra de ações em lote -->
    <div
      v-if="selectionMode"
      class="flex flex-col gap-3 rounded-lg bg-n-solid-2 px-4 py-3 ring-1 ring-n-alpha-2"
    >
      <!-- Linha 1: Seleção por etapa e porcentagem -->
      <div class="flex flex-wrap items-center gap-3">
        <span class="text-sm font-medium text-n-slate-11">{{ t('KANBAN.BATCH.SELECT_FROM') }}:</span>
        <select
          v-model="selectedStageForSelection"
          class="rounded-md border border-n-alpha-3 bg-n-solid-1 px-2 py-1.5 text-sm text-n-slate-12"
        >
          <option value="all">{{ t('KANBAN.BATCH.ALL_STAGES') }} ({{ allDealsCount }})</option>
          <option v-for="stage in STAGES" :key="stage" :value="stage">
            {{ columnTitle(stage) }} ({{ getStageDealsCount(stage) }})
          </option>
        </select>
        <div class="flex items-center gap-1">
          <button
            class="rounded-md bg-n-solid-3 px-2 py-1 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-3 transition"
            type="button"
            @click="selectAllFromStage(selectedStageForSelection)"
          >
            100%
          </button>
          <button
            class="rounded-md bg-n-solid-3 px-2 py-1 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-3 transition"
            type="button"
            @click="selectByPercentage(50, selectedStageForSelection)"
          >
            50%
          </button>
          <button
            class="rounded-md bg-n-solid-3 px-2 py-1 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-3 transition"
            type="button"
            @click="selectByPercentage(25, selectedStageForSelection)"
          >
            25%
          </button>
        </div>
        <button
          v-if="selectedDealsCount > 0"
          class="text-sm font-medium text-n-slate-11 hover:underline"
          type="button"
          @click="deselectAllDeals"
        >
          {{ t('KANBAN.BATCH.DESELECT_ALL') }}
        </button>
      </div>

      <!-- Linha 2: Contador e ações -->
      <div class="flex items-center justify-between">
        <span class="text-sm font-semibold text-n-slate-12">
          {{ t('KANBAN.BATCH.SELECTED_COUNT', { count: selectedDealsCount }) }}
        </span>
        <div class="flex items-center gap-2">
          <button
            class="inline-flex items-center justify-center rounded-md border border-n-brand bg-n-brand px-3 py-2 h-9 text-sm font-medium text-white transition hover:bg-n-blue-10 disabled:opacity-50 disabled:cursor-not-allowed"
            type="button"
            :disabled="selectedDealsCount === 0 || isDistributing"
            @click="openDistributeModal"
          >
            <span class="i-lucide-users mr-2 size-4" />
            {{ t('KANBAN.DISTRIBUTE.BUTTON') }}
          </button>
          <button
            class="inline-flex items-center justify-center rounded-md border border-n-ruby-9 bg-n-ruby-9 px-3 py-2 h-9 text-sm font-medium text-white transition hover:bg-n-ruby-10 disabled:opacity-50 disabled:cursor-not-allowed"
            type="button"
            :disabled="selectedDealsCount === 0 || isDeletingBatch"
            @click="deleteSelectedDeals"
          >
            <span v-if="isDeletingBatch" class="i-lucide-loader-2 mr-2 size-4 animate-spin" />
            <span v-else class="i-lucide-trash-2 mr-2 size-4" />
            {{ t('KANBAN.BATCH.DELETE_SELECTED') }}
          </button>
        </div>
      </div>
    </div>

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
            <div class="flex items-center gap-2">
              <template v-if="selectionMode && state[stage].items.length > 0">
                <button
                  type="button"
                  class="text-[11px] font-medium text-n-brand hover:underline"
                  @click="selectAllFromStage(stage)"
                >
                  {{ t('KANBAN.BATCH.SELECT_ALL') }}
                </button>
                <span class="text-n-alpha-6">|</span>
                <button
                  type="button"
                  class="text-[11px] font-medium text-n-slate-11 hover:underline"
                  @click="deselectAllFromStage(stage)"
                >
                  {{ t('KANBAN.BATCH.DESELECT_ALL') }}
                </button>
              </template>
              <div class="inline-flex items-center justify-center rounded-full bg-n-solid-2 text-n-slate-12 size-6 text-xs font-semibold">
                {{ state[stage].items.length }}
              </div>
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
            <!-- Linha superior: checkbox + tag de etapa + avatar fantasma -->
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <!-- Checkbox de seleção em lote -->
                <button
                  v-if="selectionMode"
                  type="button"
                  class="flex items-center justify-center size-5 rounded border transition-colors"
                  :class="isDealSelected(deal.id)
                    ? 'bg-n-blue-9 border-n-blue-9 text-white'
                    : 'bg-n-solid-1 border-n-alpha-3 hover:border-n-blue-9'"
                  @click="toggleDealSelection(deal.id, $event)"
                >
                  <span v-if="isDealSelected(deal.id)" class="i-lucide-check size-3" />
                </button>
                <div class="inline-flex items-center gap-1 rounded-full bg-n-solid-1 px-2 py-0.5 text-[11px] font-medium text-n-slate-11 ring-1 ring-n-alpha-1">
                  <span :class="['i-lucide-flag', 'size-3', stageBadgeIconColor(stage)]" />
                  {{ columnTitle(stage) }}
                </div>
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

            <!-- DEBUG: Mostrar dados do deal -->
            <div v-if="false" class="text-[8px] text-n-slate-11 mt-1">
              Contact: {{ deal.contact?.name }} | Labels: {{ deal.contact?.label_list }}
            </div>

            <!-- Etiquetas do contato -->
            <div
              v-if="deal.contact?.label_list && deal.contact.label_list.length > 0"
              class="flex flex-wrap gap-1 mt-1"
            >
              <span
                v-for="label in deal.contact.label_list"
                :key="label"
                class="inline-flex items-center rounded-full bg-n-solid-3 px-2 py-0.5 text-[10px] font-medium text-n-slate-11 ring-1 ring-n-alpha-1"
              >
                {{ label }}
              </span>
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
              <div class="flex items-center gap-2 flex-wrap">
                <!-- Botao de ver contato -->
                <button
                  v-if="deal.contact?.id"
                  type="button"
                  class="flex items-center gap-1 rounded-md px-2 py-1 text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors text-xs"
                  :title="$t('KANBAN.VIEW_CONTACT')"
                  @click.stop="openContactView(deal, $event)"
                >
                  <span class="i-lucide-user size-3.5" />
                  <span>Ver Contato</span>
                </button>
                <!-- Botao de iniciar conversa (se nao tiver conversa) -->
                <button
                  v-if="!deal._conversationId"
                  type="button"
                  class="flex items-center gap-1 rounded-md px-2 py-1 text-n-brand hover:bg-n-alpha-2 hover:text-n-brand transition-colors font-medium text-xs"
                  :title="$t('KANBAN.START_CONVERSATION')"
                  @click.stop="openStartConversationModal(deal, $event)"
                >
                  <span class="i-lucide-message-square-plus size-3.5" />
                  <span>Iniciar Conversa</span>
                </button>
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
      :default-pipeline-id="selectedPipelineId"
      :default-stage-id="pipelineStages[0]?.id"
      :default-pipeline-name="pipelines.find(p => p.id === selectedPipelineId)?.name"
      :default-stage-name="pipelineStages[0]?.name"
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
    <StartConversationModal
      v-if="showStartConversationModal && selectedDealForConversation"
      :show="showStartConversationModal"
      :contact-id="String(selectedDealForConversation.contact?.id || '')"
      :contact="selectedDealForConversation.contact"
      :deal-id="selectedDealForConversation.id"
      @close="showStartConversationModal = false; selectedDealForConversation = null"
      @conversation-created="handleConversationCreated"
    />

    <!-- Modal de Distribuição para Agentes -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition-opacity duration-200"
        leave-active-class="transition-opacity duration-200"
        enter-from-class="opacity-0"
        leave-to-class="opacity-0"
      >
        <div
          v-if="showDistributeModal"
          class="fixed inset-0 z-[9998] flex items-center justify-center bg-black/50"
          @click.self="showDistributeModal = false"
        >
          <div class="w-full max-w-lg rounded-xl bg-n-solid-1 p-6 shadow-xl ring-1 ring-n-alpha-2">
            <div class="mb-4 flex items-center justify-between">
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{ t('KANBAN.DISTRIBUTE.TITLE') }}
              </h2>
              <button
                type="button"
                class="rounded-md p-1 text-n-slate-11 hover:bg-n-alpha-2"
                @click="showDistributeModal = false"
              >
                <span class="i-lucide-x size-5" />
              </button>
            </div>

            <p class="mb-4 text-sm text-n-slate-11">
              {{ t('KANBAN.DISTRIBUTE.DESCRIPTION', { count: selectedDealsCount }) }}
            </p>

            <!-- Seletor de Agente -->
            <div class="mb-4">
              <label class="mb-1 block text-sm font-medium text-n-slate-12">
                {{ t('KANBAN.DISTRIBUTE.ADD_AGENT') }}
              </label>
              <select
                class="w-full rounded-md border border-n-alpha-3 bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12"
                @change="addAgentToDistribution($event.target.value); $event.target.value = ''"
              >
                <option value="">{{ t('KANBAN.DISTRIBUTE.SELECT_AGENT') }}</option>
                <option
                  v-for="agent in agents"
                  :key="agent.id"
                  :value="agent.id"
                  :disabled="distributionConfig.find(d => d.agentId === agent.id)"
                >
                  {{ agent.name }}
                </option>
              </select>
            </div>

            <!-- Lista de Agentes Selecionados -->
            <div v-if="distributionConfig.length > 0" class="mb-4 space-y-2">
              <div
                v-for="config in distributionConfig"
                :key="config.agentId"
                class="flex items-center gap-3 rounded-lg bg-n-solid-2 p-3 ring-1 ring-n-alpha-2"
              >
                <Avatar :name="config.agentName" :size="32" rounded-full />
                <div class="flex-1">
                  <span class="text-sm font-medium text-n-slate-12">{{ config.agentName }}</span>
                </div>
                <div class="flex items-center gap-2">
                  <input
                    type="number"
                    min="0"
                    max="100"
                    :value="config.percentage"
                    class="w-16 rounded-md border border-n-alpha-3 bg-n-solid-1 px-2 py-1 text-center text-sm text-n-slate-12"
                    @input="updateAgentPercentage(config.agentId, $event.target.value)"
                  />
                  <span class="text-sm text-n-slate-11">%</span>
                  <button
                    type="button"
                    class="rounded-md p-1 text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-red-9"
                    @click="removeAgentFromDistribution(config.agentId)"
                  >
                    <span class="i-lucide-trash-2 size-4" />
                  </button>
                </div>
              </div>
            </div>

            <!-- Total e Aviso -->
            <div v-if="distributionConfig.length > 0" class="mb-4">
              <div class="flex items-center justify-between text-sm">
                <span class="text-n-slate-11">{{ t('KANBAN.DISTRIBUTE.TOTAL') }}:</span>
                <span
                  :class="totalDistributionPercentage === 100 ? 'text-n-green-9' : 'text-n-red-9'"
                  class="font-semibold"
                >
                  {{ totalDistributionPercentage }}%
                </span>
              </div>
              <p v-if="totalDistributionPercentage !== 100" class="mt-1 text-xs text-n-red-9">
                {{ t('KANBAN.DISTRIBUTE.MUST_BE_100') }}
              </p>
            </div>

            <!-- Botões -->
            <div class="flex items-center justify-end gap-2">
              <button
                type="button"
                class="rounded-md border border-n-alpha-3 bg-n-solid-2 px-4 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-solid-3"
                @click="showDistributeModal = false"
              >
                {{ t('KANBAN.DISTRIBUTE.CANCEL') }}
              </button>
              <button
                type="button"
                class="rounded-md bg-n-brand px-4 py-2 text-sm font-medium text-white hover:bg-n-blue-10 disabled:opacity-50 disabled:cursor-not-allowed"
                :disabled="distributionConfig.length === 0 || totalDistributionPercentage !== 100 || isDistributing"
                @click="distributeToAgents"
              >
                <span v-if="isDistributing" class="i-lucide-loader-2 mr-2 inline-block size-4 animate-spin" />
                {{ t('KANBAN.DISTRIBUTE.CONFIRM') }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

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

