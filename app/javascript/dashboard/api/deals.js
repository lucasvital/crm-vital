import ApiClient from './ApiClient';

class DealsAPI extends ApiClient {
  constructor() {
    super('deals', { accountScoped: true });
  }

  list({ pipelineId, contactId, createdAtFrom, createdAtTo } = {}) {
    return axios.get(this.url, {
      params: {
        pipeline_id: pipelineId,
        contact_id: contactId,
        created_at_from: createdAtFrom || undefined,
        created_at_to: createdAtTo || undefined,
      },
    });
  }

  update(dealId, payload) {
    return axios.patch(`${this.url}/${dealId}`, payload);
  }
}

export default new DealsAPI();


