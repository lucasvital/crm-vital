<script setup>
import { computed, onMounted, ref, watch, onActivated } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStoreGetters } from 'dashboard/composables/store';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DealActivitiesAPI from 'dashboard/api/dealActivities';
import PipelinesAPI from 'dashboard/api/pipelines';

const { t } = useI18n();
const router = useRouter();
const getters = useStoreGetters();

const activities = ref([]);
const pipelines = ref([]);
const loading = ref(false);
const selectedPipeline = ref(null);
const showDeleteModal = ref(false);
const activeActivity = ref(null);
const deleting = ref(false);

const accountId = computed(() => getters.getCurrentAccountId.value);

const fetchPipelines = async () => {
  try {
    const { data } = await PipelinesAPI.get();
    pipelines.value = data || [];
    if (pipelines.value.length > 0 && !selectedPipeline.value) {
      selectedPipeline.value = pipelines.value[0].id;
    }
  } catch (error) {
    console.error('Error fetching pipelines:', error);
    useAlert(t('DEAL_ACTIVITIES_SETTINGS.ERRORS.FETCH_FAILED'));
  }
};

const fetchActivities = async () => {
  loading.value = true;
  try {
    const response = await DealActivitiesAPI.get();
    activities.value = response.data || [];
  } catch (error) {
    console.error('Error fetching activities:', error);
    useAlert(t('DEAL_ACTIVITIES_SETTINGS.ERRORS.FETCH_FAILED'));
  } finally {
    loading.value = false;
  }
};

const filteredActivities = computed(() => {
  if (!selectedPipeline.value) return activities.value;
  
  const pipeline = pipelines.value.find(p => p.id === selectedPipeline.value);
  if (!pipeline) return [];
  
  const stageIds = pipeline.pipeline_stages?.map(s => s.id) || [];
  return activities.value.filter(a => stageIds.includes(a.pipeline_stage_id));
});

const getStageName = stageId => {
  for (const pipeline of pipelines.value) {
    const stage = pipeline.pipeline_stages?.find(s => s.id === stageId);
    if (stage) return stage.name;
  }
  return '-';
};

const getPipelineName = stageId => {
  for (const pipeline of pipelines.value) {
    if (pipeline.pipeline_stages?.some(s => s.id === stageId)) {
      return pipeline.name;
    }
  }
  return '-';
};

const getMessageCount = activity => {
  return activity.messages?.length || 0;
};

const goToNew = () => {
  router.push({ name: 'deal_activities_new', params: { accountId: accountId.value } });
};

const goToEdit = activity => {
  router.push({
    name: 'deal_activities_edit',
    params: { accountId: accountId.value, activityId: activity.id },
  });
};

const openDeleteModal = activity => {
  activeActivity.value = activity;
  showDeleteModal.value = true;
};

const closeDeleteModal = () => {
  showDeleteModal.value = false;
  activeActivity.value = null;
};

const confirmDelete = async () => {
  if (!activeActivity.value) return;
  
  deleting.value = true;
  try {
    await DealActivitiesAPI.delete(activeActivity.value.id);
    useAlert(t('DEAL_ACTIVITIES_SETTINGS.ALERTS.DELETE_SUCCESS'));
    await fetchActivities();
    closeDeleteModal();
  } catch (error) {
    console.error('Error deleting activity:', error);
    useAlert(t('DEAL_ACTIVITIES_SETTINGS.ALERTS.DELETE_FAILED'));
  } finally {
    deleting.value = false;
  }
};

onMounted(async () => {
  await fetchPipelines();
  await fetchActivities();
});

// Recarregar atividades quando voltar para esta página
watch(
  () => router.currentRoute.value.name,
  (newRouteName) => {
    if (newRouteName === 'deal_activities_index') {
      fetchActivities();
    }
  }
);

// Recarregar quando o componente for reativado (se estiver em keep-alive)
onActivated(() => {
  fetchActivities();
});
</script>

