<script setup>
import { ref, onMounted } from 'vue';
import Draggable from 'vuedraggable';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import PipelinesAPI from 'dashboard/api/pipelines';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';
import WebhookList from './components/WebhookList.vue';

const { t } = useI18n();
const { accountId } = useAccount();
const alert = useAlert;

const pipelines = ref([]);
const newPipelineName = ref('');
const expandedId = ref(null);
const stageName = ref('');
const showModal = ref(false);
const editingPipeline = ref(null);
const editingPipelineName = ref('');
const editingStages = ref([]);
const showDuplicateModal = ref(false);
const duplicateSourcePipeline = ref(null);
const duplicatePipelineName = ref('');
const activeTab = ref('settings'); // 'settings' ou 'webhooks'

const load = async () => {
  const { data } = await PipelinesAPI.get();
  pipelines.value = data || [];
};

const createPipeline = async () => {
  if (!newPipelineName.value) return;
  try {
    await PipelinesAPI.create({ pipeline: { name: newPipelineName.value } });
    newPipelineName.value = '';
    await load();
    alert(t('PIPELINES.ALERTS.CREATE_SUCCESS'));
  } catch (error) {
    alert(error.message || t('PIPELINES.ALERTS.CREATE_ERROR'));
  }
};

const renamePipeline = async (pipeline, name) => {
  try {
    await PipelinesAPI.update(pipeline.id, { pipeline: { name } });
    await load();
    alert(t('PIPELINES.ALERTS.UPDATE_SUCCESS'));
  } catch (error) {
    alert(error.message || t('PIPELINES.ALERTS.UPDATE_ERROR'));
  }
};

const deletePipeline = async pipeline => {
  if (!confirm('Tem certeza que deseja remover este pipeline?')) return;
  try {
    await PipelinesAPI.delete(pipeline.id);
    await load();
    alert(t('PIPELINES.ALERTS.DELETE_SUCCESS'));
  } catch (error) {
    alert(error.message || t('PIPELINES.ALERTS.DELETE_ERROR'));
  }
};

const openDuplicateModal = pipe => {
  duplicateSourcePipeline.value = pipe;
  duplicatePipelineName.value = `${pipe.name} (cópia)`;
  showDuplicateModal.value = true;
};

const duplicatePipeline = async () => {
  if (!duplicateSourcePipeline.value || !duplicatePipelineName.value) return;
  try {
    const { data: original } = await PipelinesAPI.show(
      duplicateSourcePipeline.value.id
    );

    const { data: newPipeline } = await PipelinesAPI.create({
      pipeline: { name: duplicatePipelineName.value },
    });

    const stages = (original.pipeline_stages || [])
      .slice()
      .sort((a, b) => a.position - b.position);

    for (const stage of stages) {
      // eslint-disable-next-line no-await-in-loop
      await PipelinesAPI.createStage(newPipeline.id, {
        name: stage.name,
        is_won: stage.is_won,
      });
    }

    const { data: refreshed } = await PipelinesAPI.show(newPipeline.id);
    const newStages = (refreshed.pipeline_stages || [])
      .slice()
      .sort((a, b) => a.position - b.position);
    const order = newStages.map((s, i) => ({ id: s.id, position: i + 1 }));
    await PipelinesAPI.reorderStages(newPipeline.id, order);

    await load();
    showDuplicateModal.value = false;
    duplicateSourcePipeline.value = null;
    duplicatePipelineName.value = '';
    alert(t('PIPELINES.ALERTS.DUPLICATE_SUCCESS'));
  } catch (error) {
    alert(error.message || t('PIPELINES.ALERTS.DUPLICATE_ERROR'));
  }
};

const toggleExpand = pipe => {
  expandedId.value = expandedId.value === pipe.id ? null : pipe.id;
};

const createStage = async pipe => {
  if (!stageName.value) return;
  await PipelinesAPI.createStage(pipe.id, { name: stageName.value });
  stageName.value = '';
  await load();
  alert(t('LABEL_MGMT.ADD.SUCCESS'));
};

