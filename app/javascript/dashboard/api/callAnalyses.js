import ApiClient from './ApiClient';

class CallAnalysesAPI extends ApiClient {
  constructor() {
    super('call_analyses', { accountScoped: true });
  }

  list({ contactId, userId, dealId } = {}) {
    return axios.get(this.url, {
      params: {
        contact_id: contactId,
        user_id: userId,
        deal_id: dealId,
      },
    });
  }

  create(payload) {
    return axios.post(this.url, {
      call_analysis: payload,
    });
  }

  get(id) {
    return axios.get(`${this.url}/${id}`);
  }

  update(id, payload) {
    return axios.patch(`${this.url}/${id}`, {
      call_analysis: payload,
    });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new CallAnalysesAPI();

