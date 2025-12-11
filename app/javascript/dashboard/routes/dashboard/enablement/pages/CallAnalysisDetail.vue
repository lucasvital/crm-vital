<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import callAnalysesAPI from 'dashboard/api/callAnalyses';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const analysis = ref(null);
const loading = ref(false);
const activeTab = ref('overview');
let pollingInterval = null;

const analysisId = computed(() => route.params.id);
const performanceData = computed(() => analysis.value?.analysis_result?.performance_analysis || {});
const crmData = computed(() => analysis.value?.analysis_result?.crm_extraction || {});
const pdiData = computed(() => analysis.value?.analysis_result?.pdi_recommendations || {});

// Status de processamento
const isProcessing = computed(() => 
  analysis.value?.processing_status === 'pending' || 
  analysis.value?.processing_status === 'processing' ||
  analysis.value?.['in_progress?']
);
const isFailed = computed(() => analysis.value?.processing_status === 'failed');
const isCompleted = computed(() => analysis.value?.processing_status === 'completed');

const fetchAnalysis = async () => {
  loading.value = true;
  try {
    const response = await callAnalysesAPI.get(analysisId.value);
    analysis.value = response.data;

    // Se está processando, iniciar polling
    if (isProcessing.value && !pollingInterval) {
      startPolling();
    }
    // Se terminou, parar polling
    if (!isProcessing.value && pollingInterval) {
      stopPolling();
    }
  } catch (error) {
    useAlert(t('ENABLEMENT.API.ERROR.FETCH_ANALYSIS'));
    router.push({ name: 'enablement_index' });
  } finally {
    loading.value = false;
  }
};

const startPolling = () => {
  pollingInterval = setInterval(async () => {
    try {
      const response = await callAnalysesAPI.get(analysisId.value);
      analysis.value = response.data;

      // Se completou ou falhou, para o polling
      if (!isProcessing.value) {
        stopPolling();
        if (isCompleted.value) {
          useAlert(t('ENABLEMENT.SUCCESS.ANALYSIS_COMPLETED'));
        }
      }
    } catch (error) {
      console.error('Polling error:', error);
    }
  }, 5000); // Poll a cada 5 segundos
};

const stopPolling = () => {
  if (pollingInterval) {
    clearInterval(pollingInterval);
    pollingInterval = null;
  }
};

const goBack = () => {
  router.push({ name: 'enablement_index' });
};

const getScoreColor = (score) => {
  if (score >= 8) return 'text-green-600 bg-green-500/10';
  if (score >= 6) return 'text-n-amber-11 bg-n-amber-3';
  return 'text-n-ruby-11 bg-n-ruby-3';
};

const formatDate = (dateString) => {
  const date = new Date(dateString);
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
};

const formatCompetencyLabel = (competency) => {
  if (!competency) return '';
  
  // Tenta traduzir usando a chave de tradução
  const translationKey = `ENABLEMENT.COMPETENCY.${competency.toUpperCase()}`;
  const translated = t(translationKey);
  
  // Se encontrou tradução, retorna
  if (translated !== translationKey) {
    return translated;
  }
  
  // Fallback: converte snake_case para Title Case
  return competency
    .replace(/_/g, ' ')
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
};

onMounted(() => {
  fetchAnalysis();
});

onUnmounted(() => {
  stopPolling();
});
</script>

