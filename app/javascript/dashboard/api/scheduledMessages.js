/* global axios */
import ApiClient from './ApiClient';

class ScheduledMessagesAPI extends ApiClient {
  constructor() {
    super('scheduled_messages', { accountScoped: true });
  }

  list(conversationId) {
    return axios.get(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages`
    );
  }

  show(conversationId, id) {
    return axios.get(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages/${id}`
    );
  }

  create(conversationId, data) {
    return axios.post(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages`,
      { scheduled_message: data }
    );
  }

  cancel(conversationId, id) {
    return axios.patch(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages/${id}`,
      { status: 'cancelled' }
    );
  }

  delete(conversationId, id) {
    return axios.delete(
      `${this.baseUrl()}/conversations/${conversationId}/scheduled_messages/${id}`
    );
  }
}

export default new ScheduledMessagesAPI();
