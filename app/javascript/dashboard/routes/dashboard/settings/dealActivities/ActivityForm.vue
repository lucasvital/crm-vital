<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStoreGetters } from 'dashboard/composables/store';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DealActivitiesAPI from 'dashboard/api/dealActivities';
import PipelinesAPI from 'dashboard/api/pipelines';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const getters = useStoreGetters();

const accountId = computed(() => getters.getCurrentAccountId.value);
const isEditMode = computed(() => !!route.params.activityId);

const pipelines = ref([]);
const stages = ref([]);
const loading = ref(false);
const saving = ref(false);

const form = ref({
  title: '',
  description: '',
  pipeline_id: null,
  pipeline_stage_id: null,
  move_to_stage_id: null,
  messages: [{ content: '' }],
});

const availableStagesForMove = computed(() => {
  if (!form.value.pipeline_stage_id) return stages.value;
  return stages.value.filter(s => s.id !== form.value.pipeline_stage_id);
});

const selectedPipeline = computed({
  get: () => form.value.pipeline_id,
  set: async value => {
    form.value.pipeline_id = value;
    form.value.pipeline_stage_id = null;
    await loadStages();
  },
});

const fetchPipelines = async () => {
  loading.value = true;
  try {
    const { data } = await PipelinesAPI.get();
    pipelines.value = data || [];
    if (pipelines.value.length > 0 && !form.value.pipeline_id) {
      form.value.pipeline_id = pipelines.value[0].id;
      await loadStages();
    }
  } catch (error) {
    console.error('Error fetching pipelines:', error);
    useAlert(t('DEAL_ACTIVITIES_SETTINGS.ERRORS.FETCH_FAILED'));
  } finally {
    loading.value = false;
  }
};

const loadStages = async () => {
  if (!form.value.pipeline_id) {
    stages.value = [];
    return;
  }
  
  try {
    const { data } = await PipelinesAPI.getStages(form.value.pipeline_id);
    stages.value = data || [];
    
    if (stages.value.length > 0 && !form.value.pipeline_stage_id) {
      form.value.pipeline_stage_id = stages.value[0].id;
    }
  } catch (error) {
    console.error('Error fetching stages:', error);
    stages.value = [];
  }
};

const fetchActivity = async () => {
  if (!isEditMode.value) return;
  
  loading.value = true;
  try {
    const response = await DealActivitiesAPI.get();
    const activity = response.data?.find(
      a => a.id === parseInt(route.params.activityId, 10)
    );
    
    if (activity) {
      form.value = {
        title: activity.title,
        description: activity.description || '',
        pipeline_id: null,
        pipeline_stage_id: activity.pipeline_stage_id,
        move_to_stage_id: activity.move_to_stage_id || null,
        messages: activity.messages?.length > 0 ? activity.messages : [{ content: '' }],
      };
      
      // Encontrar o pipeline baseado no stage
      // Vamos buscar os stages de cada pipeline para encontrar qual contém o stage_id
      for (const pipeline of pipelines.value) {
        try {
          const { data: pipelineStages } = await PipelinesAPI.getStages(pipeline.id);
          if (pipelineStages?.some(s => s.id === activity.pipeline_stage_id)) {
            form.value.pipeline_id = pipeline.id;
            await loadStages();
            break;
          }
        } catch (error) {
          console.error('Error checking stages for pipeline:', pipeline.id, error);
        }
      }
    }
  } catch (error) {
    console.error('Error fetching activity:', error);
    useAlert(t('DEAL_ACTIVITIES_SETTINGS.ERRORS.FETCH_FAILED'));
  } finally {
    loading.value = false;
  }
};

const addMessage = () => {
  form.value.messages.push({ content: '' });
};

const removeMessage = index => {
  if (form.value.messages.length > 1) {
    form.value.messages.splice(index, 1);
  }
};

const moveMessageUp = index => {
  if (index > 0) {
    const temp = form.value.messages[index];
    form.value.messages[index] = form.value.messages[index - 1];
    form.value.messages[index - 1] = temp;
  }
};

const moveMessageDown = index => {
  if (index < form.value.messages.length - 1) {
    const temp = form.value.messages[index];
    form.value.messages[index] = form.value.messages[index + 1];
    form.value.messages[index + 1] = temp;
  }
};

// Refs para os textareas
const messageTextareas = ref([]);

// Inserir variável no textarea na posição do cursor
const insertVariable = (variable, index) => {
  const textarea = messageTextareas.value[index];
  if (!textarea) return;
  
  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  const text = form.value.messages[index].content;
  
  // Inserir a variável na posição do cursor
  const before = text.substring(0, start);
  const after = text.substring(end);
  form.value.messages[index].content = before + variable + after;
  
  // Reposicionar cursor após a variável inserida
  setTimeout(() => {
    const newPosition = start + variable.length;
    textarea.focus();
    textarea.setSelectionRange(newPosition, newPosition);
  }, 0);
};

