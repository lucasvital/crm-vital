import { frontendURL } from 'dashboard/helper/URLHelper';
import { RouterView } from 'vue-router';

const EnablementIndex = () =>
  import('./pages/EnablementIndex.vue');
const NewCallAnalysis = () =>
  import('./pages/NewCallAnalysis.vue');
const CallAnalysisDetail = () =>
  import('./pages/CallAnalysisDetail.vue');
const SellerPdiView = () =>
  import('./pages/SellerPdiView.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/enablement'),
      component: RouterView,
      children: [
        {
          path: '',
          name: 'enablement_index',
          component: EnablementIndex,
          meta: {
            permissions: ['administrator', 'agent'],
          },
        },
        {
          path: 'new',
          name: 'enablement_new_analysis',
          component: NewCallAnalysis,
          meta: {
            permissions: ['administrator', 'agent'],
          },
        },
        {
          path: 'analysis/:id',
          name: 'enablement_analysis_detail',
          component: CallAnalysisDetail,
          meta: {
            permissions: ['administrator', 'agent'],
          },
        },
        {
          path: 'pdi',
          name: 'enablement_my_pdi',
          component: SellerPdiView,
          meta: {
            permissions: ['administrator', 'agent'],
          },
        },
        {
          path: 'pdi/:user_id',
          name: 'enablement_user_pdi',
          component: SellerPdiView,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};