const updateStage = async (pipe, st, name) => {
  await PipelinesAPI.updateStage(pipe.id, st.id, { name });
  await load();
  alert(t('GENERAL_SETTINGS.UPDATE.SUCCESS'));
};

const deleteStage = async (pipe, st) => {
  await PipelinesAPI.deleteStage(pipe.id, st.id);
  await load();
  alert(t('LABEL_MGMT.DELETE.SUCCESS'));
};

const moveStage = async (pipe, st, direction) => {
  const list = (pipe.pipeline_stages || []).slice().sort((a, b) => a.position - b.position);
  const idx = list.findIndex(s => s.id === st.id);
  const swapWith = direction === 'up' ? idx - 1 : idx + 1;
  if (swapWith < 0 || swapWith >= list.length) return;
  const tmp = list[idx];
  list[idx] = list[swapWith];
  list[swapWith] = tmp;
  const order = list.map((s, i) => ({ id: s.id, position: i + 1 }));
  await PipelinesAPI.reorderStages(pipe.id, order);
  await load();
};

const pipelineHasWonStage = stages =>
  Array.isArray(stages) && stages.some(stage => stage.is_won);

const openModal = async pipe => {
  activeTab.value = 'settings'; // Reset para aba de configurações
  const pipelineId = pipe.id;
  let { data } = await PipelinesAPI.show(pipelineId);
  editingPipeline.value = data;
  editingPipelineName.value = data.name;
  let stages = (data.pipeline_stages || [])
    .slice()
    .sort((a, b) => a.position - b.position);

  // Garante que sempre exista uma etapa marcada como ganho:
  // - Se não houver nenhuma etapa, cria uma etapa padrão "Ganho"
  // - Se houver etapas mas nenhuma marcada como ganho, marca a última como ganho
  if (!pipelineHasWonStage(stages)) {
    if (stages.length === 0) {
      await PipelinesAPI.createStage(pipelineId, { name: 'Ganho' });
      ({ data } = await PipelinesAPI.show(pipelineId));
      stages = (data.pipeline_stages || [])
        .slice()
        .sort((a, b) => a.position - b.position);
    }

    const wonStage = stages[stages.length - 1];
    if (wonStage) {
      await PipelinesAPI.updateStage(pipelineId, wonStage.id, { is_won: true });
      ({ data } = await PipelinesAPI.show(pipelineId));
      stages = (data.pipeline_stages || [])
        .slice()
        .sort((a, b) => a.position - b.position);
    }
  }

  editingStages.value = stages;
  showModal.value = true;
};

const savePipeline = async () => {
  if (!editingPipeline.value) return;
  await PipelinesAPI.update(editingPipeline.value.id, {
    pipeline: { name: editingPipelineName.value },
  });
  await load();
  showModal.value = false;
  alert(t('GENERAL_SETTINGS.UPDATE.SUCCESS'));
};

const addStageInModal = async () => {
  if (!editingPipeline.value || !stageName.value) return;
  const previousIds = editingStages.value.map(s => s.id);
  await PipelinesAPI.createStage(editingPipeline.value.id, {
    name: stageName.value,
  });
  stageName.value = '';
  const { data } = await PipelinesAPI.show(editingPipeline.value.id);
  const fetched = (data.pipeline_stages || []).slice();
  const newStages = fetched.filter(s => !previousIds.includes(s.id));
  const existingStages = fetched.filter(s => previousIds.includes(s.id));
  editingStages.value = [...existingStages, ...newStages].map((s, i) => ({
    ...s,
    position: i + 1,
  }));
  const order = editingStages.value.map((s, i) => ({
    id: s.id,
    position: i + 1,
  }));
  await PipelinesAPI.reorderStages(editingPipeline.value.id, order);
  await load();
};

const renameStageInModal = async (st, name) => {
  if (!editingPipeline.value) return;
  await PipelinesAPI.updateStage(editingPipeline.value.id, st.id, { name });
  const { data } = await PipelinesAPI.show(editingPipeline.value.id);
  editingStages.value = (data.pipeline_stages || []).slice().sort((a, b) => a.position - b.position);
  alert(t('GENERAL_SETTINGS.UPDATE.SUCCESS'));
};

