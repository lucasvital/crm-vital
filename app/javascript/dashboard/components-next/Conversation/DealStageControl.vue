<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  stage: { type: String, default: 'new' },
  stages: {
    type: Array,
    default: () => ['new', 'qualified', 'proposal', 'won', 'lost'],
  },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['change']);
const { t } = useI18n();

const currentStage = ref(props.stage || 'new');
watch(
  () => props.stage,
  val => {
    currentStage.value = val || 'new';
  }
);

const isDisabled = computed(() => props.loading);

const onSelect = next => {
  if (isDisabled.value || next === currentStage.value) return;
  emit('change', next);
};

const labelFor = key => {
  const map = {
    new: t('KANBAN.COLUMNS.NEW'),
    qualified: t('KANBAN.COLUMNS.QUALIFIED'),
    proposal: t('KANBAN.COLUMNS.PROPOSAL'),
    won: t('KANBAN.COLUMNS.WON'),
    lost: t('KANBAN.COLUMNS.LOST'),
  };
  return map[key] || key;
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <div
      role="tablist"
      aria-label="Deal stages"
      class="flex flex-wrap gap-2"
    >
      <button
        v-for="s in stages"
        :key="s"
        type="button"
        class="px-2 py-1 rounded-lg text-sm transition-colors duration-200 outline-none ring-0
               border border-n-weak
               data-[active=true]:bg-n-solid-3 data-[active=true]:border-n-strong
               hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-focus"
        :data-active="currentStage === s"
        :aria-current="currentStage === s ? 'true' : undefined"
        :disabled="isDisabled"
        @click="onSelect(s)"
      >
        {{ labelFor(s) }}
      </button>
    </div>
    <p class="text-xs text-n-slate-11">
      {{ t('KANBAN.CARDS.MOVE_TO') }}
    </p>
  </div>
</template>






