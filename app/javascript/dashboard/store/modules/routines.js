import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import RoutinesAPI from '../../api/routines';
import { throwErrorMessage } from '../utils/api';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getRoutines($state) {
    return $state.records;
  },
  getRoutine:
    $state =>
    id =>
      $state.records.find(record => record.id === Number(id)),
  getRoutinesUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  async get({ commit }, params = {}) {
    commit(types.SET_ROUTINES_UI_FLAG, { isFetching: true });
    try {
      const response = await RoutinesAPI.get(params);
      commit(types.SET_ROUTINES, response.data.payload || []);
    } catch (error) {
      // ignore
    } finally {
      commit(types.SET_ROUTINES_UI_FLAG, { isFetching: false });
    }
  },

  async create({ commit }, payload) {
    commit(types.SET_ROUTINES_UI_FLAG, { isCreating: true });
    try {
      const response = await RoutinesAPI.create({ routine: payload });
      commit(types.ADD_ROUTINE, response.data.payload);
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_ROUTINES_UI_FLAG, { isCreating: false });
    }
  },

  async update({ commit }, { id, ...payload }) {
    commit(types.SET_ROUTINES_UI_FLAG, { isUpdating: true });
    try {
      const response = await RoutinesAPI.update(id, { routine: payload });
      commit(types.EDIT_ROUTINE, response.data.payload);
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_ROUTINES_UI_FLAG, { isUpdating: false });
    }
  },

  async delete({ commit }, id) {
    commit(types.SET_ROUTINES_UI_FLAG, { isDeleting: true });
    try {
      await RoutinesAPI.delete(id);
      commit(types.DELETE_ROUTINE, id);
    } catch (error) {
      throwErrorMessage(error);
      throw error;
    } finally {
      commit(types.SET_ROUTINES_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_ROUTINES_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.SET_ROUTINES]: MutationHelpers.set,
  [types.ADD_ROUTINE]: MutationHelpers.setSingleRecord,
  [types.EDIT_ROUTINE]: MutationHelpers.update,
  [types.DELETE_ROUTINE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};


