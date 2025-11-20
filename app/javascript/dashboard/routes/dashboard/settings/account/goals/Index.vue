<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import GoalsAPI from 'dashboard/api/goals';
import AgentsAPI from 'dashboard/api/agents';
import TeamsAPI from 'dashboard/api/teams';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';

const { t } = useI18n();
const { accountId } = useAccount();
const alert = useAlert();
const store = useStore();

const loading = ref(false);
const goals = ref([]);
const progressMap = ref({});
const agents = ref([]);
const teams = ref([]);

// Form state
const showModal = ref(false);
const form = ref({
  title: '',
  scopeType: 'user',
  scopeId: null,
  metric: 'count',
  targetNumber: 1,
  targetAmount: null,
  startDate: '',
  endDate: '',
  notes: '',
});

const canSubmit = computed(() => {
  if (!form.value.title || !form.value.scopeType || !form.value.startDate || !form.value.endDate) return false;
  if (!form.value.scopeId) return false;
  if (form.value.metric === 'count') return !!form.value.targetNumber;
  if (form.value.metric === 'amount') return !!form.value.targetAmount;
  return true;
});

const load = async () => {
  loading.value = true;
  try {
    const { data: goalsData } = await GoalsAPI.get();
    goals.value = goalsData || [];
    // prefetch progress (best effort)
    const entries = await Promise.all(
      (goals.value || []).map(async g => {
        try {
          const { data } = await GoalsAPI.progress(g.id);
          return [g.id, data];
        } catch (e) {
          return [g.id, null];
        }
      })
    );
    progressMap.value = Object.fromEntries(entries);
    // load agents and teams for form selects
    // Carregar usuários e times
    const [agentsRes] = await Promise.all([AgentsAPI.get()]);
    let agentsList = agentsRes?.data || [];
    // Teams via store (fonte única usada no app todo)
    await store.dispatch('teams/get');
    let teamsList = store.getters['teams/getTeams'] || [];
    if (!Array.isArray(teamsList) || teamsList.length === 0) {
      // fallback via API (cache/network)
      try {
        const fallback = await TeamsAPI.get(true);
        teamsList = fallback?.data || [];
      } catch {
        // ignore
      }
    }
    // Fallback via store se vazio
    if (!Array.isArray(agentsList) || agentsList.length === 0) {
      await store.dispatch('agents/get');
      agentsList = store.getters['agents/getAgents'] || [];
    }
    if (!Array.isArray(teamsList) || teamsList.length === 0) {
      await store.dispatch('teams/get');
      // teams store getter não existe aqui; reaproveitar TeamsAPI cacheado
      // mantém teamsList como estava
    }
    // Inclui o admin atual caso não venha pelo endpoint de agents
    const currentUser = store.getters['auth/getCurrentUser'] || {};
    const currentRole = store.getters['auth/getCurrentRole'];
    const hasCurrent = agentsList.some(u => u.id === currentUser.id);
    if (currentUser.id && !hasCurrent) {
      agentsList.unshift({
        id: currentUser.id,
        name: `${currentUser.name} (você${currentRole === 'administrator' ? ' • admin' : ''})`,
      });
    }
    agents.value = agentsList;
    teams.value = teamsList;
  } finally {
    loading.value = false;
  }
};

const openModal = () => {
  showModal.value = true;
};

const resetForm = () => {
  form.value = {
    title: '',
    scopeType: 'user',
    scopeId: null,
    metric: 'count',
    targetNumber: 1,
    targetAmount: null,
    startDate: '',
    endDate: '',
    notes: '',
  };
};

