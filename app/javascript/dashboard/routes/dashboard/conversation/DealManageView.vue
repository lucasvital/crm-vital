<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';

import DealDetailsLayout from 'dashboard/components-next/Deals/DealDetailsLayout.vue';
import DealDetails from 'dashboard/components-next/Deals/DealDetails.vue';
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

const emit = defineEmits(['close', 'goBack', 'updateDeal']);

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
</script>

<template>
  <DealDetailsLayout
    :selected-deal="selectedDeal"
    :is-updating="isUpdating"
    :show-back-button="showBackButton"
    @close="handleClose"
    @go-back="handleBack"
  >
    <DealDetails
      :selected-deal="selectedDeal"
      :pipeline-stages="pipelineStages"
      :is-updating="isUpdating"
      @update-deal="$emit('updateDeal', $event)"
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
        <template v-if="activeTab === 'details'">
          <div class="px-6">
            <p class="text-sm text-n-slate-11">
              {{ $t('DEAL_MANAGE.DETAILS_TAB_PLACEHOLDER') }}
            </p>
          </div>
        </template>
        <DealActivities
          v-else-if="activeTab === 'activities'"
          :selected-deal="selectedDeal"
          :current-stage="currentStage"
        />
      </div>
    </template>
  </DealDetailsLayout>
</template>

