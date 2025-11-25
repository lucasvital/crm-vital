import { frontendURL } from 'dashboard/helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import RoutinesIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/routines'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'routines_list',
          component: RoutinesIndex,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};


