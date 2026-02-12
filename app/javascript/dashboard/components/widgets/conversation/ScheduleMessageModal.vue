<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  messageContent: { type: String, required: true },
  isPrivateNote: { type: Boolean, default: false },
});

const emit = defineEmits(['cancel', 'schedule', 'update:show']);

const { t } = useI18n();
const selectedDate = ref('');
const selectedTime = ref('');

const localShow = computed({
  get: () => props.show,
  set: value => emit('update:show', value),
});

const minDateTime = computed(() => {
  const now = new Date();
  now.setMinutes(now.getMinutes() + 1);
  return now;
});

const minDate = computed(() => {
  return minDateTime.value.toISOString().split('T')[0];
});

const minTime = computed(() => {
  if (selectedDate.value === minDate.value) {
    const hours = minDateTime.value.getHours().toString().padStart(2, '0');
    const minutes = minDateTime.value.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }
  return '00:00';
});

const canSchedule = computed(() => {
  if (!selectedDate.value || !selectedTime.value) return false;

  const scheduledDateTime = new Date(
    `${selectedDate.value}T${selectedTime.value}`
  );
  return scheduledDateTime > minDateTime.value;
});

const quickOptions = [
  { label: t('SCHEDULED_MESSAGES.QUICK_OPTIONS.IN_1_HOUR'), minutes: 60 },
  { label: t('SCHEDULED_MESSAGES.QUICK_OPTIONS.IN_3_HOURS'), minutes: 180 },
  {
    label: t('SCHEDULED_MESSAGES.QUICK_OPTIONS.TOMORROW_9AM'),
    time: 'tomorrow_9am',
  },
  {
    label: t('SCHEDULED_MESSAGES.QUICK_OPTIONS.NEXT_MONDAY_9AM'),
    time: 'next_monday_9am',
  },
];

const setQuickOption = option => {
  const now = new Date();
  let targetDate;

  if (option.minutes) {
    targetDate = new Date(now.getTime() + option.minutes * 60000);
  } else if (option.time === 'tomorrow_9am') {
    targetDate = new Date(now);
    targetDate.setDate(targetDate.getDate() + 1);
    targetDate.setHours(9, 0, 0, 0);
  } else if (option.time === 'next_monday_9am') {
    targetDate = new Date(now);
    const daysUntilMonday = (8 - targetDate.getDay()) % 7 || 7;
    targetDate.setDate(targetDate.getDate() + daysUntilMonday);
    targetDate.setHours(9, 0, 0, 0);
  }

  selectedDate.value = targetDate.toISOString().split('T')[0];
  selectedTime.value = targetDate.toTimeString().slice(0, 5);
};

const handleSchedule = () => {
  const scheduledAt = new Date(
    `${selectedDate.value}T${selectedTime.value}`
  );
  emit('schedule', scheduledAt.toISOString());
};

const handleCancel = () => {
  selectedDate.value = '';
  selectedTime.value = '';
  emit('cancel');
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="handleCancel">
    <div class="flex flex-col">
      <woot-modal-header
        :header-title="$t('SCHEDULED_MESSAGES.TITLE')"
        :header-content="$t('SCHEDULED_MESSAGES.DESCRIPTION')"
      />

      <div class="px-4 py-4 space-y-4">
        <!-- Quick options -->
        <div>
          <label class="text-sm font-medium text-n-slate-12 mb-2 block">
            {{ $t('SCHEDULED_MESSAGES.QUICK_OPTIONS.LABEL') }}
          </label>
          <div class="grid grid-cols-2 gap-2">
            <NextButton
              v-for="option in quickOptions"
              :key="option.label"
              faded
              slate
              size="small"
              :label="option.label"
              @click="setQuickOption(option)"
            />
          </div>
        </div>

        <!-- Custom date/time -->
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="text-sm font-medium text-n-slate-12 mb-1 block">
              {{ $t('SCHEDULED_MESSAGES.DATE_LABEL') }}
            </label>
            <input
              v-model="selectedDate"
              type="date"
              :min="minDate"
              class="w-full px-3 py-2 border border-n-alpha-2 rounded-md"
            />
          </div>
          <div>
            <label class="text-sm font-medium text-n-slate-12 mb-1 block">
              {{ $t('SCHEDULED_MESSAGES.TIME_LABEL') }}
            </label>
            <input
              v-model="selectedTime"
              type="time"
              :min="minTime"
              class="w-full px-3 py-2 border border-n-alpha-2 rounded-md"
            />
          </div>
        </div>

        <!-- Preview -->
        <div
          v-if="canSchedule"
          class="p-3 bg-n-blue-3 border border-n-blue-7 rounded-md"
        >
          <p class="text-sm text-n-blue-11">
            {{
              $t('SCHEDULED_MESSAGES.PREVIEW', {
                date: new Date(
                  `${selectedDate}T${selectedTime}`
                ).toLocaleString(),
              })
            }}
          </p>
        </div>

        <!-- Message preview -->
        <div>
          <label class="text-sm font-medium text-n-slate-12 mb-1 block">
            {{ $t('SCHEDULED_MESSAGES.MESSAGE_PREVIEW') }}
          </label>
          <div
            class="p-3 bg-n-solid-2 border border-n-alpha-2 rounded-md max-h-32 overflow-y-auto"
          >
            <p class="text-sm text-n-slate-11">{{ messageContent }}</p>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex justify-end gap-2 px-4 py-4 border-t border-n-alpha-2">
        <NextButton
          faded
          slate
          :label="$t('SCHEDULED_MESSAGES.CANCEL')"
          @click="handleCancel"
        />
        <NextButton
          :label="$t('SCHEDULED_MESSAGES.SCHEDULE')"
          :disabled="!canSchedule"
          icon="i-ph-clock"
          @click="handleSchedule"
        />
      </div>
    </div>
  </woot-modal>
</template>
