<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

import DealDetailsLayout from 'dashboard/components-next/Deals/DealDetailsLayout.vue';
import DealDetails from 'dashboard/components-next/Deals/DealDetails.vue';
import DealDetailsEdit from 'dashboard/components-next/Deals/DealDetailsEdit.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import DealActivities from 'dashboard/components-next/Deals/DealActivities.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  selectedDeal: {
    type: Object,
    required: true,
  },
  pipelineStages: {
    type: Array,
    default: () => [],
  },
  isUpdating: {
    type: Boolean,
    default: false,
  },
  showBackButton: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['close', 'goBack', 'updateDeal', 'stageChanged']);

const { t } = useI18n();

const activeTab = ref('details');

const DEAL_TABS_OPTIONS = [
  { key: 'DETAILS', value: 'details' },
  { key: 'ACTIVITIES', value: 'activities' },
];

const tabs = computed(() => {
  return DEAL_TABS_OPTIONS.map(tab => ({
    label: t(`DEAL_MANAGE.TABS.${tab.key}`),
    value: tab.value,
  }));
});

const activeTabIndex = computed(() => {
  return DEAL_TABS_OPTIONS.findIndex(v => v.value === activeTab.value);
});

const handleTabChange = tab => {
  activeTab.value = tab.value;
};

const currentStage = computed(() => {
  return props.selectedDeal?.custom_attributes?.deal_stage || '';
});

const handleClose = () => {
  emit('close');
};

const handleBack = () => {
  emit('goBack');
};

const handleDealUpdated = updatedData => {
  emit('updateDeal', updatedData);
};

const handleStageChanged = data => {
  emit('stageChanged', data);
};
</script>

<template>
  <DealDetailsLayout
    :selected-deal="selectedDeal"
    :is-updating="isUpdating"
    :show-back-button="showBackButton"
    @close="handleClose"
    @go-back="handleBack"
  >
    <DealDetailsEdit
      :selected-deal="selectedDeal"
      :pipeline-stages="pipelineStages"
      @updated="handleDealUpdated"
      @close="handleClose"
    />
    
    <template #sidebar>
      <div class="px-6">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTabIndex"
          class="w-full [&>button]:w-full bg-n-alpha-black2"
          @tab-changed="handleTabChange"
        />
      </div>
      <div class="mt-4">
        <DealDetails
          v-if="activeTab === 'details'"
          :selected-deal="selectedDeal"
          :pipeline-stages="pipelineStages"
        />
        <DealActivities
          v-else-if="activeTab === 'activities'"
          :selected-deal="selectedDeal"
          :current-stage="currentStage"
          :pipeline-stages="pipelineStages"
          @stage-changed="handleStageChanged"
        />
      </div>
    </template>
  </DealDetailsLayout>
</template>

