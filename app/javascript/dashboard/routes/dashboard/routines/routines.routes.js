import { frontendURL } from 'dashboard/helper/URLHelper';
import RoutinesView from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/routines'),
      name: 'routines_view',
      component: RoutinesView,
      meta: {
        permissions: ['administrator', 'agent'],
      },
    },
  ],
};

