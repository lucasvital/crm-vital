/* global axios */
import ApiClient from './ApiClient';

class RoutinesAPI extends ApiClient {
  constructor() {
    super('routines', { accountScoped: true });
  }

  getAgentRoutines(params = {}) {
    const baseUrl = this.baseUrl();
    return axios.get(`${baseUrl}/agent_routines`, { params });
  }

  markComplete(routineId) {
    const baseUrl = this.baseUrl();
    return axios.post(`${baseUrl}/routine_completions`, { routine_id: routineId });
  }

  unmarkComplete(routineId) {
    const baseUrl = this.baseUrl();
    return axios.delete(`${baseUrl}/routine_completions/${routineId}`);
  }
}

export default new RoutinesAPI();


