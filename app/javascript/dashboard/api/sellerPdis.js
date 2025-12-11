import ApiClient from './ApiClient';

class SellerPdisAPI extends ApiClient {
  constructor() {
    super('seller_pdis', { accountScoped: true });
  }

  get(userId = null) {
    const url = userId ? `${this.url}/${userId}` : this.url;
    return axios.get(url);
  }
}

export default new SellerPdisAPI();

