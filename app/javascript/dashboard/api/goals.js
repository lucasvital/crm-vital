import ApiClient from './ApiClient';

class GoalsAPI extends ApiClient {
  constructor() {
    super('goals', { accountScoped: true });
  }

  progress(id) {
    return axios.get(`${this.url}/${id}/progress`);
  }
}

export default new GoalsAPI();