<template>
  <div class="flex flex-col flex-1 h-full overflow-auto bg-n-background">
    <!-- Header -->
    <div class="flex items-center justify-between px-8 py-6 border-b border-n-slate-4">
      <div class="flex items-center gap-4">
        <button
          class="p-2 rounded-md hover:bg-n-slate-3 text-n-slate-11 hover:text-n-slate-12"
          @click="goBack"
        >
          <fluent-icon icon="chevron-left-outline" size="20" />
        </button>
        <div v-if="!loading && analysis">
          <h1 class="text-2xl font-semibold text-n-slate-12">
            {{ analysis.contact?.name || t('ENABLEMENT.NO_CONTACT') }}
          </h1>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('ENABLEMENT.ANALYZED_BY') }}: {{ analysis.user?.name }} • {{ formatDate(analysis.created_at) }}
          </p>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <!-- Processing State -->
    <div v-else-if="analysis && isProcessing" class="flex flex-col items-center justify-center flex-1 p-8">
      <div class="max-w-md text-center">
        <div class="flex items-center justify-center w-24 h-24 mx-auto mb-6 rounded-full bg-n-amber-3">
          <Spinner size="large" />
        </div>
        <h3 class="mb-2 text-xl font-semibold text-n-slate-12">
          {{ t('ENABLEMENT.PROCESSING.TITLE') }}
        </h3>
        <p class="mb-4 text-sm text-n-slate-11">
          {{ t('ENABLEMENT.PROCESSING.MESSAGE') }}
        </p>
        <p class="text-xs text-n-slate-10">
          {{ t('ENABLEMENT.PROCESSING.HINT') }}
        </p>
      </div>
    </div>

    <!-- Failed State -->
    <div v-else-if="analysis && isFailed" class="flex flex-col items-center justify-center flex-1 p-8">
      <div class="max-w-md text-center">
        <div class="flex items-center justify-center w-24 h-24 mx-auto mb-6 rounded-full bg-n-ruby-3">
          <fluent-icon icon="dismiss-outline" size="48" class="text-n-ruby-11" />
        </div>
        <h3 class="mb-2 text-xl font-semibold text-n-slate-12">
          {{ t('ENABLEMENT.PROCESSING.FAILED_TITLE') }}
        </h3>
        <p class="mb-4 text-sm text-n-slate-11">
          {{ analysis.processing_error || t('ENABLEMENT.PROCESSING.FAILED_MESSAGE') }}
        </p>
        <button
          class="px-6 py-3 text-sm font-medium text-white rounded-md bg-n-brand hover:brightness-110"
          @click="goBack"
        >
          {{ t('ENABLEMENT.ACTIONS.BACK_TO_LIST') }}
        </button>
      </div>
    </div>

    <!-- Content (when completed) -->
    <div v-else-if="analysis && isCompleted" class="flex-1 overflow-y-auto">
      <!-- Score Card -->
      <div class="p-6 border-b border-n-slate-4 bg-n-slate-2">
        <div class="max-w-4xl mx-auto">
          <div class="flex items-center gap-6">
            <div :class="['px-6 py-4 rounded-lg', getScoreColor(analysis.seller_score)]">
              <div class="mb-1 text-sm font-medium">{{ t('ENABLEMENT.OVERALL_SCORE') }}</div>
              <div class="text-3xl font-bold">{{ Number(analysis.seller_score).toFixed(1) }}/10</div>
            </div>
            <div class="flex-1">
              <p class="text-sm text-n-slate-11">
                {{ analysis.summary }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Tabs -->
      <div class="border-b border-n-slate-4">
        <div class="max-w-4xl px-6 mx-auto">
          <div class="flex gap-4">
            <button
              :class="[
                'px-4 py-3 text-sm font-medium border-b-2 transition-colors',
                activeTab === 'overview'
                  ? 'border-woot-500 text-woot-500'
                  : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
              ]"
              @click="activeTab = 'overview'"
            >
              {{ t('ENABLEMENT.TABS.OVERVIEW') }}
            </button>
            <button
              :class="[
                'px-4 py-3 text-sm font-medium border-b-2 transition-colors',
                activeTab === 'performance'
                  ? 'border-woot-500 text-woot-500'
                  : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
              ]"
              @click="activeTab = 'performance'"
            >
              {{ t('ENABLEMENT.TABS.PERFORMANCE') }}
            </button>
            <button
              :class="[
                'px-4 py-3 text-sm font-medium border-b-2 transition-colors',
                activeTab === 'pdi'
                  ? 'border-woot-500 text-woot-500'
                  : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
              ]"
              @click="activeTab = 'pdi'"
            >
              {{ t('ENABLEMENT.TABS.PDI') }}
            </button>
            <button
              :class="[
                'px-4 py-3 text-sm font-medium border-b-2 transition-colors',
                activeTab === 'transcript'
                  ? 'border-woot-500 text-woot-500'
                  : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
              ]"
              @click="activeTab = 'transcript'"
            >
              {{ t('ENABLEMENT.TABS.TRANSCRIPT') }}
            </button>
          </div>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="p-6">
        <div class="max-w-4xl mx-auto space-y-6">
          <!-- Overview Tab -->
          <div v-if="activeTab === 'overview'" class="space-y-6">
            <!-- Next Steps -->
            <div v-if="crmData.next_steps?.length">
              <h3 class="mb-3 text-lg font-semibold text-n-slate-12">
                {{ t('ENABLEMENT.NEXT_STEPS') }}
              </h3>
              <div class="space-y-2">
                <div
                  v-for="(step, index) in crmData.next_steps"
                  :key="index"
                  class="p-3 border rounded-lg bg-n-blue-3 border-n-blue-6"
                >
                  <p class="text-sm font-medium text-n-blue-11">{{ step.action }}</p>
                  <p v-if="step.responsible" class="mt-1 text-xs text-n-blue-11">
                    {{ t('ENABLEMENT.RESPONSIBLE') }}: {{ step.responsible }}
                  </p>
                </div>
              </div>
            </div>

            <!-- Objections -->
            <div v-if="crmData.objections?.length">
              <h3 class="mb-3 text-lg font-semibold text-n-slate-12">
                {{ t('ENABLEMENT.OBJECTIONS') }}
              </h3>
              <div class="space-y-2">
                <div
                  v-for="(obj, index) in crmData.objections"
                  :key="index"
                  class="p-3 border rounded-lg bg-n-slate-3 border-n-slate-4"
                >
                  <p class="text-sm text-n-slate-12">{{ obj.objection }}</p>
                  <p v-if="obj.response" class="mt-1 text-xs text-n-slate-11">
                    {{ t('ENABLEMENT.RESPONSE') }}: {{ obj.response }}
                  </p>
                </div>
              </div>
            </div>

            <!-- Competitors -->
            <div v-if="crmData.competitors_mentioned?.length">
              <h3 class="mb-3 text-lg font-semibold text-n-slate-12">
                {{ t('ENABLEMENT.COMPETITORS') }}
              </h3>
              <div class="flex flex-wrap gap-2">
                <span
                  v-for="(competitor, index) in crmData.competitors_mentioned"
                  :key="index"
                  class="px-3 py-1 text-sm rounded-full bg-n-iris-3 text-n-iris-11"
                >
                  {{ competitor }}
                </span>
              </div>
            </div>
          </div>

          <!-- Performance Tab -->
          <div v-if="activeTab === 'performance'" class="space-y-6">
            <!-- Scores -->
            <div v-if="performanceData.scores">
              <h3 class="mb-4 text-lg font-semibold text-n-slate-12">
                {{ t('ENABLEMENT.PERFORMANCE_SCORES') }}
              </h3>
              <div class="grid grid-cols-2 gap-4">
                <div
                  v-for="(score, key) in performanceData.scores"
                  :key="key"
                  class="p-4 rounded-lg bg-n-slate-3"
                >
                  <div class="mb-1 text-sm text-n-slate-11">
                    {{ t(`ENABLEMENT.SCORES.${key.toUpperCase()}`) }}
                  </div>
                  <div class="flex items-center gap-2">
                    <div class="flex-1 h-2 overflow-hidden rounded-full bg-n-slate-5">
                      <div
                        class="h-full transition-all bg-woot-500"
                        :style="{ width: `${(score / 10) * 100}%` }"
                      />
                    </div>
                    <span class="text-lg font-semibold text-n-slate-12">
                      {{ score }}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Strengths -->
            <div v-if="performanceData.strengths?.length">
              <h3 class="mb-3 text-lg font-semibold text-n-slate-12">
                {{ t('ENABLEMENT.STRENGTHS') }}
              </h3>
              <ul class="space-y-2">
                <li
                  v-for="(strength, index) in performanceData.strengths"
                  :key="index"
                  class="flex items-start gap-2 text-sm text-n-slate-11"
                >
                  <fluent-icon icon="checkmark-circle" size="16" class="mt-0.5 text-green-500" />
                  <span>{{ strength }}</span>
                </li>
              </ul>
            </div>

            <!-- Improvement Areas -->
            <div v-if="performanceData.improvement_areas?.length">
              <h3 class="mb-3 text-lg font-semibold text-n-slate-12">
                {{ t('ENABLEMENT.IMPROVEMENT_AREAS') }}
              </h3>
              <ul class="space-y-2">
                <li
                  v-for="(area, index) in performanceData.improvement_areas"
                  :key="index"
                  class="flex items-start gap-2 text-sm text-n-slate-11"
                >
                  <span class="mt-0.5 text-n-amber-11">⚠</span>
                  <span>{{ area }}</span>
                </li>
              </ul>
            </div>
          </div>

          <!-- PDI Tab -->
          <div v-if="activeTab === 'pdi'" class="space-y-6">
            <!-- Competencies -->
            <div v-if="pdiData.competencies">
              <h3 class="mb-4 text-lg font-semibold text-n-slate-12">
                {{ t('ENABLEMENT.COMPETENCIES') }}
              </h3>
              <div class="grid grid-cols-2 gap-4">
                <div
                  v-for="(score, competency) in pdiData.competencies"
                  :key="competency"
                  class="p-4 rounded-lg bg-n-slate-3"
                >
                  <div class="mb-2 text-sm font-medium text-n-slate-12">
                    {{ competency }}
                  </div>
                  <div class="flex items-center gap-2">
                    <div class="flex-1 h-2 overflow-hidden rounded-full bg-n-slate-5">
                      <div
                        class="h-full transition-all bg-woot-500"
                        :style="{ width: `${(score / 10) * 100}%` }"
                      />
                    </div>
                    <span class="text-sm font-semibold text-n-slate-12">
                      {{ score }}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Improvement Areas with Action Plans -->
            <div v-if="pdiData.improvement_areas?.length">
              <h3 class="mb-3 text-lg font-semibold text-n-slate-12">
                {{ t('ENABLEMENT.PDI_IMPROVEMENT_AREAS') }}
              </h3>
              <div class="space-y-4">
                <div
                  v-for="(area, index) in pdiData.improvement_areas"
                  :key="index"
                  class="p-4 border rounded-lg bg-n-slate-3 border-n-slate-4"
                >
                  <div class="flex items-start justify-between mb-2">
                    <h4 class="text-sm font-semibold text-n-slate-12">
                      {{ formatCompetencyLabel(area.competency) }}
                    </h4>
                    <span
                      :class="[
                        'px-2 py-1 text-xs font-medium rounded',
                        area.priority === 'high' ? 'bg-n-ruby-3 text-n-ruby-11' :
                        area.priority === 'medium' ? 'bg-n-amber-3 text-n-amber-11' :
                        'bg-n-blue-3 text-n-blue-11'
                      ]"
                    >
                      {{ t(`ENABLEMENT.PRIORITY.${area.priority?.toUpperCase() || 'LOW'}`) }}
                    </span>
                  </div>
                  <p class="mb-3 text-sm text-n-slate-11">
                    {{ area.current_level }} → {{ area.target_level }}
                  </p>
                  <div v-if="area.action_plan?.length">
                    <p class="mb-1 text-xs font-medium text-n-slate-12">
                      {{ t('ENABLEMENT.ACTION_PLAN') }}:
                    </p>
                    <ul class="space-y-1">
                      <li
                        v-for="(action, idx) in area.action_plan"
                        :key="idx"
                        class="pl-4 text-xs text-n-slate-11"
                      >
                        • {{ action }}
                      </li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Transcript Tab -->
          <div v-if="activeTab === 'transcript'">
            <div class="p-4 rounded-lg bg-n-slate-3">
              <pre class="text-sm whitespace-pre-wrap text-n-slate-11">{{ analysis.transcript }}</pre>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

