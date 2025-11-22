<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  routine: {
    type: Object,
    default: null,
  },
  uiFlags: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const form = reactive({
  title: '',
  description: '',
  weekday: 'monday',
  time_of_day: '09:00',
  active: true,
});

const isEditing = computed(() => !!props.routine);

watch(
  () => props.routine,
  newVal => {
    if (newVal) {
      form.title = newVal.title || '';
      form.description = newVal.description || '';
      form.weekday = newVal.weekday || 'monday';
      form.time_of_day = newVal.time_of_day || '09:00';
      form.active = newVal.active ?? true;
    } else {
      form.title = '';
      form.description = '';
      form.weekday = 'monday';
      form.time_of_day = '09:00';
      form.active = true;
    }
  },
  { immediate: true }
);

const weekdayOptions = computed(() => [
  { value: 'monday', label: t('ROUTINES.WEEKDAY.MONDAY') },
  { value: 'tuesday', label: t('ROUTINES.WEEKDAY.TUESDAY') },
  { value: 'wednesday', label: t('ROUTINES.WEEKDAY.WEDNESDAY') },
  { value: 'thursday', label: t('ROUTINES.WEEKDAY.THURSDAY') },
  { value: 'friday', label: t('ROUTINES.WEEKDAY.FRIDAY') },
]);

const isSubmitting = computed(
  () => props.uiFlags.isCreating || props.uiFlags.isUpdating
);

const onSubmit = async () => {
  const payload = {
    title: form.title,
    description: form.description,
    weekday: form.weekday,
    time_of_day: form.time_of_day,
    active: form.active,
  };

  try {
    if (isEditing.value) {
      await store.dispatch('routines/update', {
        id: props.routine.id,
        ...payload,
      });
      useAlert(t('ROUTINES.EDIT.API.SUCCESS_MESSAGE'));
    } else {
      await store.dispatch('routines/create', payload);
      useAlert(t('ROUTINES.CREATE.API.SUCCESS_MESSAGE'));
    }
    emit('close');
  } catch (error) {
    // handled via useAlert in store utils
  }
};
</script>

<template>
  <form
    class="grid gap-4"
    @submit.prevent="onSubmit"
  >
      <div class="grid gap-1">
        <label class="text-xs font-medium text-n-slate-11">
          {{ $t('ROUTINES.FORM.WEEKDAY') }}
        </label>
        <select
          v-model="form.weekday"
          class="w-full px-3 py-2 text-sm border rounded-md bg-n-solid-1 border-n-weak text-n-slate-12"
        >
          <option
            v-for="opt in weekdayOptions"
            :key="opt.value"
            :value="opt.value"
          >
            {{ opt.label }}
          </option>
        </select>
      </div>

      <div class="grid gap-1">
        <label class="text-xs font-medium text-n-slate-11">
          {{ $t('ROUTINES.FORM.TIME') }}
        </label>
        <input
          v-model="form.time_of_day"
          type="time"
          class="w-full px-3 py-2 text-sm border rounded-md bg-n-solid-1 border-n-weak text-n-slate-12"
        />
      </div>

      <div class="grid gap-1">
        <label class="text-xs font-medium text-n-slate-11">
          {{ $t('ROUTINES.FORM.TITLE') }}
        </label>
        <input
          v-model="form.title"
          type="text"
          class="w-full px-3 py-2 text-sm border rounded-md bg-n-solid-1 border-n-weak text-n-slate-12"
        />
      </div>

      <div class="grid gap-1">
        <label class="text-xs font-medium text-n-slate-11">
          {{ $t('ROUTINES.FORM.DESCRIPTION') }}
        </label>
        <textarea
          v-model="form.description"
          rows="3"
          class="w-full px-3 py-2 text-sm border rounded-md resize-none bg-n-solid-1 border-n-weak text-n-slate-12"
        />
      </div>

      <div class="flex items-center gap-2">
        <input
          id="routine-active"
          v-model="form.active"
          type="checkbox"
          class="w-4 h-4 border rounded bg-n-solid-1 border-n-weak"
        />
        <label
          for="routine-active"
          class="text-xs font-medium text-n-slate-11"
        >
          {{ $t('ROUTINES.FORM.ACTIVE') }}
        </label>
      </div>

      <div class="flex justify-end gap-2 pt-2">
        <Button
          slate
          variant="ghost"
          :label="$t('ROUTINES.FORM.CANCEL')"
          @click="emit('close')"
        />
        <Button
          blue
          type="submit"
          :loading="isSubmitting"
          :label="
            isEditing
              ? $t('ROUTINES.FORM.SAVE')
              : $t('ROUTINES.FORM.CREATE')
          "
        />
      </div>
    </form>
</template>


