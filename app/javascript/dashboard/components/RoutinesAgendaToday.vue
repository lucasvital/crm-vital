<script setup>
import { onMounted, ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import RoutinesAPI from 'dashboard/api/routines';

const { t } = useI18n();

const routines = ref([]);
const isLoading = ref(false);
const hasError = ref(false);

const loadRoutines = async () => {
  isLoading.value = true;
  hasError.value = false;
  try {
    const response = await RoutinesAPI.getAgentRoutines({ weekday: 'today' });
    // eslint-disable-next-line no-console
    console.log('[RoutinesAgenda] Response:', response.data);
    routines.value = response.data.payload || [];
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[RoutinesAgenda] Error:', error);
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  loadRoutines();
});

const hasRoutines = computed(() => routines.value.length > 0);
const hasVisibleRoutines = computed(() => 
  routines.value.some(r => !r.completed)
);

const toggleComplete = async routine => {
  try {
    if (routine.completed) {
      await RoutinesAPI.unmarkComplete(routine.id);
    } else {
      await RoutinesAPI.markComplete(routine.id);
    }
    routine.completed = !routine.completed;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('[RoutinesAgenda] Toggle error:', error);
  }
};
</script>

<template>
  <section
    v-if="!isLoading && hasVisibleRoutines"
    :aria-label="$t('ROUTINES.AGENDA.TITLE')"
    class="flex flex-col w-full gap-2 px-4 py-3 border-b border-n-weak bg-n-solid-2"
  >
    <div class="flex items-center justify-between gap-2">
      <div class="flex items-center gap-2">
        <span
          class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-n-blue-3 text-n-blue-text"
        >
          <span class="i-lucide-calendar-days size-3.5" />
        </span>
        <div class="flex flex-col">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ $t('ROUTINES.AGENDA.TITLE') }}
          </h2>
          <p class="text-xs text-n-slate-11">
            {{ $t('ROUTINES.AGENDA.DESCRIPTION') }}
          </p>
        </div>
      </div>
    </div>

    <div class="mt-1">
      <div
        v-if="hasError"
        class="py-1 text-xs text-ruby-11"
      >
        {{ $t('GENERAL.ERROR') }}
      </div>
      <ul v-else class="flex flex-col gap-1">
        <li
          v-for="routine in routines"
          v-show="!routine.completed"
          :key="routine.id"
          class="flex items-start justify-between gap-3 text-xs"
        >
          <div
            class="flex items-center justify-center flex-shrink-0 w-10 h-6 text-[11px] font-medium rounded-full bg-n-solid-1 text-n-slate-11 border border-n-weak"
          >
            {{ routine.time_of_day }}
          </div>
          <div class="flex-1 min-w-0">
            <p class="font-medium truncate text-n-slate-12">
              {{ routine.title }}
            </p>
            <p
              v-if="routine.description"
              class="mt-0.5 text-[11px] leading-snug text-n-slate-11 line-clamp-2"
            >
              {{ routine.description }}
            </p>
          </div>
          <button
            type="button"
            class="flex-shrink-0 inline-flex items-center justify-center w-5 h-5 border rounded border-n-weak bg-n-solid-1 hover:bg-n-solid-3 transition-colors"
            :aria-label="$t('ROUTINES.AGENDA.MARK_COMPLETE')"
            @click="toggleComplete(routine)"
          >
            <span class="i-lucide-check size-3 text-n-slate-11" />
          </button>
        </li>
      </ul>
    </div>
  </section>
</template>


