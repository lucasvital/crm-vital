<script setup>
import { computed } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  routine: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();

const weekdayLabelKey = computed(() => {
  return `ROUTINES.WEEKDAY.${props.routine.weekday.toUpperCase()}`;
});
</script>

<template>
  <tr>
    <td class="py-4 ltr:pr-4 rtl:pl-4">
      {{ $t(weekdayLabelKey) }}
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4">
      {{ routine.time_of_day }}
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4 truncate">
      {{ routine.title }}
      <p v-if="routine.description" class="mt-1 text-xs text-n-slate-10">
        {{ routine.description }}
      </p>
    </td>
    <td class="py-4 ltr:pr-4 rtl:pl-4">
      <span
        class="inline-flex items-center px-2 py-0.5 text-xs font-medium rounded-full"
        :class="
          routine.active
            ? 'bg-emerald-3 text-emerald-11'
            : 'bg-n-slate-3 text-n-slate-11'
        "
      >
        {{
          routine.active
            ? $t('ROUTINES.STATUS.ACTIVE')
            : $t('ROUTINES.STATUS.INACTIVE')
        }}
      </span>
    </td>
    <td class="py-4 flex justify-end gap-1">
      <Button
        v-tooltip.top="$t('ROUTINES.EDIT.TOOLTIP')"
        icon="i-lucide-pen"
        slate
        xs
        faded
        @click="$emit('edit', routine)"
      />
      <Button
        v-tooltip.top="$t('ROUTINES.DELETE.TOOLTIP')"
        icon="i-lucide-trash-2"
        xs
        ruby
        faded
        @click="$emit('delete', routine)"
      />
    </td>
  </tr>
</template>