const isFormValid = computed(() => {
  return (
    form.value.title.trim() !== '' &&
    form.value.pipeline_stage_id &&
    form.value.messages.length > 0 &&
    form.value.messages.every(m => m.content.trim() !== '')
  );
});

// Rastrear qual textarea está em foco
const currentMessageIndex = ref(0);

const goBack = () => {
  router.push({
    name: 'deal_activities_index',
    params: { accountId: accountId.value },
  });
};

const handleSubmit = async () => {
  if (!isFormValid.value) {
    useAlert(t('DEAL_ACTIVITIES_SETTINGS.ERRORS.INVALID_FORM'));
    return;
  }
  
  saving.value = true;
  try {
    const payload = {
      deal_activity: {
        title: form.value.title,
        description: form.value.description,
        pipeline_stage_id: form.value.pipeline_stage_id,
        move_to_stage_id: form.value.move_to_stage_id || null,
        messages: form.value.messages,
      },
    };
    
    if (isEditMode.value) {
      await DealActivitiesAPI.update(route.params.activityId, payload);
      useAlert(t('DEAL_ACTIVITIES_SETTINGS.ALERTS.UPDATE_SUCCESS'));
    } else {
      await DealActivitiesAPI.create(payload);
      useAlert(t('DEAL_ACTIVITIES_SETTINGS.ALERTS.CREATE_SUCCESS'));
    }
    
    goBack();
  } catch (error) {
    console.error('Error saving activity:', error);
    const message = isEditMode.value
      ? t('DEAL_ACTIVITIES_SETTINGS.ALERTS.UPDATE_FAILED')
      : t('DEAL_ACTIVITIES_SETTINGS.ALERTS.CREATE_FAILED');
    useAlert(message);
  } finally {
    saving.value = false;
  }
};

onMounted(async () => {
  await fetchPipelines();
  if (isEditMode.value) {
    await fetchActivity();
  }
});
</script>