<template>
  <div class="flex-1 overflow-auto">
    <BaseSettingsHeader
      :title="$t('DEAL_ACTIVITIES_SETTINGS.TITLE')"
      :description="$t('DEAL_ACTIVITIES_SETTINGS.DESCRIPTION')"
      feature-name="deal_activities"
    >
      <template #actions>
        <Button
          icon="i-lucide-circle-plus"
          :label="$t('DEAL_ACTIVITIES_SETTINGS.ADD')"
          @click="goToNew"
        />
      </template>
    </BaseSettingsHeader>

    <div class="mt-6 mb-4 px-8">
      <label class="block text-sm font-medium text-n-slate-12 mb-2">
        {{ $t('DEAL_ACTIVITIES_SETTINGS.FILTER_BY_PIPELINE') }}
      </label>
      <select
        v-model="selectedPipeline"
        class="w-64 rounded-lg border border-n-alpha-2 bg-n-background px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
      >
        <option
          v-for="pipeline in pipelines"
          :key="pipeline.id"
          :value="pipeline.id"
        >
          {{ pipeline.name }}
        </option>
      </select>
    </div>

    <div class="px-8 flex-1">
      <woot-loading-state
        v-if="loading"
        :message="$t('DEAL_ACTIVITIES_SETTINGS.LOADING')"
      />
      <p
        v-else-if="!filteredActivities.length"
        class="flex flex-col items-center justify-center h-full text-base text-n-slate-11 py-8"
      >
        {{ $t('DEAL_ACTIVITIES_SETTINGS.NO_ACTIVITIES') }}
      </p>
      <table v-else class="min-w-full overflow-x-auto divide-y divide-n-weak">
        <thead>
          <tr>
            <th
              class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
            >
              {{ $t('DEAL_ACTIVITIES_SETTINGS.TABLE.PIPELINE') }}
            </th>
            <th
              class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
            >
              {{ $t('DEAL_ACTIVITIES_SETTINGS.TABLE.STAGE') }}
            </th>
            <th
              class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
            >
              {{ $t('DEAL_ACTIVITIES_SETTINGS.TABLE.TITLE') }}
            </th>
            <th
              class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
            >
              {{ $t('DEAL_ACTIVITIES_SETTINGS.TABLE.MESSAGES') }}
            </th>
            <th
              class="py-4 ltr:pr-4 rtl:pl-4 text-right font-semibold text-n-slate-11"
            >
              {{ $t('DEAL_ACTIVITIES_SETTINGS.TABLE.ACTIONS') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak text-n-slate-11">
          <tr v-for="activity in filteredActivities" :key="activity.id">
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              {{ getPipelineName(activity.pipeline_stage_id) }}
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              {{ getStageName(activity.pipeline_stage_id) }}
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4 font-medium text-n-slate-12">
              {{ activity.title }}
            </td>
            <td class="py-4 ltr:pr-4 rtl:pl-4">
              <span
                class="inline-flex items-center gap-1 rounded-full bg-n-alpha-2 px-2 py-0.5 text-xs text-n-slate-11"
              >
                <span class="i-lucide-messages-square size-3" />
                {{ getMessageCount(activity) }}
              </span>
            </td>
            <td class="py-4 flex justify-end gap-1">
              <Button
                v-tooltip.top="$t('DEAL_ACTIVITIES_SETTINGS.EDIT')"
                icon="i-lucide-pen"
                slate
                xs
                faded
                @click="goToEdit(activity)"
              />
              <Button
                v-tooltip.top="$t('DEAL_ACTIVITIES_SETTINGS.DELETE')"
                icon="i-lucide-trash-2"
                xs
                ruby
                faded
                @click="openDeleteModal(activity)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <woot-delete-modal
      v-model:show="showDeleteModal"
      :on-close="closeDeleteModal"
      :on-confirm="confirmDelete"
      :title="$t('DEAL_ACTIVITIES_SETTINGS.DELETE_MODAL.TITLE')"
      :message="$t('DEAL_ACTIVITIES_SETTINGS.DELETE_MODAL.MESSAGE')"
      :message-value="activeActivity?.title || ''"
      :confirm-text="$t('DEAL_ACTIVITIES_SETTINGS.DELETE_MODAL.CONFIRM')"
      :reject-text="$t('DEAL_ACTIVITIES_SETTINGS.DELETE_MODAL.CANCEL')"
      :is-deleting="deleting"
    />
  </div>
</template>

