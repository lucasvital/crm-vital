<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import sellerPdisAPI from 'dashboard/api/sellerPdis';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const pdi = ref(null);
const loading = ref(false);
const userId = computed(() => route.params.user_id || null);

const fetchPdi = async () => {
  loading.value = true;
  try {
    const response = await sellerPdisAPI.get(userId.value);
    pdi.value = response.data;
  } catch (error) {
    useAlert(t('ENABLEMENT.API.ERROR.FETCH_PDI'));
  } finally {
    loading.value = false;
  }
};

const goBack = () => {
  router.push({ name: 'enablement_index' });
};

const formatDate = (dateString) => {
  const date = new Date(dateString);
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);
};

onMounted(() => {
  fetchPdi();
});
</script>

<template>
  <div class="flex flex-col h-full bg-white dark:bg-slate-900">
    <!-- Header -->
    <div class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-700">
      <div class="flex items-center gap-4">
        <button
          class="p-2 text-slate-600 hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-100"
          @click="goBack"
        >
          <i class="text-xl icon ion-ios-arrow-back" />
        </button>
        <div v-if="!loading && pdi">
          <h1 class="text-2xl font-semibold text-slate-900 dark:text-slate-100">
            {{ t('ENABLEMENT.PDI.TITLE') }}
          </h1>
          <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
            {{ pdi.user?.name }} • {{ pdi.analyses_count }} {{ t('ENABLEMENT.PDI.ANALYSES') }}
          </p>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center flex-1">
      <Spinner />
    </div>

    <!-- Empty State -->
    <div
      v-else-if="!pdi || pdi.analyses_count === 0"
      class="flex flex-col items-center justify-center flex-1 p-8"
    >
      <div class="text-center max-w-md">
        <div class="w-24 h-24 mx-auto mb-4 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center">
          <i class="text-4xl text-slate-400 dark:text-slate-600 icon ion-ios-stats" />
        </div>
        <h3 class="text-lg font-medium text-slate-900 dark:text-slate-100 mb-2">
          {{ t('ENABLEMENT.PDI.EMPTY_TITLE') }}
        </h3>
        <p class="text-sm text-slate-600 dark:text-slate-400 mb-6">
          {{ t('ENABLEMENT.PDI.EMPTY_MESSAGE') }}
        </p>
      </div>
    </div>

    <!-- Content -->
    <div v-else class="flex-1 overflow-y-auto p-6">
      <div class="max-w-4xl mx-auto space-y-8">
        <!-- Competencies Overview -->
        <div>
          <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
            {{ t('ENABLEMENT.PDI.COMPETENCIES_TITLE') }}
          </h2>
          <div v-if="Object.keys(pdi.competencies || {}).length" class="grid grid-cols-2 gap-4">
            <div
              v-for="(data, competency) in pdi.competencies"
              :key="competency"
              class="p-4 bg-slate-50 rounded-lg dark:bg-slate-800"
            >
              <div class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-2">
                {{ competency }}
              </div>
              <div class="flex items-center gap-2 mb-2">
                <div class="flex-1 h-3 bg-slate-200 rounded-full overflow-hidden dark:bg-slate-700">
                  <div
                    class="h-full bg-woot-500 transition-all"
                    :style="{ width: `${(data.current_score / 10) * 100}%` }"
                  />
                </div>
                <span class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                  {{ data.current_score }}
                </span>
              </div>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                {{ t('ENABLEMENT.PDI.LAST_UPDATED') }}: {{ formatDate(data.last_updated) }}
              </p>
            </div>
          </div>
          <p v-else class="text-sm text-slate-600 dark:text-slate-400">
            {{ t('ENABLEMENT.PDI.NO_COMPETENCIES') }}
          </p>
        </div>

        <!-- Strengths -->
        <div v-if="pdi.strengths?.length">
          <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
            {{ t('ENABLEMENT.PDI.STRENGTHS_TITLE') }}
          </h2>
          <div class="grid gap-3">
            <div
              v-for="(strength, index) in pdi.strengths"
              :key="index"
              class="p-4 bg-green-50 border border-green-200 rounded-lg dark:bg-green-900/20 dark:border-green-800"
            >
              <div class="flex items-start gap-3">
                <i class="text-green-600 icon ion-ios-star text-xl mt-0.5 dark:text-green-400" />
                <div>
                  <h4 class="text-sm font-semibold text-green-900 dark:text-green-200 mb-1">
                    {{ strength.competency || strength }}
                  </h4>
                  <p v-if="strength.description" class="text-sm text-green-800 dark:text-green-300">
                    {{ strength.description }}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Improvement Areas -->
        <div v-if="pdi.improvement_areas?.length">
          <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
            {{ t('ENABLEMENT.PDI.IMPROVEMENT_AREAS_TITLE') }}
          </h2>
          <div class="space-y-4">
            <div
              v-for="(area, index) in pdi.improvement_areas"
              :key="index"
              class="p-4 bg-yellow-50 border border-yellow-200 rounded-lg dark:bg-yellow-900/20 dark:border-yellow-800"
            >
              <div class="flex items-start gap-3">
                <i class="text-yellow-600 icon ion-ios-bulb text-xl mt-0.5 dark:text-yellow-400" />
                <div class="flex-1">
                  <h4 class="text-sm font-semibold text-yellow-900 dark:text-yellow-200 mb-1">
                    {{ area.competency || area }}
                  </h4>
                  <p v-if="area.current_level" class="text-sm text-yellow-800 dark:text-yellow-300 mb-2">
                    {{ area.current_level }} → {{ area.target_level }}
                  </p>
                  <div v-if="area.action_plan?.length" class="mt-2">
                    <p class="text-xs font-medium text-yellow-900 dark:text-yellow-200 mb-1">
                      {{ t('ENABLEMENT.PDI.ACTION_PLAN') }}:
                    </p>
                    <ul class="space-y-1">
                      <li
                        v-for="(action, idx) in area.action_plan"
                        :key="idx"
                        class="text-xs text-yellow-800 dark:text-yellow-300 pl-4"
                      >
                        • {{ action }}
                      </li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Evolution History -->
        <div v-if="pdi.evolution_history?.length">
          <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
            {{ t('ENABLEMENT.PDI.EVOLUTION_TITLE') }}
          </h2>
          <div class="space-y-3">
            <div
              v-for="(entry, index) in pdi.evolution_history.slice().reverse()"
              :key="index"
              class="flex items-center gap-4 p-4 bg-slate-50 rounded-lg dark:bg-slate-800"
            >
              <div class="flex-shrink-0">
                <div class="w-12 h-12 rounded-full bg-woot-500 flex items-center justify-center">
                  <span class="text-lg font-semibold text-white">
                    {{ entry.score?.toFixed(1) }}
                  </span>
                </div>
              </div>
              <div class="flex-1">
                <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  {{ formatDate(entry.date) }}
                </p>
                <p v-if="entry.key_improvements?.length" class="text-xs text-slate-600 dark:text-slate-400 mt-1">
                  {{ entry.key_improvements.join(' • ') }}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

