<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import callAnalysesAPI from 'dashboard/api/callAnalyses';
import ContactsAPI from 'dashboard/api/contacts';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const router = useRouter();
const { t } = useI18n();
const store = useStore();

const transcript = ref('');
const selectedContactId = ref(null);
const selectedUserId = ref(null);
const selectedDealId = ref(null);
const loading = ref(false);
const analyzing = ref(false);
const contacts = ref([]);
const users = ref([]);

const currentUser = computed(() => window.chatwootConfig?.user);
const isAdmin = computed(() => currentUser.value?.role === 'administrator');

// Contador de caracteres
const transcriptLength = computed(() => transcript.value.length);
const isLongTranscript = computed(() => transcriptLength.value > 20000);

const fetchContacts = async () => {
  try {
    const response = await ContactsAPI.get(1, 'name', '');
    contacts.value = response.data.payload || [];
  } catch (error) {
    console.error('Error fetching contacts:', error);
  }
};

const fetchUsers = async () => {
  if (!isAdmin.value) return;
  try {
    await store.dispatch('agents/get');
    users.value = store.getters['agents/getAgents'] || [];
  } catch (error) {
    console.error('Error fetching users:', error);
  }
};

const handleSubmit = async () => {
  if (!transcript.value.trim()) {
    useAlert(t('ENABLEMENT.VALIDATION.TRANSCRIPT_REQUIRED'));
    return;
  }

  if (!selectedContactId.value) {
    useAlert(t('ENABLEMENT.VALIDATION.CONTACT_REQUIRED'));
    return;
  }

  analyzing.value = true;
  try {
    const payload = {
      transcript: transcript.value,
      contact_id: selectedContactId.value,
      deal_id: selectedDealId.value || null,
    };

    if (isAdmin.value && selectedUserId.value) {
      payload.user_id = selectedUserId.value;
    }

    const response = await callAnalysesAPI.create(payload);

    // Se é processamento assíncrono (202 Accepted), mostra mensagem diferente
    if (response.status === 202 || response.data.processing_status === 'pending') {
      useAlert(t('ENABLEMENT.SUCCESS.ANALYSIS_QUEUED'));
    } else {
      useAlert(t('ENABLEMENT.SUCCESS.ANALYSIS_CREATED'));
    }

    router.push({
      name: 'enablement_analysis_detail',
      params: { id: response.data.id },
    });
  } catch (error) {
    const message = error?.response?.data?.error || 
                    error?.response?.data?.errors?.join(', ') ||
                    t('ENABLEMENT.ERROR.ANALYSIS_FAILED');
    useAlert(message);
  } finally {
    analyzing.value = false;
  }
};

const goBack = () => {
  router.push({ name: 'enablement_index' });
};

onMounted(() => {
  fetchContacts();
  if (isAdmin.value) {
    fetchUsers();
  }
});
</script>

<template>
  <div class="flex flex-col flex-1 h-full overflow-auto bg-n-background">
    <!-- Header -->
    <div class="flex items-center gap-4 px-8 py-6 border-b border-n-slate-4">
      <button
        class="p-2 rounded-md hover:bg-n-slate-3 text-n-slate-11 hover:text-n-slate-12"
        @click="goBack"
      >
        <fluent-icon icon="chevron-left-outline" size="20" />
      </button>
      <div>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          {{ t('ENABLEMENT.NEW_ANALYSIS.TITLE') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ t('ENABLEMENT.NEW_ANALYSIS.DESCRIPTION') }}
        </p>
      </div>
    </div>

    <!-- Form -->
    <div class="flex-1 p-8 overflow-y-auto">
      <div class="space-y-6">
        <!-- Transcript -->
        <div>
          <div class="flex items-center justify-between mb-2">
            <label class="text-sm font-medium text-n-slate-12">
              {{ t('ENABLEMENT.FORM.TRANSCRIPT_LABEL') }}
              <span class="text-red-500">*</span>
            </label>
            <span 
              :class="[
                'text-xs',
                isLongTranscript ? 'text-n-amber-11' : 'text-n-slate-10'
              ]"
            >
              {{ transcriptLength.toLocaleString() }} {{ t('ENABLEMENT.FORM.CHARACTERS') }}
              <span v-if="isLongTranscript" class="ml-1">
                ({{ t('ENABLEMENT.FORM.ASYNC_PROCESSING') }})
              </span>
            </span>
          </div>
          <textarea
            v-model="transcript"
            :placeholder="t('ENABLEMENT.FORM.TRANSCRIPT_PLACEHOLDER')"
            class="w-full h-64 px-4 py-3 text-sm border rounded-md bg-n-background border-n-slate-4 text-n-slate-12 placeholder-n-slate-9 focus:ring-2 focus:ring-woot-500 focus:border-transparent"
            :disabled="analyzing"
          />
        </div>

        <!-- Contact -->
        <div>
          <label class="block mb-2 text-sm font-medium text-n-slate-12">
            {{ t('ENABLEMENT.FORM.CONTACT_LABEL') }}
            <span class="text-red-500">*</span>
          </label>
          <select
            v-model="selectedContactId"
            class="w-full px-4 py-3 text-sm border rounded-md bg-n-background border-n-slate-4 text-n-slate-12 focus:ring-2 focus:ring-woot-500 focus:border-transparent"
            :disabled="analyzing"
          >
            <option :value="null">{{ t('ENABLEMENT.FORM.SELECT_CONTACT') }}</option>
            <option
              v-for="contact in contacts"
              :key="contact.id"
              :value="contact.id"
            >
              {{ contact.name }} {{ contact.email ? `(${contact.email})` : '' }}
            </option>
          </select>
        </div>

        <!-- User (Admin only) -->
        <div v-if="isAdmin">
          <label class="block mb-2 text-sm font-medium text-n-slate-12">
            {{ t('ENABLEMENT.FORM.SELLER_LABEL') }}
          </label>
          <select
            v-model="selectedUserId"
            class="w-full px-4 py-3 text-sm border rounded-md bg-n-background border-n-slate-4 text-n-slate-12 focus:ring-2 focus:ring-woot-500 focus:border-transparent"
            :disabled="analyzing"
          >
            <option :value="null">{{ t('ENABLEMENT.FORM.SELECT_SELLER_SELF') }}</option>
            <option
              v-for="user in users"
              :key="user.id"
              :value="user.id"
            >
              {{ user.name }}
            </option>
          </select>
          <p class="mt-1 text-xs text-n-slate-10">
            {{ t('ENABLEMENT.FORM.SELLER_HELP') }}
          </p>
        </div>

        <!-- Actions -->
        <div class="flex items-center justify-end gap-3 pt-4">
          <button
            class="px-6 py-3 text-sm font-medium rounded-md text-n-slate-12 bg-n-slate-3 hover:bg-n-slate-4"
            :disabled="analyzing"
            @click="goBack"
          >
            {{ t('ENABLEMENT.ACTIONS.CANCEL') }}
          </button>
          <button
            class="flex items-center gap-2 px-6 py-3 text-sm font-medium text-white rounded-md bg-n-brand hover:brightness-110 disabled:opacity-50 disabled:cursor-not-allowed"
            :disabled="analyzing"
            @click="handleSubmit"
          >
            <Spinner v-if="analyzing" size="small" />
            <span>{{ analyzing ? t('ENABLEMENT.ACTIONS.ANALYZING') : t('ENABLEMENT.ACTIONS.ANALYZE') }}</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
