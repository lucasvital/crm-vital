import ApiClient from './ApiClient';

class DealsAPI extends ApiClient {
  constructor() {
    super('deals', { accountScoped: true });
  }

  list({ pipelineId, contactId } = {}) {
    return axios.get(this.url, {
      params: {
        pipeline_id: pipelineId,
        contact_id: contactId,
      },
    });
  }
}

export default new DealsAPI();


