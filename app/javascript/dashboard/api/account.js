/* global axios */
import ApiClient from './ApiClient';

class AccountAPI extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
  }

  createAccount(data) {
    return axios.post(`${this.apiVersion}/accounts`, data);
  }

  async getCacheKeys() {
    const response = await axios.get(
      `/api/v1/accounts/${this.accountIdFromRoute}/cache_keys`
    );
    return response.data.cache_keys;
  }

  updateLogo(accountId, logoFile) {
    const formData = new FormData();
    formData.append('logo', logoFile);
    return axios.patch(`${this.apiVersion}/accounts/${accountId}`, formData);
  }

  deleteLogo(accountId) {
    return axios.delete(`${this.apiVersion}/accounts/${accountId}/logo`);
  }
}

export default new AccountAPI();
