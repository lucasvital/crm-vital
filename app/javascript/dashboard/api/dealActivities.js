/* global axios */
import ApiClient from './ApiClient';

class DealActivitiesAPI extends ApiClient {
  constructor() {
    super('deal_activities', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }

  create(data) {
    return axios.post(this.url, data);
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  reorder(positions) {
    return axios.put(`${this.url}/reorder`, { positions });
  }
}

export default new DealActivitiesAPI();

