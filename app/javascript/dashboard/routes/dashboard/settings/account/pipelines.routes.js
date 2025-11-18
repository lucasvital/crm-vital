import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import PipelinesIndex from './pipelines/Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/pipelines'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'settings_pipelines_index',
          component: PipelinesIndex,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};


