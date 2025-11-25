<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import RoutinesTableRow from './RoutinesTableRow.vue';
import RoutineForm from './RoutineForm.vue';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const records = computed(() => getters['routines/getRoutines'].value);
const uiFlags = computed(() => getters['routines/getRoutinesUIFlags'].value);

const showForm = ref(false);
const editingRoutine = ref(null);

const showDeleteConfirmationPopup = ref(false);
const selectedRoutine = ref(null);

onMounted(() => {
  showForm.value = false;
  editingRoutine.value = null;
  showDeleteConfirmationPopup.value = false;
  selectedRoutine.value = null;
  store.dispatch('routines/get');
});

const openCreateForm = () => {
  editingRoutine.value = null;
  showForm.value = true;
};

const openEditForm = routine => {
  editingRoutine.value = routine;
  showForm.value = true;
};

const closeForm = () => {
  showForm.value = false;
  editingRoutine.value = null;
};

const openDeletePopup = routine => {
  selectedRoutine.value = routine;
  showDeleteConfirmationPopup.value = true;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
  selectedRoutine.value = null;
};

const deleteRoutine = async () => {
  if (!selectedRoutine.value) return;
  try {
    await store.dispatch('routines/delete', selectedRoutine.value.id);
    useAlert(t('ROUTINES.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('ROUTINES.DELETE.API.ERROR_MESSAGE'));
  } finally {
    closeDeletePopup();
  }
};
</script>

<template>
  <SettingsLayout
    :no-records-message="$t('ROUTINES.LIST.404')"
    :no-records-found="!records.length && !uiFlags.isFetching"
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('ROUTINES.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('ROUTINES.HEADER')"
        :description="$t('ROUTINES.DESCRIPTION')"
        icon-name="calendar"
        feature-name="routines"
      >
        <template #actions>
          <Button
            icon="i-lucide-circle-plus"
            :label="$t('ROUTINES.HEADER_BTN_TXT')"
            @click="openCreateForm"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <table class="min-w-full divide-y divide-n-weak">
        <thead>
          <tr>
            <th
              class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
            >
              {{ $t('ROUTINES.LIST.TABLE_HEADER.WEEKDAY') }}
            </th>
            <th
              class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
            >
              {{ $t('ROUTINES.LIST.TABLE_HEADER.TIME') }}
            </th>
            <th
              class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
            >
              {{ $t('ROUTINES.LIST.TABLE_HEADER.TITLE') }}
            </th>
            <th
              class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
            >
              {{ $t('ROUTINES.LIST.TABLE_HEADER.STATUS') }}
            </th>
            <th class="py-4 ltr:pr-4 rtl:pl-4 text-right" />
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak text-n-slate-11">
          <RoutinesTableRow
            v-for="routine in records"
            :key="routine.id"
            :routine="routine"
            @edit="openEditForm"
            @delete="openDeletePopup"
          />
        </tbody>
      </table>
    </template>
  </SettingsLayout>

  <!-- Modal fora do SettingsLayout -->
  <woot-modal :show="showForm" :on-close="closeForm">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="
          editingRoutine
            ? $t('ROUTINES.EDIT.TITLE')
            : $t('ROUTINES.CREATE.TITLE')
        "
      />
      <div class="px-6 py-4">
        <RoutineForm
          :routine="editingRoutine"
          :ui-flags="uiFlags"
          @close="closeForm"
        />
      </div>
    </div>
  </woot-modal>

  <woot-delete-modal
    :show="showDeleteConfirmationPopup"
    :on-close="closeDeletePopup"
    :on-confirm="deleteRoutine"
    :title="$t('ROUTINES.DELETE.CONFIRM.TITLE')"
    :message="$t('ROUTINES.DELETE.CONFIRM.MESSAGE')"
    :message-value="selectedRoutine && selectedRoutine.title"
    :confirm-text="$t('ROUTINES.DELETE.CONFIRM.YES')"
    :reject-text="$t('ROUTINES.DELETE.CONFIRM.NO')"
  />
</template>
