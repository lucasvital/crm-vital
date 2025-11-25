<script setup>
import ReportHeader from './components/ReportHeader.vue';
import ConversationHeatmapContainer from './components/heatmaps/ConversationHeatmapContainer.vue';
import ResolutionHeatmapContainer from './components/heatmaps/ResolutionHeatmapContainer.vue';
import AgentLiveReportContainer from './components/AgentLiveReportContainer.vue';
import TeamLiveReportContainer from './components/TeamLiveReportContainer.vue';
import StatsLiveReportsContainer from './components/StatsLiveReportsContainer.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
</script>

<template>
  <ReportHeader :header-title="$t('OVERVIEW_REPORTS.HEADER')">
    <router-link :to="{ name: 'sales_forecast' }">
      <NextButton :label="'Previsão de Vendas'" />
    </router-link>
  </ReportHeader>
  <div class="flex flex-col gap-4 pb-6">
    <StatsLiveReportsContainer />
    <ConversationHeatmapContainer />
    <ResolutionHeatmapContainer />
    <AgentLiveReportContainer />
    <TeamLiveReportContainer />
  </div>
</template>
