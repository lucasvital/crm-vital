<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, numeric } from '@vuelidate/validators';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PipelinesAPI from 'dashboard/api/pipelines';

export default {
  components: { NextButton },
  props: {
    show: { type: Boolean, default: false },
    currentChat: { type: Object, default: () => ({}) },
    initialValues: { type: Object, default: () => ({}) },
    titleKey: { type: String, default: 'KANBAN.FORM.TITLE' },
    descKey: { type: String, default: 'KANBAN.FORM.DESC' },
    submitKey: { type: String, default: 'KANBAN.FORM.SUBMIT' },
  },
  emits: ['cancel', 'update:show', 'submit'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      title: '',
      amount: '',
      currency: 'BRL',
      closeDate: '',
      notes: '',
      isSubmitting: false,
      pipelines: [],
      selectedPipelineId: null,
      stageOptions: [], // [{id, name, key, position}]
      selectedStageId: null,
    };
  },
  watch: {
    initialValues: {
      handler(val) {
        if (!val) return;
        this.title = val.title || '';
        this.amount = val.amount != null ? String(val.amount) : '';
        this.currency = val.currency || 'BRL';
        this.closeDate = val.closeDate || '';
        this.notes = val.notes || '';
      },
      deep: true,
      immediate: true,
    },
  },
  validations() {
    return {
      title: { required, minLength: minLength(2) },
      amount: { required, numeric },
      currency: { required },
      selectedPipelineId: { required },
      selectedStageId: { required },
    };
  },
  computed: {
    localShow: {
      get() {
        return this.show;
      },
      set(value) {
        this.$emit('update:show', value);
      },
    },
    isFormValid() {
      const validTitle = !!this.title && !this.v$.title.$error;
      const validAmount = !!this.amount && !this.v$.amount.$error;
      const validCurrency = !!this.currency && !this.v$.currency.$error;
      const validPipeline = !!this.selectedPipelineId && !this.v$.selectedPipelineId.$error;
      const validStage = !!this.selectedStageId && !this.v$.selectedStageId.$error;
      return validTitle && validAmount && validCurrency && validPipeline && validStage;
    },
    currencyOptions() {
      return ['BRL', 'USD', 'EUR'];
    },
  },
  methods: {
    async loadPipelines() {
      const { data } = await PipelinesAPI.get();
      this.pipelines = data || [];
      if (this.pipelines.length) {
        this.selectedPipelineId = this.pipelines[0].id;
        this.stageOptions = (this.pipelines[0].pipeline_stages || []).slice().sort((a, b) => a.position - b.position);
        this.selectedStageId = this.stageOptions[0]?.id || null;
      }
    },
    onChangePipeline() {
      const found = this.pipelines.find(p => p.id === Number(this.selectedPipelineId));
      this.stageOptions = (found?.pipeline_stages || []).slice().sort((a, b) => a.position - b.position);
      this.selectedStageId = this.stageOptions[0]?.id || null;
      this.v$.selectedStageId.$touch();
    },
    onCancel() {
      this.$emit('cancel');
    },
    async onSubmit() {
      if (!this.isFormValid) return;
      this.isSubmitting = true;
      try {
        const stage = this.stageOptions.find(s => s.id === Number(this.selectedStageId));
        this.$emit('submit', {
          title: this.title,
          amount: Number(this.amount),
          currency: this.currency,
          closeDate: this.closeDate || null,
          notes: this.notes || null,
          pipelineId: Number(this.selectedPipelineId) || null,
          stageId: Number(this.selectedStageId) || null,
          stageKey: stage?.key || 'new',
        });
        this.onCancel();
      } finally {
        this.isSubmitting = false;
      }
    },
  },
  mounted() {
    this.loadPipelines();
  },
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onCancel">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t(titleKey)"
        :header-content="$t(descKey)"
      />
      <form class="w-full" @submit.prevent="onSubmit">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label :class="{ error: v$.selectedPipelineId.$error }">
              <span class="block text-sm mb-1">Pipeline</span>
              <select v-model="selectedPipelineId" @change="onChangePipeline">
                <option v-for="p in pipelines" :key="p.id" :value="p.id">
                  {{ p.name }}
                </option>
              </select>
            </label>
          </div>
          <div>
            <label :class="{ error: v$.selectedStageId.$error }">
              <span class="block text-sm mb-1">Etapa inicial</span>
              <select v-model="selectedStageId">
                <option v-for="s in stageOptions" :key="s.id" :value="s.id">
                  {{ s.name }}
                </option>
              </select>
            </label>
          </div>
          <div class="col-span-2">
            <label :class="{ error: v$.title.$error }">
              <span class="block text-sm mb-1">{{ $t('KANBAN.FORM.FIELDS.TITLE') }}</span>
              <input
                v-model="title"
                type="text"
                :placeholder="$t('KANBAN.FORM.PLACEHOLDERS.TITLE')"
                @input="v$.title.$touch"
              />
            </label>
          </div>
          <div>
            <label :class="{ error: v$.amount.$error }">
              <span class="block text-sm mb-1">{{ $t('KANBAN.FORM.FIELDS.AMOUNT') }}</span>
              <input
                v-model="amount"
                type="number"
                step="0.01"
                min="0"
                :placeholder="$t('KANBAN.FORM.PLACEHOLDERS.AMOUNT')"
                @input="v$.amount.$touch"
              />
            </label>
          </div>
          <div>
            <label :class="{ error: v$.currency.$error }">
              <span class="block text-sm mb-1">{{ $t('KANBAN.FORM.FIELDS.CURRENCY') }}</span>
              <select v-model="currency" @change="v$.currency.$touch">
                <option v-for="c in currencyOptions" :key="c" :value="c">{{ c }}</option>
              </select>
            </label>
          </div>
          <div>
            <label>
              <span class="block text-sm mb-1">{{ $t('KANBAN.FORM.FIELDS.CLOSE_DATE') }}</span>
              <input
                v-model="closeDate"
                type="date"
                :placeholder="$t('KANBAN.FORM.PLACEHOLDERS.CLOSE_DATE')"
              />
            </label>
          </div>
          <div class="col-span-2">
            <label>
              <span class="block text-sm mb-1">{{ $t('KANBAN.FORM.FIELDS.NOTES') }}</span>
              <textarea
                v-model="notes"
                rows="3"
                :placeholder="$t('KANBAN.FORM.PLACEHOLDERS.NOTES')"
              />
            </label>
          </div>
        </div>
        <div class="flex flex-row justify-end w-full gap-2 px-0 py-4">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('KANBAN.FORM.CANCEL')"
            @click.prevent="onCancel"
          />
          <NextButton
            type="submit"
            :label="$t(submitKey)"
            :disabled="!isFormValid || isSubmitting"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>

<style scoped>
.error input,
.error select,
.error textarea {
  border-color: var(--color-error, #f87171);
}
</style>