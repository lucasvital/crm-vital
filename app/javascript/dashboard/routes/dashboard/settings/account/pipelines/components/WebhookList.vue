<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PipelineWebhooksAPI from 'dashboard/api/pipelineWebhooks';
import WebhookWizard from './WebhookWizard.vue';

const props = defineProps({
  pipeline: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const alert = useAlert;

const webhooks = ref([]);
const isLoading = ref(false);
const showWizard = ref(false);
const editingWebhook = ref(null);

const loadWebhooks = async () => {
  isLoading.value = true;
  try {
    const { data } = await PipelineWebhooksAPI.getAll(props.pipeline.id);
    webhooks.value = data || [];
  } catch (error) {
    alert('Erro ao carregar webhooks');
  } finally {
    isLoading.value = false;
  }
};

const openCreateWizard = () => {
  editingWebhook.value = null;
  showWizard.value = true;
};

const openEditWizard = webhook => {
  editingWebhook.value = webhook;
  showWizard.value = true;
};

const closeWizard = () => {
  showWizard.value = false;
  editingWebhook.value = null;
};

const handleWebhookSaved = () => {
  loadWebhooks();
};

const toggleActive = async webhook => {
  try {
    await PipelineWebhooksAPI.update(props.pipeline.id, webhook.id, {
      active: !webhook.active,
    });
    await loadWebhooks();
    alert('Status atualizado com sucesso');
  } catch (error) {
    alert('Erro ao atualizar status');
  }
};

const deleteWebhook = async webhook => {
  if (!confirm(`Tem certeza que deseja excluir "${webhook.name}"?`)) {
    return;
  }

  try {
    await PipelineWebhooksAPI.delete(props.pipeline.id, webhook.id);
    await loadWebhooks();
    alert('Webhook excluído com sucesso');
  } catch (error) {
    alert('Erro ao excluir webhook');
  }
};

const copyToClipboard = text => {
  navigator.clipboard.writeText(text).then(() => {
    alert('URL copiada para a área de transferência!');
  });
};

onMounted(() => {
  loadWebhooks();
});
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h3 class="text-lg font-semibold text-n-slate-12">
        Webhooks de Entrada
      </h3>
      <button
        type="button"
        class="rounded-md border border-n-strong bg-n-brand px-4 py-2 text-sm font-medium text-white hover:brightness-110"
        @click="openCreateWizard"
      >
        + Nova Integração
      </button>
    </div>

    <div v-if="isLoading" class="text-center py-8 text-n-slate-11">
      Carregando...
    </div>

    <div
      v-else-if="webhooks.length === 0"
      class="text-center py-8 text-n-slate-11"
    >
      <p class="mb-2">Nenhuma integração configurada</p>
      <p class="text-xs">
        Clique em "Nova Integração" para criar um webhook e receber leads
      </p>
    </div>

    <div v-else class="space-y-3">
      <div
        v-for="webhook in webhooks"
        :key="webhook.id"
        class="rounded-lg border border-n-alpha-2 bg-n-solid-2 p-4 hover:bg-n-solid-3 transition-colors"
      >
        <div class="flex items-start gap-3">
          <div
            class="flex-shrink-0 flex items-center justify-center w-10 h-10 rounded-md bg-n-solid-1 border border-n-alpha-2"
          >
            <span class="i-lucide-webhook size-5 text-n-blue-11" />
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex items-start justify-between gap-2 mb-2">
              <div class="flex items-center gap-2 flex-wrap">
                <h4 class="text-sm font-semibold text-n-slate-12">
                  {{ webhook.name }}
                </h4>
                <span
                  class="inline-flex items-center gap-1 rounded-md px-2 py-0.5 text-2xs font-medium whitespace-nowrap"
                  :class="
                    webhook.active
                      ? 'bg-n-grass-3 text-n-grass-11 border border-n-grass-8'
                      : 'bg-n-solid-3 text-n-slate-11 border border-n-alpha-2'
                  "
                >
                  <span
                    class="w-1.5 h-1.5 rounded-full"
                    :class="webhook.active ? 'bg-n-grass-9' : 'bg-n-slate-9'"
                  />
                  {{ webhook.active ? 'Ativo' : 'Inativo' }}
                </span>
              </div>

              <div class="flex items-center gap-1 flex-shrink-0">
                <button
                  type="button"
                  class="rounded-md border border-n-strong bg-n-solid-1 p-1.5 text-n-slate-12 hover:bg-n-solid-2"
                  :title="webhook.active ? 'Desativar' : 'Ativar'"
                  @click="toggleActive(webhook)"
                >
                  <span
                    class="size-4"
                    :class="
                      webhook.active ? 'i-lucide-toggle-right' : 'i-lucide-toggle-left'
                    "
                  />
                </button>

                <button
                  type="button"
                  class="rounded-md border border-n-strong bg-n-solid-1 p-1.5 text-n-blue-11 hover:bg-n-blue-3"
                  title="Editar"
                  @click="openEditWizard(webhook)"
                >
                  <span class="i-lucide-pencil size-4" />
                </button>

                <button
                  type="button"
                  class="rounded-md border border-n-strong bg-n-solid-1 p-1.5 text-n-ruby-11 hover:bg-n-ruby-3"
                  title="Excluir"
                  @click="deleteWebhook(webhook)"
                >
                  <span class="i-lucide-trash-2 size-4" />
                </button>
              </div>
            </div>

            <div class="space-y-2 text-xs text-n-slate-11">
              <div class="flex items-center gap-1">
                <span class="i-lucide-git-branch size-3 flex-shrink-0" />
                <span
                  >Etapa: <strong>{{ webhook.pipeline_stage?.name }}</strong></span
                >
              </div>

              <div
                v-if="
                  webhook.tag_config?.labels &&
                    webhook.tag_config.labels.length > 0
                "
                class="flex items-start gap-1"
              >
                <span class="i-lucide-tag size-3 flex-shrink-0 mt-0.5" />
                <div class="flex items-center gap-1 flex-wrap">
                  <span>Tags:</span>
                  <span
                    v-for="tag in webhook.tag_config.labels"
                    :key="tag"
                    class="inline-flex items-center rounded-md bg-n-solid-1 border border-n-alpha-2 px-1.5 py-0.5 text-2xs"
                  >
                    {{ tag }}
                  </span>
                </div>
              </div>

              <div class="flex items-start gap-2">
                <span class="i-lucide-link size-3 flex-shrink-0 mt-1" />
                <div class="flex-1 min-w-0">
                  <code
                    class="block text-2xs bg-n-solid-1 border border-n-alpha-2 rounded px-2 py-1 break-all"
                  >
                    {{ webhook.full_webhook_url }}
                  </code>
                </div>
                <button
                  type="button"
                  class="flex-shrink-0 rounded-md border border-n-strong bg-n-solid-1 px-2 py-1 text-2xs font-medium text-n-blue-11 hover:bg-n-blue-3 whitespace-nowrap"
                  @click="copyToClipboard(webhook.full_webhook_url)"
                >
                  Copiar
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal do Wizard -->
    <woot-modal v-model:show="showWizard" :on-close="closeWizard">
      <WebhookWizard
        v-if="showWizard"
        :pipeline="pipeline"
        :webhook="editingWebhook"
        @close="closeWizard"
        @saved="handleWebhookSaved"
      />
    </woot-modal>
  </div>
</template>