const setWonStage = async st => {
  if (!editingPipeline.value || st.is_won) return;
  await PipelinesAPI.updateStage(editingPipeline.value.id, st.id, { is_won: true });
  const { data } = await PipelinesAPI.show(editingPipeline.value.id);
  editingStages.value = (data.pipeline_stages || []).slice().sort((a, b) => a.position - b.position);
  await load();
};

const deleteStageInModal = async st => {
  if (!editingPipeline.value) return;
  if (st.is_won) {
    alert(t('PIPELINES.VALIDATIONS.WON_STAGE_REQUIRED'));
    return;
  }
  await PipelinesAPI.deleteStage(editingPipeline.value.id, st.id);
  const { data } = await PipelinesAPI.show(editingPipeline.value.id);
  editingStages.value = (data.pipeline_stages || [])
    .slice()
    .sort((a, b) => a.position - b.position);
  await load();
};

const onStagesReordered = async newOrder => {
  if (!editingPipeline.value) return;
  editingStages.value = newOrder.slice();
  const order = editingStages.value.map((s, i) => ({
    id: s.id,
    position: i + 1,
  }));
  await PipelinesAPI.reorderStages(editingPipeline.value.id, order);
  await load();
};
onMounted(load);
</script>

<template>
  <div class="flex flex-col max-w-4xl mx-auto w-full">
    <BaseSettingsHeader title="Pipelines" />
    <div class="mt-4 rounded-xl border border-n-alpha-2 bg-n-solid-1 p-4">
      <div class="flex items-center gap-2">
        <input
          v-model="newPipelineName"
          type="text"
          class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
          placeholder="Novo pipeline"
        />
        <button
          class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-solid-2"
          @click="createPipeline"
        >
          Criar
        </button>
      </div>
      <div class="mt-4 space-y-3">
        <div
          v-for="pipe in pipelines"
          :key="pipe.id"
          class="flex items-center justify-between rounded-lg border border-n-alpha-2 bg-n-solid-2 p-3 cursor-pointer hover:bg-n-solid-3"
          @click="openModal(pipe)"
        >
          <div class="flex items-center gap-2 text-sm font-medium text-n-slate-12">
            {{ pipe.name }}
            <span class="text-xs text-n-slate-11">• {{ (pipe.pipeline_stages || []).length }} etapas</span>
          </div>
          <div class="flex items-center gap-2">
            <button
              class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-1 text-xs font-medium text-n-blue-11 hover:bg-n-blue-3"
              @click.stop="openDuplicateModal(pipe)"
            >
              Duplicar
            </button>
            <button
              class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-1 text-xs font-medium text-n-ruby-11 hover:bg-n-ruby-3"
              @click.stop="deletePipeline(pipe)"
            >
              Remover
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal de edição do Pipeline -->
    <woot-modal :show="showModal" :on-close="() => (showModal = false)">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header header-title="Editar Pipeline" />
        
        <!-- Tabs -->
        <div class="flex border-b border-n-alpha-2 px-6">
          <button
            type="button"
            class="px-4 py-3 text-sm font-medium border-b-2 transition-colors"
            :class="activeTab === 'settings' ? 'border-n-brand text-n-brand' : 'border-transparent text-n-slate-11 hover:text-n-slate-12'"
            @click="activeTab = 'settings'"
          >
            Configurações
          </button>
          <button
            type="button"
            class="px-4 py-3 text-sm font-medium border-b-2 transition-colors"
            :class="activeTab === 'webhooks' ? 'border-n-brand text-n-brand' : 'border-transparent text-n-slate-11 hover:text-n-slate-12'"
            @click="activeTab = 'webhooks'"
          >
            Webhooks
          </button>
        </div>

        <!-- Tab: Configurações -->
        <div v-show="activeTab === 'settings'" class="px-6 py-4 space-y-3">
          <div>
            <label class="text-sm text-n-slate-12 mb-1 block">Nome do pipeline</label>
            <input
              v-model="editingPipelineName"
              type="text"
              class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
              placeholder="Nome do pipeline"
            />
          </div>
          <div class="space-y-2">
            <div class="flex items-center gap-2">
              <input
                v-model="stageName"
                type="text"
                class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
                placeholder="Nome da etapa (ex.: Qualificado)"
              />
              <button
                class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-solid-2"
                @click="addStageInModal"
              >
                Adicionar etapa
              </button>
            </div>
            <Draggable
              v-model="editingStages"
              item-key="id"
              ghost-class="ghost"
              handle=".stage-drag-handle"
              class="space-y-2"
              @update:model-value="onStagesReordered"
            >
              <template #item="{ element: st }">
                <li
                  :key="st.id"
                  class="flex items-center gap-2 rounded-md border border-n-alpha-2 bg-n-solid-2 p-2"
                >
                  <button
                    type="button"
                    class="stage-drag-handle inline-flex items-center justify-center rounded-md border border-n-alpha-2 bg-n-solid-1 p-1 text-xs text-n-slate-11 cursor-grab active:cursor-grabbing"
                    aria-label="Reordenar etapa"
                  >
                    <span class="i-lucide-grip-vertical size-4" />
                  </button>
                  <input
                    :value="st.name"
                    class="flex-1 rounded-md border border-n-alpha-2 bg-n-solid-1 px-2 py-1 text-sm"
                    @change="e => renameStageInModal(st, e.target.value)"
                  />
                  <button
                    type="button"
                    class="rounded-md border px-2 py-1 text-2xs font-medium transition-colors"
                    :class="st.is_won
                      ? 'border-n-grass-7 bg-n-grass-3 text-n-grass-11 cursor-default'
                      : 'border-n-alpha-2 bg-n-solid-1 text-n-slate-11 hover:border-n-grass-7 hover:text-n-grass-11'"
                    :title="st.is_won ? 'Esta é a etapa de ganho' : 'Marcar como etapa de ganho'"
                    @click="setWonStage(st)"
                  >
                    {{ st.is_won ? '✓ Ganho' : 'Marcar ganho' }}
                  </button>
                  <button
                    type="button"
                    class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-1 text-xs font-medium text-n-ruby-11 hover:bg-n-ruby-3"
                    :disabled="st.is_won"
                    @click="deleteStageInModal(st)"
                  >
                    Remover
                  </button>
                </li>
              </template>
            </Draggable>
          </div>
        </div>

        <!-- Tab: Webhooks -->
        <div v-show="activeTab === 'webhooks'" class="px-6 py-4 max-h-[500px] overflow-y-auto">
          <WebhookList v-if="editingPipeline" :pipeline="editingPipeline" />
        </div>

        <div v-show="activeTab === 'settings'" class="w-full flex justify-end gap-2 items-center px-6 pb-4 border-t border-n-alpha-2">
          <button
            type="button"
            class="rounded-md border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            @click="() => (showModal = false)"
          >
            Cancelar
          </button>
          <button
            type="button"
            class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-solid-2"
            @click="savePipeline"
          >
            Salvar
          </button>
        </div>
      </div>
    </woot-modal>

    <!-- Modal de duplicação -->
    <woot-modal
      :show="showDuplicateModal"
      :on-close="() => (showDuplicateModal = false)"
    >
      <div class="flex flex-col h-auto">
        <woot-modal-header header-title="Duplicar Pipeline" />
        <div class="px-6 py-4">
          <label class="text-sm text-n-slate-12 mb-1 block"
            >Nome do novo pipeline</label
          >
          <input
            v-model="duplicatePipelineName"
            type="text"
            class="w-full rounded-md border border-n-alpha-2 bg-n-solid-1 px-3 py-2 text-sm"
            placeholder="Nome do pipeline"
            @keyup.enter="duplicatePipeline"
          />
        </div>
        <div class="w-full flex justify-end gap-2 items-center px-6 pb-4">
          <button
            type="button"
            class="rounded-md border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            @click="() => (showDuplicateModal = false)"
          >
            Cancelar
          </button>
          <button
            type="button"
            class="rounded-md border border-n-strong bg-n-solid-1 px-3 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-solid-2"
            @click="duplicatePipeline"
          >
            Duplicar
          </button>
        </div>
      </div>
    </woot-modal>
  </div>
</template>


