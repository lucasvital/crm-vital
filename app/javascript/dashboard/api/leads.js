/* global axios */
import ApiClient from './ApiClient';

class LeadsAPI extends ApiClient {
  constructor() {
    super('leads', { accountScoped: true });
  }

  create(leadData) {
    return axios.post(`${this.url}`, { lead: leadData });
  }

  importUpload(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(`${this.url}/import/upload`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  importProcess(importData) {
    return axios.post(`${this.url}/import/process`, importData);
  }
}

export default new LeadsAPI();

