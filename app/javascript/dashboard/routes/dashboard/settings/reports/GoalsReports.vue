<script setup>
import { ref, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import ReportsAPI from 'dashboard/api/reports';
import GoalsAPI from 'dashboard/api/goals';
import PipelinesAPI from 'dashboard/api/pipelines';
import BarChart from 'shared/components/charts/BarChart.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const { t } = useI18n();
const { accountId } = useAccount();

const from = ref(new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10));
const to = ref(new Date().toISOString().slice(0, 10));
const pipelines = ref([]);
const selectedPipelineId = ref(null);
const showPipelineMenu = ref(false);

const userRanking = ref([]);
const teamRanking = ref([]);
const goals = ref([]);
const progressMap = ref({});
const loading = ref(false);

const currencyFormatter = (value, currency = 'BRL') => {
  try {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency,
      maximumFractionDigits: 0,
    }).format(Number(value || 0));
  } catch (e) {
    // fallback simples
    return `R$ ${Number(value || 0).toLocaleString('pt-BR')}`;
  }
};

const loadPipelines = async () => {
  const { data } = await PipelinesAPI.get();
  pipelines.value = data || [];
};

const loadRankings = async () => {
  const paramsBase = {
    from: from.value,
    to: to.value,
    metric: 'amount', // default; pode alternar depois
    pipeline_ids: selectedPipelineId.value ? [selectedPipelineId.value] : [],
  };
  const [usersRes, teamsRes] = await Promise.all([
    ReportsAPI.dealsWon({ ...paramsBase, group_by: 'user' }),
    ReportsAPI.dealsWon({ ...paramsBase, group_by: 'team' }),
  ]);
  userRanking.value = usersRes.data?.data || [];
  teamRanking.value = teamsRes.data?.data || [];
};

const loadGoals = async () => {
  const { data } = await GoalsAPI.get();
  goals.value = data || [];
  const entries = await Promise.all(
    goals.value.map(async g => {
      try {
        const { data: pg } = await GoalsAPI.progress(g.id);
        return [g.id, pg];
      } catch {
        return [g.id, null];
      }
    })
  );
  progressMap.value = Object.fromEntries(entries);
};

const refreshAll = async () => {
  loading.value = true;
  try {
    await Promise.all([loadRankings(), loadGoals()]);
  } finally {
    loading.value = false;
  }
};

onMounted(async () => {
  await loadPipelines();
  await refreshAll();
});

const userChart = computed(() => {
  const labels = userRanking.value.map(r => r.user_name || `#${r.user_id}`);
  const data = userRanking.value.map(r => r.value);
  return {
    labels,
    datasets: [
      {
        type: 'bar',
        label: 'Usuários',
        data,
        backgroundColor: '#6EE7B7',
        borderColor: '#059669',
      },
    ],
  };
});

const teamChart = computed(() => {
  const labels = teamRanking.value.map(r => r.team_name || `#${r.team_id}`);
  const data = teamRanking.value.map(r => r.value);
  return {
    labels,
    datasets: [
      {
        type: 'bar',
        label: 'Times',
        data,
        backgroundColor: '#93C5FD',
        borderColor: '#1D4ED8',
      },
    ],
  };
});
</script>

