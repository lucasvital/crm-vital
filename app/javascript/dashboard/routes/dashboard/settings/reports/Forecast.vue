<script setup>
import { ref, onMounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import ForecastsAPI from 'dashboard/api/forecasts';
import NextButton from 'dashboard/components-next/button/Button.vue';
import BarChart from 'shared/components/charts/BarChart.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const { t } = useI18n();

const loading = ref(false);
const generating = ref(false);
const generationProgress = ref(0);
const metrics = ref(null);
const forecast = ref(null);
const error = ref('');
const nextAllowedAt = ref('');
const showHistory = ref(false);
const history = ref([]);
const selectedPeriod = ref('monthly');

const currencyBRL = v => {
  try {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(Number(v || 0));
  } catch {
    return `R$ ${Number(v || 0).toLocaleString('pt-BR')}`;
  }
};

const loadMetrics = async () => {
  loading.value = true;
  error.value = '';
  try {
    const { data } = await ForecastsAPI.metrics();
    metrics.value = data;
  } catch (e) {
    error.value = 'Erro ao buscar métricas';
  } finally {
    loading.value = false;
  }
};

const generateForecast = async () => {
  generating.value = true;
  error.value = '';
  forecast.value = null;
  generationProgress.value = 0;
  const timer = setInterval(() => {
    generationProgress.value = Math.min(generationProgress.value + 8, 92);
  }, 800);
  try {
    const { data } = await ForecastsAPI.generate();
    forecast.value = data;
    await loadHistory();
  } catch (e) {
    error.value = e?.response?.data?.error || 'Erro ao gerar previsão';
    nextAllowedAt.value = e?.response?.data?.next_allowed_at || '';
    if (!forecast.value) {
      try {
        const { data } = await ForecastsAPI.latest();
        if (data && Object.keys(data).length) {
          forecast.value = data;
        }
      } catch {}
    }
  } finally {
    clearInterval(timer);
    generationProgress.value = 100;
    generating.value = false;
  }
};

onMounted(async () => {
  await loadMetrics();
  await loadHistory();
  try {
    const { data } = await ForecastsAPI.latest();
    if (data && Object.keys(data).length) {
      forecast.value = data;
    }
  } catch {}
});

const weeklyChart = computed(() => {
  const labels = (forecast.value?.weekly_forecast || []).map(w => w.week);
  const expected = (forecast.value?.weekly_forecast || []).map(w => Number(w.expected_revenue || 0));
  const conservative = (forecast.value?.weekly_forecast || []).map(w => Number(w.conservative_revenue || 0));
  const optimistic = (forecast.value?.weekly_forecast || []).map(w => Number(w.optimistic_revenue || 0));
  return {
    labels,
    datasets: [
      { type: 'bar', label: 'Esperado', data: expected, backgroundColor: '#3b82f6' },
      { type: 'bar', label: 'Conservador', data: conservative, backgroundColor: '#f59e0b' },
      { type: 'bar', label: 'Otimista', data: optimistic, backgroundColor: '#10b981' },
    ],
  };
});

const monthlyChart = computed(() => {
  const labels = (forecast.value?.monthly_forecast || []).map(m => m.month);
  const expected = (forecast.value?.monthly_forecast || []).map(m => Number(m.expected_revenue || 0));
  const conservative = (forecast.value?.monthly_forecast || []).map(m => Number(m.conservative_revenue || 0));
  const optimistic = (forecast.value?.monthly_forecast || []).map(m => Number(m.optimistic_revenue || 0));
  return {
    labels,
    datasets: [
      { type: 'bar', label: 'Esperado', data: expected, backgroundColor: '#3b82f6' },
      { type: 'bar', label: 'Conservador', data: conservative, backgroundColor: '#f59e0b' },
      { type: 'bar', label: 'Otimista', data: optimistic, backgroundColor: '#10b981' },
    ],
  };
});

const monthlyTotals = computed(() => {
  const m = forecast.value?.monthly_forecast || [];
  const expected = m.reduce((s, x) => s + Number(x.expected_revenue || 0), 0);
  const optimistic = m.reduce((s, x) => s + Number(x.optimistic_revenue || 0), 0);
  const conservative = m.reduce((s, x) => s + Number(x.conservative_revenue || 0), 0);
  const deals = m.reduce((s, x) => s + Number(x.expected_deals_closed || 0), 0);
  const avgMonthly = m.length ? expected / m.length : 0;
  return { expected, optimistic, conservative, deals, avgMonthly };
});

const stagesChart = computed(() => {
  const map = metrics.value?.deals_by_stage || {};
  const labels = Object.keys(map);
  const values = labels.map(k => Number(map[k] || 0));
  return {
    labels,
    datasets: [{ type: 'bar', label: 'Distribuição por estágio', data: values, backgroundColor: '#64748b' }],
  };
});

const scenario = computed(() => {
  const e = monthlyTotals.value.expected || 0;
  const o = monthlyTotals.value.optimistic || 0;
  const c = monthlyTotals.value.conservative || 0;
  const deals = monthlyTotals.value.deals || 0;
  const percUp = e > 0 ? ((o - e) / e) * 100 : 0;
  const percDown = e > 0 ? ((e - c) / e) * 100 : 0;
  return {
    optimistic: { total: o, deals: Math.round(deals * 1.3), probability: 30, diffVsExpected: percUp },
    expected: { total: e, deals: Math.round(deals), probability: 50, diffVsExpected: 0 },
    conservative: { total: c, deals: Math.round(deals * 0.7), probability: 20, diffVsExpected: -percDown },
    analysis: {
      variation: o - c,
      riskMargin: e - c,
      potentialGain: o - e,
    },
  };
});

const nextAllowedComputed = computed(() => {
  if (nextAllowedAt.value) return new Date(nextAllowedAt.value);
  const created = forecast.value?.created_at ? new Date(forecast.value.created_at) : null;
  return created ? new Date(created.getTime() + 7 * 24 * 60 * 60 * 1000) : null;
});

const canGenerate = computed(() => {
  if (!nextAllowedComputed.value) return true;
  return new Date() >= nextAllowedComputed.value;
});
</script>

<template>
  <div class="p-6 space-y-6">
    <div class="flex items-center justify-between">
      <div class="text-lg font-semibold text-n-slate-12">Previsão de Vendas</div>
      <div class="flex items-center gap-3">
        <div v-if="nextAllowedComputed" class="text-xs text-n-slate-11">
          Próxima geração: {{ nextAllowedComputed.toLocaleString('pt-BR') }}
        </div>
        <NextButton :label="'Gerar previsão'" :loading="generating" :disabled="!canGenerate" @click="generateForecast" />
      </div>
    </div>

    <div v-if="error" class="rounded-lg border border-red-300 bg-red-50 text-red-900 p-3 text-sm">
      <div>{{ error }}</div>
      <div v-if="nextAllowedAt" class="text-xs">Próxima geração permitida: {{ new Date(nextAllowedAt).toLocaleString('pt-BR') }}</div>
    </div>

    <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
      <div class="text-sm font-medium text-n-slate-12 mb-2">Métricas do pipeline</div>
      <woot-loading-state v-if="loading" class="text-xs" message="Carregando…" />
      <div v-else-if="!forecast && generating" class="space-y-3">
        <div class="flex items-center justify-center gap-2 text-sm text-n-slate-12">
          <span class="i-lucide-loader-2 animate-spin" />
          <span>Analisando pipeline…</span>
        </div>
        <div class="w-full bg-n-alpha-2 rounded-full h-2 overflow-hidden">
          <div class="bg-n-strong h-full transition-all duration-700 ease-out" :style="{ width: generationProgress + '%' }" />
        </div>
        <div class="text-xs text-n-slate-11">{{ generationProgress }}% — pode levar até 30 segundos</div>
      </div>
      <div v-else-if="metrics" class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Negócios</div>
          <div class="text-base font-semibold text-n-slate-12">{{ metrics.total_deals }}</div>
        </div>
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Valor total</div>
          <div class="text-base font-semibold text-n-slate-12">{{ currencyBRL(metrics.total_pipeline_value) }}</div>
        </div>
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Ativo no pipeline</div>
          <div class="text-base font-semibold text-n-slate-12">{{ currencyBRL(metrics.active_pipeline_value) }}</div>
        </div>
      </div>
    </div>

    <div v-if="forecast" class="space-y-4">
      <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
        <div class="text-sm font-medium text-n-slate-12 mb-2">Resumo</div>
        <div class="text-sm text-n-slate-12">{{ forecast.summary }}</div>
        <div class="text-xs text-n-slate-11 mt-1">Confiança: {{ forecast.confidence_level }}%</div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Receita Esperada (3 meses)</div>
          <div class="text-base font-semibold text-n-slate-12">{{ currencyBRL(monthlyTotals.expected) }}</div>
        </div>
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Potencial Otimista</div>
          <div class="text-base font-semibold text-n-slate-12">{{ currencyBRL(monthlyTotals.optimistic) }}</div>
        </div>
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Risco Conservador</div>
          <div class="text-base font-semibold text-n-slate-12">{{ currencyBRL(monthlyTotals.conservative) }}</div>
        </div>
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Negócios Esperados</div>
          <div class="text-base font-semibold text-n-slate-12">{{ Number(monthlyTotals.deals || 0).toLocaleString('pt-BR') }}</div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
          <div class="flex items-center justify-between mb-1">
            <div class="text-sm font-medium text-n-slate-12">Otimista</div>
            <div class="text-xs text-n-slate-11">{{ scenario.optimistic.probability }}%</div>
          </div>
          <div class="text-xl font-semibold text-n-slate-12">{{ currencyBRL(scenario.optimistic.total) }}</div>
          <div class="text-xs text-n-slate-11">Próximos 3 meses • {{ scenario.optimistic.deals }} negócios</div>
          <div class="text-xs text-n-slate-11 mt-1">{{ Number(scenario.optimistic.diffVsExpected).toFixed(0) }}% vs. esperado</div>
        </div>
        <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
          <div class="flex items-center justify-between mb-1">
            <div class="text-sm font-medium text-n-slate-12">Esperado</div>
            <div class="text-xs text-n-slate-11">{{ scenario.expected.probability }}%</div>
          </div>
          <div class="text-xl font-semibold text-n-slate-12">{{ currencyBRL(scenario.expected.total) }}</div>
          <div class="text-xs text-n-slate-11">Próximos 3 meses • {{ scenario.expected.deals }} negócios</div>
          <div class="text-xs text-n-slate-11 mt-1">0% vs. esperado</div>
        </div>
        <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
          <div class="flex items-center justify-between mb-1">
            <div class="text-sm font-medium text-n-slate-12">Conservador</div>
            <div class="text-xs text-n-slate-11">{{ scenario.conservative.probability }}%</div>
          </div>
          <div class="text-xl font-semibold text-n-slate-12">{{ currencyBRL(scenario.conservative.total) }}</div>
          <div class="text-xs text-n-slate-11">Próximos 3 meses • {{ scenario.conservative.deals }} negócios</div>
          <div class="text-xs text-n-slate-11 mt-1">{{ Number(scenario.conservative.diffVsExpected).toFixed(0) }}% vs. esperado</div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
          <div class="text-sm font-medium text-n-slate-12 mb-2">Principais Insights</div>
          <div v-if="!forecast.key_insights?.length" class="text-xs text-n-slate-11">Sem insights.</div>
          <ul v-else class="space-y-2">
            <li v-for="k in forecast.key_insights" :key="k" class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3 text-sm text-n-slate-12">{{ k }}</li>
          </ul>
        </div>
        <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
          <div class="text-sm font-medium text-n-slate-12 mb-2">Recomendações</div>
          <div v-if="!forecast.recommendations?.length" class="text-xs text-n-slate-11">Sem recomendações.</div>
          <ul v-else class="space-y-2">
            <li v-for="r in forecast.recommendations" :key="r" class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3 text-sm text-n-slate-12">{{ r }}</li>
          </ul>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Média Mensal</div>
          <div class="text-base font-semibold text-n-slate-12">{{ currencyBRL(monthlyTotals.avgMonthly) }}</div>
        </div>
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Nível de Confiança</div>
          <div class="text-base font-semibold text-n-slate-12">{{ Number(forecast.confidence_level || 0).toFixed(0) }}%</div>
        </div>
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Riscos Identificados</div>
          <div class="text-base font-semibold text-n-slate-12">{{ forecast.risks?.length || 0 }}</div>
        </div>
        <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
          <div class="text-xs text-n-slate-11">Oportunidades</div>
          <div class="text-base font-semibold text-n-slate-12">{{ forecast.opportunities?.length || 0 }}</div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
          <div class="text-sm font-medium text-n-slate-12 mb-2">Previsão Semanal</div>
          <div v-if="!forecast.weekly_forecast?.length" class="text-xs text-n-slate-11">Sem dados</div>
          <div v-else class="h-64">
            <BarChart :collection="weeklyChart" />
          </div>
        </div>
        <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
          <div class="text-sm font-medium text-n-slate-12 mb-2">Previsão Mensal</div>
          <div v-if="!forecast.monthly_forecast?.length" class="text-xs text-n-slate-11">Sem dados</div>
          <div v-else class="h-64">
            <BarChart :collection="monthlyChart" />
          </div>
        </div>
      </div>

      <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
        <div class="text-sm font-medium text-n-slate-12 mb-2">Distribuição do Pipeline por Estágio</div>
        <div v-if="!metrics?.deals_by_stage" class="text-xs text-n-slate-11">Sem dados</div>
        <div v-else class="h-64">
          <BarChart :collection="stagesChart" />
        </div>
      </div>

      <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
        <div class="text-sm font-medium text-n-slate-12 mb-2">Análise Estatística</div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
            <div class="text-xs text-n-slate-11">Variação Total</div>
            <div class="text-base font-semibold text-n-slate-12">{{ currencyBRL(scenario.analysis.variation) }}</div>
            <div class="text-xs text-n-slate-11">Entre melhor e pior cenário</div>
          </div>
          <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
            <div class="text-xs text-n-slate-11">Margem de Risco</div>
            <div class="text-base font-semibold text-n-slate-12">{{ currencyBRL(scenario.analysis.riskMargin) }}</div>
            <div class="text-xs text-n-slate-11">Possível perda no cenário conservador</div>
          </div>
          <div class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
            <div class="text-xs text-n-slate-11">Potencial de Ganho</div>
            <div class="text-base font-semibold text-n-slate-12">{{ currencyBRL(scenario.analysis.potentialGain) }}</div>
            <div class="text-xs text-n-slate-11">Upside no cenário otimista</div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
          <div class="text-sm font-medium text-n-slate-12 mb-2">Riscos</div>
          <div v-if="!forecast.risks?.length" class="text-xs text-n-slate-11">Sem riscos identificados</div>
          <ul v-else class="space-y-2">
            <li v-for="r in forecast.risks" :key="r.title" class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
              <div class="text-sm font-medium text-n-slate-12">{{ r.title }}</div>
              <div class="text-xs text-n-slate-11">{{ r.description }}</div>
            </li>
          </ul>
        </div>
        <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
          <div class="text-sm font-medium text-n-slate-12 mb-2">Oportunidades</div>
          <div v-if="!forecast.opportunities?.length" class="text-xs text-n-slate-11">Sem oportunidades</div>
          <ul v-else class="space-y-2">
            <li v-for="o in forecast.opportunities" :key="o.title" class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
              <div class="text-sm font-medium text-n-slate-12">{{ o.title }}</div>
              <div class="text-xs text-n-slate-11">{{ o.description }}</div>
            </li>
          </ul>
        </div>
      </div>

      <div class="rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
        <div class="flex items-center justify-between mb-2">
          <div class="text-sm font-medium text-n-slate-12">Histórico de Previsões</div>
          <NextButton sm slate :label="showHistory ? 'Fechar' : 'Ver histórico'" @click="showHistory = !showHistory" />
        </div>
        <div v-if="showHistory">
          <div v-if="!history.length" class="text-xs text-n-slate-11">Sem histórico.</div>
          <ul v-else class="space-y-2">
            <li v-for="h in history" :key="h.id" class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3">
              <div class="flex items-center justify-between">
                <div class="text-sm font-medium text-n-slate-12">{{ new Date(h.created_at || h.createdAt).toLocaleString('pt-BR') }}</div>
                <NextButton sm :label="'Abrir'" @click="async () => { const { data } = await ForecastsAPI.show(h.id); forecast = data; }" />
              </div>
              <div class="text-xs text-n-slate-11 mt-1">{{ h.summary || 'Previsão anterior' }}</div>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>
const loadHistory = async () => {
  try {
    const { data } = await ForecastsAPI.history();
    history.value = Array.isArray(data) ? data : [];
  } catch {}
};
