import ApiClient from './ApiClient';

class PipelineWebhooksAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
  }

  getAll(pipelineId) {
    return axios.get(`${this.url}/${pipelineId}/webhooks`);
  }

  show(pipelineId, webhookId) {
    return axios.get(`${this.url}/${pipelineId}/webhooks/${webhookId}`);
  }

  create(pipelineId, webhookData) {
    return axios.post(`${this.url}/${pipelineId}/webhooks`, {
      webhook: webhookData,
    });
  }

  update(pipelineId, webhookId, webhookData) {
    return axios.patch(`${this.url}/${pipelineId}/webhooks/${webhookId}`, {
      webhook: webhookData,
    });
  }

  delete(pipelineId, webhookId) {
    return axios.delete(`${this.url}/${pipelineId}/webhooks/${webhookId}`);
  }
}

export default new PipelineWebhooksAPI();