<template>
  <div class="px-6 py-5 space-y-4">
    <div class="flex items-center gap-3">
      <div>
        <label class="text-xs text-n-slate-11 mb-1 block">De</label>
        <input v-model="from" type="date" class="rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 text-sm h-9 leading-none py-0" />
      </div>
      <div>
        <label class="text-xs text-n-slate-11 mb-1 block">Até</label>
        <input v-model="to" type="date" class="rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 text-sm h-9 leading-none py-0" />
      </div>
      <div>
        <div class="relative inline-block">
          <NextButton
            sm
            slate
            type="button"
            class="!h-9"
            aria-label="Selecionar pipeline"
            :trailing-icon="'i-lucide-chevron-down'"
            :label="(pipelines.find(p => p.id === selectedPipelineId)?.name) || 'Todos os pipelines'"
            @click="showPipelineMenu = !showPipelineMenu"
          />
          <DropdownMenu
            v-if="showPipelineMenu"
            class="absolute z-50 mt-1 min-w-48"
            :menu-items="[{ label: 'Todos os pipelines', action: 'select', value: null }, ...(pipelines || []).map(p => ({ label: p.name, action: 'select', value: p.id }))]"
            @action="async ({ value }) => {
              showPipelineMenu = false;
              selectedPipelineId = value ? Number(value) : null;
              await refreshAll();
            }"
          />
        </div>
      </div>
      <button
        class="rounded-md border border-n-strong bg-n-solid-1 px-3 text-sm font-medium text-n-slate-12 hover:bg-n-solid-2 h-9 leading-none"
        @click="refreshAll"
      >
        Atualizar
      </button>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
        <div class="text-sm font-medium text-n-slate-12 mb-2">Ranking por usuários (ganhos)</div>
        <div class="h-72 flex items-center justify-center">
          <woot-loading-state v-if="loading" class="text-xs" message="Carregando…" />
          <BarChart v-else :collection="userChart" />
        </div>
      </div>
      <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
        <div class="text-sm font-medium text-n-slate-12 mb-2">Ranking por times (ganhos)</div>
        <div class="h-72 flex items-center justify-center">
          <woot-loading-state v-if="loading" class="text-xs" message="Carregando…" />
          <BarChart v-else :collection="teamChart" />
        </div>
      </div>
    </div>

    <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
      <div class="text-sm font-medium text-n-slate-12 mb-3">Metas ativas</div>
      <div v-if="!goals.length" class="text-sm text-n-slate-11">Nenhuma meta ativa.</div>
      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        <div
          v-for="g in goals"
          :key="g.id"
          class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3"
        >
          <div class="text-sm font-medium text-n-slate-12">{{ g.title }}</div>
          <div class="text-xs text-n-slate-11">
            {{ g.scope_type }} • {{ g.metric }} • {{ g.start_date }} → {{ g.end_date }}
          </div>
          <div class="mt-2 text-xs">
            <template v-if="progressMap[g.id]">
              <div class="flex items-center justify-between text-n-slate-11">
                <span>Progresso</span>
                <span class="font-medium text-n-slate-12">{{ Number(progressMap[g.id].percentage || 0).toFixed(1) }}%</span>
              </div>
              <div class="mt-1 w-full h-2 bg-n-alpha-2 rounded overflow-hidden">
                <div
                  v-if="progressMap[g.id]"
                  class="h-2 bg-green-600 rounded"
                  :style="{ width: Math.min(100, progressMap[g.id].percentage || 0) + '%' }"
                />
                <div
                  v-else
                  class="h-2 bg-n-alpha-6 animate-pulse rounded"
                  style="width: 40%"
                />
              </div>
              <div class="mt-1 text-n-slate-11">
                <template v-if="g.metric === 'amount'">
                  {{ currencyFormatter(progressMap[g.id].total) }} de {{ currencyFormatter(progressMap[g.id].target) }}
                </template>
                <template v-else>
                  {{ Number(progressMap[g.id].total || 0).toLocaleString('pt-BR') }} de {{ Number(progressMap[g.id].target || 0).toLocaleString('pt-BR') }} negócios
                </template>
              </div>
            </template>
            <div v-else>
              <div class="flex items-center justify-between text-n-slate-11">
                <span>Progresso</span>
                <span class="font-medium text-n-slate-12">0.0%</span>
              </div>
              <div class="mt-1 w-full h-2 bg-n-alpha-2 rounded">
                <div class="h-2 bg-grass-9 rounded" style="width: 0%" />
              </div>
              <div class="mt-1 text-n-slate-11">
                <template v-if="g.metric === 'amount'">
                  {{ currencyFormatter(0) }} de {{ currencyFormatter(g.target_amount || 0) }}
                </template>
                <template v-else>
                  {{ Number(0).toLocaleString('pt-BR') }} de {{ Number(g.target_number || 0).toLocaleString('pt-BR') }} negócios
                </template>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>