const createGoal = async () => {
  if (!canSubmit.value) return;
  const payload = {
    title: form.value.title,
    notes: form.value.notes || null,
    scope_type: form.value.scopeType,
    scope_id: form.value.scopeId,
    metric: form.value.metric,
    target_number: form.value.metric === 'count' ? Number(form.value.targetNumber) : null,
    target_amount: form.value.metric === 'amount' ? Number(form.value.targetAmount) : null,
    start_date: form.value.startDate,
    end_date: form.value.endDate,
  };
  await GoalsAPI.create({ goal: payload });
  showModal.value = false;
  resetForm();
  await load();
  alert(t('GENERAL_SETTINGS.CREATE.SUCCESS'));
};

const removeGoal = async goal => {
  await GoalsAPI.delete(goal.id);
  await load();
  alert(t('LABEL_MGMT.DELETE.SUCCESS'));
};

onMounted(load);

// Ensure teams list when user switches to team scope
watch(
  () => form.value.scopeType,
  async val => {
    if (val === 'team' && (!teams.value || teams.value.length === 0)) {
      try {
        await store.dispatch('teams/get');
        let list = store.getters['teams/getTeams'] || [];
        if (!Array.isArray(list) || list.length === 0) {
          const fb = await TeamsAPI.get(true);
          list = fb?.data || [];
        }
        teams.value = list;
      } catch {
        // ignore
      }
    }
  }
);
</script>

