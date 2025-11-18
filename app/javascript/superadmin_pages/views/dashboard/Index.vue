<script setup>
import { computed } from 'vue';
import BarChart from 'shared/components/charts/BarChart.vue';
const props = defineProps({
  componentData: {
    type: Object,
    default: () => ({}),
  },
});

const prepareData = sourceData => {
  var labels = [];
  var data = [];
  sourceData.forEach(item => {
    labels.push(item[0]);
    data.push(item[1]);
  });
  return {
    labels,
    datasets: [
      {
        type: 'bar',
        backgroundColor: 'rgb(31, 147, 255)',
        yAxisID: 'y',
        label: 'Conversations',
        data: data,
      },
    ],
  };
};

const chartData = computed(() => {
  return prepareData(props.componentData.chartData);
});

const { accountsCount, usersCount, inboxesCount, conversationsCount } =
  props.componentData;

// Company Size
const COMPANY_SIZE_ORDER = ['1-5', '6-20', '21-50', '51-200', '200+'];
const companySizeChart = computed(() => {
  const pairs = props.componentData.companySizeData || [];
  const map = Object.fromEntries(pairs);
  const ordered = [];
  COMPANY_SIZE_ORDER.forEach(k => {
    if (map[k] != null) ordered.push([k, map[k]]);
  });
  // Append any unexpected keys alphabetically
  Object.keys(map)
    .filter(k => !COMPANY_SIZE_ORDER.includes(k))
    .sort()
    .forEach(k => ordered.push([k, map[k]]));
  return {
    labels: ordered.map(i => i[0]),
    datasets: [
      {
        type: 'bar',
        backgroundColor: 'rgb(16, 185, 129)',
        yAxisID: 'y',
        label: 'Company size',
        data: ordered.map(i => i[1]),
      },
    ],
  };
});

// Industry
const INDUSTRY_ORDER = ['ecommerce', 'saas', 'services', 'retail', 'education', 'other'];
const pretty = s => {
  if (!s) return 'unknown';
  return s.charAt(0).toUpperCase() + s.slice(1);
};
const industryChart = computed(() => {
  const pairs = props.componentData.industryData || [];
  const map = Object.fromEntries(pairs);
  const ordered = [];
  INDUSTRY_ORDER.forEach(k => {
    if (map[k] != null) ordered.push([k, map[k]]);
  });
  Object.keys(map)
    .filter(k => !INDUSTRY_ORDER.includes(k))
    .sort()
    .forEach(k => ordered.push([k, map[k]]));
  return {
    labels: ordered.map(i => pretty(i[0])),
    datasets: [
      {
        type: 'bar',
        backgroundColor: 'rgb(59, 130, 246)',
        yAxisID: 'y',
        label: 'Industry',
        data: ordered.map(i => i[1]),
      },
    ],
  };
});
</script>

<template>
  <div class="w-full h-full">
    <header class="main-content__header" role="banner">
      <h1 id="page-title" class="main-content__page-title">
        {{ 'Admin Dashboard' }}
      </h1>
    </header>

    <section class="main-content__body main-content__body--flush">
      <div class="report--list">
        <div class="report-card">
          <div class="metric">{{ accountsCount }}</div>
          <div>{{ 'Accounts' }}</div>
        </div>
        <div class="report-card">
          <div class="metric">{{ usersCount }}</div>
          <div>{{ 'Users' }}</div>
        </div>
        <div class="report-card">
          <div class="metric">{{ inboxesCount }}</div>
          <div>{{ 'Inboxes' }}</div>
        </div>
        <div class="report-card">
          <div class="metric">{{ conversationsCount }}</div>
          <div>{{ 'Conversations' }}</div>
        </div>
      </div>
    </section>
    <!-- eslint-disable vue/no-static-inline-styles -->
    <BarChart
      class="p-8 w-full"
      :collection="chartData"
      style="max-height: 500px"
    />

    <section class="main-content__body main-content__body--flush">
      <div class="report--list">
        <div class="report-card" style="flex: 1 1 50%">
          <div class="metric" style="font-size: 16px; margin-bottom: 8px">
            Company size
          </div>
          <div style="height: 320px">
            <BarChart :collection="companySizeChart" />
          </div>
        </div>
        <div class="report-card" style="flex: 1 1 50%">
          <div class="metric" style="font-size: 16px; margin-bottom: 8px">
            Industry
          </div>
          <div style="height: 320px">
            <BarChart :collection="industryChart" />
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
