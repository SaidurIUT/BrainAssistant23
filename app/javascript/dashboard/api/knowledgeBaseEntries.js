/* global axios */

import ApiClient from './ApiClient';

class KnowledgeBaseEntriesAPI extends ApiClient {
  constructor() {
    super('knowledge_base_entries', { accountScoped: true });
  }

  getEntries() {
    return axios.get(this.url);
  }

  createEntry(data) {
    return axios.post(this.url, { knowledge_base_entry: data });
  }

  updateEntry(id, data) {
    return axios.patch(`${this.url}/${id}`, { knowledge_base_entry: data });
  }

  deleteEntry(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new KnowledgeBaseEntriesAPI();
