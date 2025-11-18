import ApiClient from './ApiClient';

class PipelinesAPI extends ApiClient {
  constructor() {
    super('pipelines', { accountScoped: true });
  }

  getStages(pipelineId) {
    return axios.get(`${this.url}/${pipelineId}/stages`);
  }

  createStage(pipelineId, payload) {
    return axios.post(`${this.url}/${pipelineId}/stages`, {
      stage: payload,
    });
  }

  updateStage(pipelineId, stageId, payload) {
    return axios.put(`${this.url}/${pipelineId}/stages/${stageId}`, {
      stage: payload,
    });
  }

  deleteStage(pipelineId, stageId) {
    return axios.delete(`${this.url}/${pipelineId}/stages/${stageId}`);
  }

  reorderStages(pipelineId, order) {
    return axios.put(`${this.url}/${pipelineId}/stages/reorder`, {
      order,
    });
  }
}

export default new PipelinesAPI();


