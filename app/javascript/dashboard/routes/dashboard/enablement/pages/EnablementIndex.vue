<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import callAnalysesAPI from 'dashboard/api/callAnalyses';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const router = useRouter();
const { t } = useI18n();

const analyses = ref([]);
const loading = ref(false);
const currentUser = computed(() => window.chatwootConfig?.user);
const isAdmin = computed(() => currentUser.value?.role === 'administrator');

const fetchAnalyses = async () => {
  loading.value = true;
  try {
    const response = await callAnalysesAPI.list();
    analyses.value = response.data || [];
  } catch (error) {
    useAlert(t('ENABLEMENT.API.ERROR.FETCH_ANALYSES'));
  } finally {
    loading.value = false;
  }
};

const goToNewAnalysis = () => {
  router.push({ name: 'enablement_new_analysis' });
};

const goToAnalysisDetail = (id) => {
  router.push({ name: 'enablement_analysis_detail', params: { id } });
};

const goToMyPdi = () => {
  router.push({ name: 'enablement_my_pdi' });
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

const getScoreColor = (score) => {
  if (score >= 8) return 'text-green-600 dark:text-green-400';
  if (score >= 6) return 'text-yellow-600 dark:text-yellow-400';
  return 'text-red-600 dark:text-red-400';
};

onMounted(() => {
  fetchAnalyses();
});
</script>

<template>
  <div class="flex flex-col flex-1 h-full overflow-auto bg-n-background">
    <!-- Header -->
    <div class="flex items-center justify-between px-8 py-6 border-b border-n-slate-4">
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          {{ t('ENABLEMENT.HEADER.TITLE') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ t('ENABLEMENT.HEADER.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex gap-2">
        <button
          class="px-4 py-2 text-sm font-medium rounded-md text-n-slate-12 bg-n-slate-3 hover:bg-n-slate-4"
          @click="goToMyPdi"
        >
          {{ t('ENABLEMENT.ACTIONS.VIEW_MY_PDI') }}
        </button>
        <button
          class="px-4 py-2.5 text-sm font-medium text-white rounded-md bg-n-brand hover:brightness-110"
          @click="goToNewAnalysis"
        >
          {{ t('ENABLEMENT.ACTIONS.NEW_ANALYSIS') }}
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <!-- Empty State -->
    <div
      v-else-if="!analyses.length"
      class="flex flex-col items-center justify-center flex-1 p-8"
    >
      <div class="max-w-md text-center">
        <div class="flex items-center justify-center w-24 h-24 mx-auto mb-4 rounded-full bg-n-slate-3">
          <span class="text-5xl text-n-slate-8">📊</span>
        </div>
        <h3 class="mb-2 text-lg font-medium text-n-slate-12">
          {{ t('ENABLEMENT.EMPTY_STATE.TITLE') }}
        </h3>
        <p class="mb-6 text-sm text-n-slate-11">
          {{ t('ENABLEMENT.EMPTY_STATE.MESSAGE') }}
        </p>
        <button
          class="px-6 py-3 text-sm font-medium text-white rounded-md bg-n-brand hover:brightness-110"
          @click="goToNewAnalysis"
        >
          {{ t('ENABLEMENT.ACTIONS.CREATE_FIRST_ANALYSIS') }}
        </button>
      </div>
    </div>

    <!-- List -->
    <div v-else class="flex-1 p-8 overflow-y-auto">
      <div class="grid gap-4">
        <div
          v-for="analysis in analyses"
          :key="analysis.id"
          class="p-5 transition-all border rounded-lg cursor-pointer bg-n-background border-n-slate-4 hover:border-woot-500"
          @click="goToAnalysisDetail(analysis.id)"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-2">
                <h3 class="text-base font-medium text-n-slate-12">
                  {{ analysis.contact?.name || t('ENABLEMENT.NO_CONTACT') }}
                </h3>
                <span
                  v-if="analysis.seller_score != null"
                  :class="['px-2 py-1 text-xs font-semibold rounded', getScoreColor(analysis.seller_score)]"
                >
                  {{ Number(analysis.seller_score).toFixed(1) }}/10
                </span>
                <span
                  v-else-if="analysis.processing_status === 'pending' || analysis.processing_status === 'processing'"
                  class="px-2 py-1 text-xs font-semibold rounded bg-n-amber-3 text-n-amber-11"
                >
                  {{ t('ENABLEMENT.STATUS.PROCESSING') }}
                </span>
                <span
                  v-else-if="analysis.processing_status === 'failed'"
                  class="px-2 py-1 text-xs font-semibold rounded bg-n-ruby-3 text-n-ruby-11"
                >
                  {{ t('ENABLEMENT.STATUS.FAILED') }}
                </span>
              </div>
              <p class="mb-3 text-sm line-clamp-2 text-n-slate-11">
                {{ analysis.summary || t('ENABLEMENT.NO_SUMMARY') }}
              </p>
              <div class="flex items-center gap-4 text-xs text-n-slate-10">
                <span class="flex items-center gap-1">
                  <span class="text-sm">👤</span>
                  {{ analysis.user?.name }}
                </span>
                <span class="flex items-center gap-1">
                  <span class="text-sm">🕐</span>
                  {{ formatDate(analysis.created_at) }}
                </span>
              </div>
            </div>
            <fluent-icon
              icon="chevron-right-outline"
              size="20"
              class="text-n-slate-8"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
