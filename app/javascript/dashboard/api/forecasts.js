/* global axios */
import ApiClient from './ApiClient';

class ForecastsAPI extends ApiClient {
  constructor() {
    super('forecasts', { accountScoped: true });
  }

  history() {
    return axios.get(`${this.url}/history`);
  }

  latest() {
    return axios.get(`${this.url}/latest`);
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }

  generate() {
    return axios.post(`${this.url}/generate`);
  }

  metrics() {
    return axios.get(`${this.url}/metrics`);
  }
}

export default new ForecastsAPI();