<template>
  <div class="flex-1 overflow-auto">
    <BaseSettingsHeader
      :title="
        isEditMode
          ? $t('DEAL_ACTIVITIES_SETTINGS.EDIT_TITLE')
          : $t('DEAL_ACTIVITIES_SETTINGS.NEW_TITLE')
      "
      :description="$t('DEAL_ACTIVITIES_SETTINGS.FORM_DESCRIPTION')"
      feature-name="deal_activities"
    >
      <template #actions>
        <Button
          slate
          faded
          :label="$t('DEAL_ACTIVITIES_SETTINGS.CANCEL')"
          @click="goBack"
        />
        <Button
          :label="$t('DEAL_ACTIVITIES_SETTINGS.SAVE')"
          :is-loading="saving"
          :disabled="!isFormValid"
          @click="handleSubmit"
        />
      </template>
    </BaseSettingsHeader>

    <div v-if="loading" class="flex items-center justify-center py-12">
      <woot-spinner size="large" />
      <p class="ml-3 text-sm text-n-slate-11">
        {{ $t('DEAL_ACTIVITIES_SETTINGS.LOADING') }}
      </p>
    </div>

    <div v-else class="mt-6 px-8 pb-8 max-w-4xl">
      <!-- Pipeline e Stage -->
      <div class="grid grid-cols-2 gap-4 mb-4">
        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.PIPELINE') }}
            <span class="text-n-ruby-11">*</span>
          </label>
          <select
            v-model="selectedPipeline"
            class="w-full rounded-lg border border-n-alpha-2 bg-n-background px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          >
            <option
              v-for="pipeline in pipelines"
              :key="pipeline.id"
              :value="pipeline.id"
            >
              {{ pipeline.name }}
            </option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-n-slate-12 mb-2">
            {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.STAGE') }}
            <span class="text-n-ruby-11">*</span>
          </label>
          <select
            v-model="form.pipeline_stage_id"
            class="w-full rounded-lg border border-n-alpha-2 bg-n-background px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          >
            <option v-for="stage in stages" :key="stage.id" :value="stage.id">
              {{ stage.name }}
            </option>
          </select>
        </div>
      </div>

      <!-- Mover para etapa após enviar -->
      <div class="mb-6">
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.MOVE_TO_STAGE') }}
          <span class="text-xs font-normal text-n-slate-11 ml-1">
            {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.MOVE_TO_STAGE_OPTIONAL') }}
          </span>
        </label>
        <select
          v-model="form.move_to_stage_id"
          class="w-full rounded-lg border border-n-alpha-2 bg-n-background px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        >
          <option :value="null">
            {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.MOVE_TO_STAGE_NONE') }}
          </option>
          <option
            v-for="stage in availableStagesForMove"
            :key="stage.id"
            :value="stage.id"
          >
            {{ stage.name }}
          </option>
        </select>
        <p class="mt-1 text-xs text-n-slate-10">
          {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.MOVE_TO_STAGE_HELP') }}
        </p>
      </div>

      <!-- Título -->
      <div class="mb-6">
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.TITLE') }}
          <span class="text-n-ruby-11">*</span>
        </label>
        <input
          v-model="form.title"
          type="text"
          class="w-full rounded-lg border border-n-alpha-2 bg-n-background px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          :placeholder="$t('DEAL_ACTIVITIES_SETTINGS.FORM.TITLE_PLACEHOLDER')"
        />
      </div>

      <!-- Descrição -->
      <div class="mb-6">
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.DESCRIPTION') }}
        </label>
        <textarea
          v-model="form.description"
          rows="3"
          class="w-full rounded-lg border border-n-alpha-2 bg-n-background px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
          :placeholder="
            $t('DEAL_ACTIVITIES_SETTINGS.FORM.DESCRIPTION_PLACEHOLDER')
          "
        />
      </div>

      <!-- Mensagens Sequenciais -->
      <div class="mb-6">
        <div class="flex items-center justify-between mb-2">
          <label class="block text-sm font-medium text-n-slate-12">
            {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.MESSAGES') }}
            <span class="text-n-ruby-11">*</span>
          </label>
          <Button
            icon="i-lucide-plus"
            xs
            :label="$t('DEAL_ACTIVITIES_SETTINGS.FORM.ADD_MESSAGE')"
            @click="addMessage"
          />
        </div>

        <!-- Info sobre variáveis -->
        <div
          class="mb-4 rounded-lg bg-n-blue-2 border border-n-blue-6 p-3 text-xs"
        >
          <div class="flex items-start gap-2">
            <span class="i-lucide-info size-4 text-n-blue-11 flex-shrink-0" />
            <div class="flex-1">
              <p class="text-n-blue-12 font-medium mb-2">
                {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.VARIABLES_HELP') }}
              </p>
              <div class="flex flex-wrap gap-2 mb-2">
                <button
                  type="button"
                  class="inline-flex items-center gap-1 px-2 py-1 rounded-md bg-n-blue-3 hover:bg-n-blue-4 text-n-blue-12 font-mono text-xs transition-colors cursor-pointer"
                  @click="insertVariable('{{nomecompleto}}', currentMessageIndex)"
                >
                  <span class="i-lucide-user size-3" />
                  <span v-text="'{{nomecompleto}}'"></span>
                </button>
                <button
                  type="button"
                  class="inline-flex items-center gap-1 px-2 py-1 rounded-md bg-n-blue-3 hover:bg-n-blue-4 text-n-blue-12 font-mono text-xs transition-colors cursor-pointer"
                  @click="insertVariable('{{primeironome}}', currentMessageIndex)"
                >
                  <span class="i-lucide-user size-3" />
                  <span v-text="'{{primeironome}}'"></span>
                </button>
              </div>
              <p class="text-n-blue-11">
                {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.DELAY_INFO') }}
              </p>
            </div>
          </div>
        </div>

        <!-- Lista de mensagens -->
        <div class="space-y-3">
          <div
            v-for="(message, index) in form.messages"
            :key="index"
            class="rounded-lg border border-n-alpha-2 bg-n-solid-1 p-4"
          >
            <div class="flex items-start gap-3 mb-2">
              <span
                class="inline-flex items-center justify-center size-6 rounded-full bg-n-brand text-white text-xs font-medium flex-shrink-0"
              >
                {{ index + 1 }}
              </span>
              <div class="flex-1">
                <textarea
                  :ref="el => { if (el) messageTextareas[index] = el; }"
                  v-model="message.content"
                  rows="3"
                  class="w-full rounded-lg border border-n-alpha-2 bg-n-background px-3 py-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                  :placeholder="
                    $t('DEAL_ACTIVITIES_SETTINGS.FORM.MESSAGE_PLACEHOLDER', {
                      number: index + 1,
                    })
                  "
                  @focus="currentMessageIndex = index"
                />
              </div>
              <div class="flex flex-col gap-1 flex-shrink-0">
                <Button
                  v-tooltip.left="$t('DEAL_ACTIVITIES_SETTINGS.FORM.MOVE_UP')"
                  icon="i-lucide-chevron-up"
                  xs
                  slate
                  faded
                  :disabled="index === 0"
                  @click="moveMessageUp(index)"
                />
                <Button
                  v-tooltip.left="
                    $t('DEAL_ACTIVITIES_SETTINGS.FORM.MOVE_DOWN')
                  "
                  icon="i-lucide-chevron-down"
                  xs
                  slate
                  faded
                  :disabled="index === form.messages.length - 1"
                  @click="moveMessageDown(index)"
                />
                <Button
                  v-tooltip.left="
                    $t('DEAL_ACTIVITIES_SETTINGS.FORM.REMOVE_MESSAGE')
                  "
                  icon="i-lucide-trash-2"
                  xs
                  ruby
                  faded
                  :disabled="form.messages.length === 1"
                  @click="removeMessage(index)"
                />
              </div>
            </div>
            <div
              v-if="index < form.messages.length - 1"
              class="flex items-center gap-2 text-xs text-n-slate-11 mt-2"
            >
              <span class="i-lucide-timer size-3" />
              {{ $t('DEAL_ACTIVITIES_SETTINGS.FORM.DELAY_BETWEEN') }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

