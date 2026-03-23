import KnowledgeBaseEntriesAPI from '../../api/knowledgeBaseEntries';
import AccountAPI from '../../api/account';

export const state = {
  entries: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
    isSavingAccountKB: false,
  },
};

export const getters = {
  getEntries(_state) {
    return _state.entries;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  fetchEntries: async function fetchEntries({ commit }) {
    commit('SET_KB_UI_FLAG', { isFetching: true });
    try {
      const response = await KnowledgeBaseEntriesAPI.getEntries();
      commit('SET_ENTRIES', response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit('SET_KB_UI_FLAG', { isFetching: false });
    }
  },

  createEntry: async function createEntry({ commit }, data) {
    commit('SET_KB_UI_FLAG', { isCreating: true });
    try {
      const response = await KnowledgeBaseEntriesAPI.createEntry(data);
      commit('ADD_ENTRY', response.data);
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit('SET_KB_UI_FLAG', { isCreating: false });
    }
  },

  updateEntry: async function updateEntry({ commit }, { id, ...updateObj }) {
    commit('SET_KB_UI_FLAG', { isUpdating: true });
    try {
      const response = await KnowledgeBaseEntriesAPI.updateEntry(id, updateObj);
      commit('EDIT_ENTRY', response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit('SET_KB_UI_FLAG', { isUpdating: false });
    }
  },

  deleteEntry: async function deleteEntry({ commit }, id) {
    commit('SET_KB_UI_FLAG', { isDeleting: true });
    try {
      await KnowledgeBaseEntriesAPI.deleteEntry(id);
      commit('DELETE_ENTRY', id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit('SET_KB_UI_FLAG', { isDeleting: false });
    }
  },

  saveAccountKnowledgeBase: async function saveAccountKnowledgeBase(
    { commit },
    { accountId, websiteUrl, scrapedData }
  ) {
    commit('SET_KB_UI_FLAG', { isSavingAccountKB: true });
    try {
      await AccountAPI.update(accountId, {
        website_url: websiteUrl,
        scraped_data: scrapedData,
      });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit('SET_KB_UI_FLAG', { isSavingAccountKB: false });
    }
  },
};

export const mutations = {
  SET_KB_UI_FLAG(_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  SET_ENTRIES(_state, data) {
    _state.entries = data;
  },

  ADD_ENTRY(_state, data) {
    _state.entries = [..._state.entries, data];
  },

  EDIT_ENTRY(_state, data) {
    const index = _state.entries.findIndex(e => e.id === data.id);
    if (index !== -1) {
      _state.entries = [
        ..._state.entries.slice(0, index),
        data,
        ..._state.entries.slice(index + 1),
      ];
    }
  },

  DELETE_ENTRY(_state, id) {
    _state.entries = _state.entries.filter(e => e.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
