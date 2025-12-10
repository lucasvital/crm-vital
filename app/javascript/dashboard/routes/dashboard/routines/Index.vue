<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import RoutinesAPI from 'dashboard/api/routines';

const { t } = useI18n();

const allRoutines = ref([]);
const isLoading = ref(false);
const hasError = ref(false);

const loadAllRoutines = async () => {
  isLoading.value = true;
  hasError.value = false;
  try {
    // Carregar rotinas de todos os dias da semana
    const weekdayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
    const promises = weekdayKeys.map(day => 
      RoutinesAPI.getAgentRoutines({ weekday: day })
    );
    const responses = await Promise.all(promises);
    
    // Combinar todas as rotinas
    const combined = responses.flatMap(res => res.data.payload || []);
    allRoutines.value = combined;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[RoutinesCalendar] Error:', error);
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  loadAllRoutines();
});

const weekdays = computed(() => [
  { key: 'monday', label: t('ROUTINES.WEEKDAY.MONDAY') },
  { key: 'tuesday', label: t('ROUTINES.WEEKDAY.TUESDAY') },
  { key: 'wednesday', label: t('ROUTINES.WEEKDAY.WEDNESDAY') },
  { key: 'thursday', label: t('ROUTINES.WEEKDAY.THURSDAY') },
  { key: 'friday', label: t('ROUTINES.WEEKDAY.FRIDAY') },
]);

const routinesByWeekday = computed(() => {
  const grouped = {};
  weekdays.value.forEach(day => {
    grouped[day.key] = allRoutines.value
      .filter(r => r.weekday === day.key && r.active)
      .sort((a, b) => a.time_of_day.localeCompare(b.time_of_day));
  });
  return grouped;
});
</script>

<template>
  <div class="flex flex-col min-h-full h-full p-4 overflow-auto bg-n-solid-1">
    <div class="max-w-7xl w-full mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-semibold text-n-slate-12">
          {{ $t('ROUTINES.CALENDAR.TITLE') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ $t('ROUTINES.CALENDAR.DESCRIPTION') }}
        </p>
      </div>

      <div v-if="isLoading" class="py-8 text-center text-n-slate-11">
        {{ $t('ROUTINES.LOADING') }}
      </div>

      <div
        v-else-if="hasError"
        class="py-8 text-center text-ruby-11"
      >
        {{ $t('GENERAL.ERROR') }}
      </div>

      <div v-else class="grid grid-cols-1 md:grid-cols-5 gap-3">
        <div
          v-for="day in weekdays"
          :key="day.key"
          class="flex flex-col rounded-lg border border-n-weak bg-n-solid-2 overflow-hidden"
        >
          <div class="px-4 py-3 border-b border-n-weak bg-n-solid-3">
            <h3 class="text-sm font-semibold text-n-slate-12">
              {{ day.label }}
            </h3>
          </div>
          <div class="flex-1 p-3 space-y-2">
            <div
              v-if="!routinesByWeekday[day.key]?.length"
              class="py-4 text-xs text-center text-n-slate-11"
            >
              {{ $t('ROUTINES.CALENDAR.NO_ROUTINES') }}
            </div>
            <div
              v-for="routine in routinesByWeekday[day.key]"
              :key="routine.id"
              class="p-3 rounded-md border border-n-weak bg-n-solid-1"
            >
              <div class="flex items-center gap-2 mb-1">
                <span
                  class="inline-flex items-center justify-center px-2 py-0.5 text-[11px] font-medium rounded-full bg-n-blue-3 text-n-blue-text"
                >
                  {{ routine.time_of_day }}
                </span>
              </div>
              <p class="text-sm font-medium text-n-slate-12">
                {{ routine.title }}
              </p>
              <p
                v-if="routine.description"
                class="mt-1 text-xs text-n-slate-11 line-clamp-2"
              >
                {{ routine.description }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