<template>
  <div class="flex flex-col max-w-5xl mx-auto w-full">
    <BaseSettingsHeader title="Metas (Goals)" />
    <div class="mt-4 rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
      <div class="flex items-center justify-between">
        <div class="text-sm text-n-slate-11">
          Defina metas por usuário ou time. O progresso é calculado quando negócios entram na etapa “Ganho”.
        </div>
        <button
          class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-solid-2"
          @click="openModal"
        >
          Nova meta
        </button>
      </div>
      <div class="mt-4">
        <div v-if="loading" class="text-sm text-n-slate-11">Carregando…</div>
        <div v-else-if="!goals.length" class="text-sm text-n-slate-11">Nenhuma meta criada.</div>
        <ul v-else class="space-y-3">
          <li
            v-for="g in goals"
            :key="g.id"
            class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3"
          >
            <div class="flex items-center justify-between">
              <div class="text-sm font-medium text-n-slate-12">
                {{ g.title }}
              </div>
              <button
                class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-1 text-xs font-medium text-n-ruby-11 hover:bg-n-ruby-3"
                @click="removeGoal(g)"
              >
                Remover
              </button>
            </div>
            <div class="mt-1 text-xs text-n-slate-11">
              Escopo:
              <span class="font-medium text-n-slate-12">{{ g.scope_type }}</span>
              —
              Métrica:
              <span class="font-medium text-n-slate-12">{{ g.metric }}</span>
              —
              Período:
              <span class="font-medium text-n-slate-12">{{ g.start_date }} → {{ g.end_date }}</span>
            </div>
            <div class="mt-2 text-xs text-n-slate-11">
              <div class="flex items-center justify-between">
                <span>Progresso</span>
                <span class="font-medium text-n-slate-12">
                  <template v-if="progressMap[g.id]">
                    {{ Number(progressMap[g.id].percentage || 0).toFixed(1) }}%
                  </template>
                  <template v-else>0.0%</template>
                </span>
              </div>
              <div class="mt-1 w-full h-2 bg-n-alpha-2 rounded overflow-hidden">
                <div
                  v-if="progressMap[g.id]"
                  class="h-2 bg-green-600 rounded"
                  :style="{ width: Math.min(100, (progressMap[g.id]?.percentage || 0)) + '%' }"
                />
                <div
                  v-else
                  class="h-2 bg-n-alpha-6 animate-pulse rounded"
                  style="width: 40%"
                />
              </div>
              <div class="mt-1">
                <template v-if="progressMap[g.id]">
                  <template v-if="g.metric === 'amount'">
                    {{ new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:0}).format(progressMap[g.id].total || 0) }}
                    de
                    {{ new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:0}).format(progressMap[g.id].target || 0) }}
                  </template>
                  <template v-else>
                    {{ Number(progressMap[g.id].total || 0).toLocaleString('pt-BR') }}
                    de
                    {{ Number(progressMap[g.id].target || 0).toLocaleString('pt-BR') }}
                    negócios
                  </template>
                </template>
                <template v-else>
                  <template v-if="g.metric === 'amount'">
                    {{ new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:0}).format(0) }}
                    de
                    {{ new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:0}).format(g.target_amount || 0) }}
                  </template>
                  <template v-else>
                    0 de {{ Number(g.target_number || 0).toLocaleString('pt-BR') }} negócios
                  </template>
                </template>
              </div>
            </div>
          </li>
        </ul>
      </div>
    </div>

    <!-- Modal Criar Meta -->
    <woot-modal :show="showModal" :on-close="() => (showModal = false)">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header header-title="Nova meta" />
        <div class="px-6 py-4 space-y-3">
          <div>
            <label class="text-sm text-n-slate-12 mb-1 block">Título</label>
            <input
              v-model="form.title"
              type="text"
              class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              placeholder="Ex.: 20 negócios ganhos no mês"
            />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm text-n-slate-12 mb-1 block">Escopo</label>
              <div class="flex items-center gap-3">
                <label class="inline-flex items-center gap-2 text-sm">
                  <input type="radio" value="user" v-model="form.scopeType" />
                  Usuário
                </label>
                <label class="inline-flex items-center gap-2 text-sm">
                  <input type="radio" value="team" v-model="form.scopeType" />
                  Time
                </label>
              </div>
            </div>
            <div>
              <label class="text-sm text-n-slate-12 mb-1 block">Destino</label>
              <select
                v-model="form.scopeId"
                class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              >
                <option :value="null" disabled>Selecione…</option>
                <template v-if="form.scopeType === 'user'">
                  <option v-for="u in agents" :key="u.id" :value="u.id">
                    {{ u.name }}
                  </option>
                </template>
                <template v-else>
                  <option v-for="tm in teams" :key="tm.id" :value="tm.id">
                    {{ tm.name }}
                  </option>
                </template>
              </select>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm text-n-slate-12 mb-1 block">Métrica</label>
              <div class="flex items-center gap-3">
                <label class="inline-flex items-center gap-2 text-sm">
                  <input type="radio" value="count" v-model="form.metric" />
                  Quantidade
                </label>
                <label class="inline-flex items-center gap-2 text-sm">
                  <input type="radio" value="amount" v-model="form.metric" />
                  Valor
                </label>
              </div>
            </div>
            <div v-if="form.metric === 'count'">
              <label class="text-sm text-n-slate-12 mb-1 block">Target (número)</label>
              <input
                v-model.number="form.targetNumber"
                type="number"
                min="1"
                class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              />
            </div>
            <div v-else>
              <label class="text-sm text-n-slate-12 mb-1 block">Target (valor)</label>
              <input
                v-model.number="form.targetAmount"
                type="number"
                min="0"
                step="0.01"
                class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm text-n-slate-12 mb-1 block">Início</label>
              <input
                v-model="form.startDate"
                type="date"
                class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              />
            </div>
            <div>
              <label class="text-sm text-n-slate-12 mb-1 block">Fim</label>
              <input
                v-model="form.endDate"
                type="date"
                class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              />
            </div>
          </div>
          <div>
            <label class="text-sm text-n-slate-12 mb-1 block">Notas (opcional)</label>
            <textarea
              v-model="form.notes"
              rows="3"
              class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
            />
          </div>
        </div>
        <div class="w-full flex justify-end gap-2 items-center px-6 pb-4">
          <button
            type="button"
            class="rounded-md border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            @click="() => (showModal = false)"
          >
            Cancelar
          </button>
          <button
            type="button"
            class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-solid-2 disabled:opacity-50"
            :disabled="!canSubmit"
            @click="createGoal"
          >
            Salvar
          </button>
        </div>
      </div>
    </woot-modal>
  </div>
</template>


