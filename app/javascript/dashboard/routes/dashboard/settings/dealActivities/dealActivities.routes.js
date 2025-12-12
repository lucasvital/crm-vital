import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';

const Index = () => import('./Index.vue');
const ActivityForm = () => import('./ActivityForm.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/deal-activities'),
      component: SettingsWrapper,
      meta: {
        permissions: ['administrator'],
      },
      children: [
        {
          path: '',
          name: 'deal_activities_index',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: 'new',
          name: 'deal_activities_new',
          component: ActivityForm,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: ':activityId/edit',
          name: 'deal_activities_edit',
          component: ActivityForm,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};

