<!-- eslint-disable vue/v-slot-style -->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAgentsList } from 'dashboard/composables/useAgentsList';
import ContactDetailsItem from './ContactDetailsItem.vue';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';
import ConversationLabels from './labels/LabelBox.vue';
import { CONVERSATION_PRIORITY } from '../../../../shared/constants/messages';
import { CONVERSATION_EVENTS } from '../../../helper/AnalyticsHelper/events';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ConversationApi from 'dashboard/api/inbox/conversation';
import ContactAPI from 'dashboard/api/contacts';
import ConversationsApi from 'dashboard/api/conversations';
import CreateDealModal from 'dashboard/components/widgets/conversation/CreateDealModal.vue';

export default {
  components: {
    ContactDetailsItem,
    MultiselectDropdown,
    ConversationLabels,
    NextButton,
    CreateDealModal,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  setup() {
    const { agentsList } = useAgentsList();
    return {
      agentsList,
    };
  },
  data() {
    return {
      priorityOptions: [
        {
          id: null,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.NONE'),
          thumbnail: `/assets/images/dashboard/priority/none.svg`,
        },
        {
          id: CONVERSATION_PRIORITY.URGENT,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.URGENT'),
          thumbnail: `/assets/images/dashboard/priority/${CONVERSATION_PRIORITY.URGENT}.svg`,
        },
        {
          id: CONVERSATION_PRIORITY.HIGH,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.HIGH'),
          thumbnail: `/assets/images/dashboard/priority/${CONVERSATION_PRIORITY.HIGH}.svg`,
        },
        {
          id: CONVERSATION_PRIORITY.MEDIUM,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.MEDIUM'),
          thumbnail: `/assets/images/dashboard/priority/${CONVERSATION_PRIORITY.MEDIUM}.svg`,
        },
        {
          id: CONVERSATION_PRIORITY.LOW,
          name: this.$t('CONVERSATION.PRIORITY.OPTIONS.LOW'),
          thumbnail: `/assets/images/dashboard/priority/${CONVERSATION_PRIORITY.LOW}.svg`,
        },
      ],
      stageOptions: [
        { id: 'new', name: this.$t('KANBAN.COLUMNS.NEW') },
        { id: 'qualified', name: this.$t('KANBAN.COLUMNS.QUALIFIED') },
        { id: 'proposal', name: this.$t('KANBAN.COLUMNS.PROPOSAL') },
        { id: 'won', name: this.$t('KANBAN.COLUMNS.WON') },
        { id: 'lost', name: this.$t('KANBAN.COLUMNS.LOST') },
      ],
      dealConversationId: null,
      dealStage: null,
      dealCustomAttributes: {},
      isDealLoading: false,
      showCreateDealModal: false,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUser: 'getCurrentUser',
      teams: 'teams/getTeams',
    }),
    hasAnAssignedTeam() {
      return !!this.currentChat?.meta?.team;
    },
    teamsList() {
      if (this.hasAnAssignedTeam) {
        return [
          { id: 0, name: this.$t('TEAMS_SETTINGS.LIST.NONE') },
          ...this.teams,
        ];
      }
      return this.teams;
    },
    assignedAgent: {
      get() {
        return this.currentChat.meta.assignee;
      },
      set(agent) {
        const agentId = agent ? agent.id : 0;
        this.$store.dispatch('setCurrentChatAssignee', agent);
        this.$store
          .dispatch('assignAgent', {
            conversationId: this.currentChat.id,
            agentId,
          })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_AGENT'));
          });
      },
    },
    assignedTeam: {
      get() {
        return this.currentChat.meta.team;
      },
      set(team) {
        const conversationId = this.currentChat.id;
        const teamId = team ? team.id : 0;
        this.$store.dispatch('setCurrentChatTeam', { team, conversationId });
        this.$store
          .dispatch('assignTeam', { conversationId, teamId })
          .then(() => {
            useAlert(this.$t('CONVERSATION.CHANGE_TEAM'));
          });
      },
    },
    assignedPriority: {
      get() {
        const selectedOption = this.priorityOptions.find(
          opt => opt.id === this.currentChat.priority
        );

        return selectedOption || this.priorityOptions[0];
      },
      set(priorityItem) {
        const conversationId = this.currentChat.id;
        const oldValue = this.currentChat?.priority;
        const priority = priorityItem ? priorityItem.id : null;

        this.$store.dispatch('setCurrentChatPriority', {
          priority,
          conversationId,
        });
        this.$store
          .dispatch('assignPriority', { conversationId, priority })
          .then(() => {
            useTrack(CONVERSATION_EVENTS.CHANGE_PRIORITY, {
              oldValue,
              newValue: priority,
              from: 'Conversation Sidebar',
            });
            useAlert(
              this.$t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SUCCESSFUL', {
                priority: priorityItem.name,
                conversationId,
              })
            );
          });
      },
    },
    selectedStage() {
      if (!this.dealStage) return null;
      return this.stageOptions.find(s => s.id === this.dealStage) || null;
    },
    showSelfAssign() {
      if (!this.assignedAgent) {
        return true;
      }
      if (this.assignedAgent.id !== this.currentUser.id) {
        return true;
      }
      return false;
    },
  },
  watch: {
    conversationId: {
      immediate: true,
      handler() {
        this.loadDealTarget();
      },
    },
  },
  methods: {
    onSelfAssign() {
      const {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        avatar_url,
      } = this.currentUser;
      const selfAssign = {
        account_id,
        availability_status,
        available_name,
        email,
        id,
        name,
        role,
        thumbnail: avatar_url,
      };
      this.assignedAgent = selfAssign;
    },
    onClickAssignAgent(selectedItem) {
      if (this.assignedAgent && this.assignedAgent.id === selectedItem.id) {
        this.assignedAgent = null;
      } else {
        this.assignedAgent = selectedItem;
      }
    },

    onClickAssignTeam(selectedItemTeam) {
      if (this.assignedTeam && this.assignedTeam.id === selectedItemTeam.id) {
        this.assignedTeam = null;
      } else {
        this.assignedTeam = selectedItemTeam;
      }
    },

    onClickAssignPriority(selectedPriorityItem) {
      const isSamePriority =
        this.assignedPriority &&
        this.assignedPriority.id === selectedPriorityItem.id;

      this.assignedPriority = isSamePriority ? null : selectedPriorityItem;
    },

    isCurrentChatDeal() {
      const attrs = (this.currentChat && this.currentChat.custom_attributes) || {};
      return !!attrs.deal_stage;
    },

    pickLatestDealConversation(list) {
      if (!Array.isArray(list)) return null;
      const matches = list.filter(c => {
        const hasLabel =
          Array.isArray(c?.labels) && c.labels.some(l => l === 'deal' || l?.title === 'deal');
        const hasStage = !!(c?.custom_attributes && c.custom_attributes.deal_stage);
        const notResolved = c?.status !== 'resolved';
        return notResolved && (hasLabel || hasStage);
      });
      if (!matches.length) return null;
      const byActivity = (a, b) => {
        const ax = a.last_activity_at || a.created_at || 0;
        const bx = b.last_activity_at || b.created_at || 0;
        return new Date(bx) - new Date(ax);
      };
      return matches.sort(byActivity)[0];
    },

    async loadDealTarget() {
      this.isDealLoading = true;
      try {
        if (this.isCurrentChatDeal()) {
          this.dealConversationId = Number(this.conversationId);
          const attrs = this.currentChat.custom_attributes || {};
          this.dealStage = attrs.deal_stage || 'new';
          this.dealCustomAttributes = { ...attrs };
          return;
        }
        const contactId = this.currentChat?.meta?.sender?.id;
        if (!contactId) {
          this.dealConversationId = null;
          this.dealStage = null;
          this.dealCustomAttributes = {};
          return;
        }
        const { data } = await ContactAPI.getConversations(contactId);
        const items = data?.data || data || [];
        const target = this.pickLatestDealConversation(items);
        if (target) {
          this.dealConversationId = Number(target.id);
          this.dealStage = (target.custom_attributes && target.custom_attributes.deal_stage) || 'new';
          this.dealCustomAttributes = { ...(target.custom_attributes || {}) };
        } else {
          this.dealConversationId = null;
          this.dealStage = null;
          this.dealCustomAttributes = {};
        }
      } catch (e) {
        this.dealConversationId = null;
        this.dealStage = null;
        this.dealCustomAttributes = {};
      } finally {
        this.isDealLoading = false;
      }
    },

    async onClickMoveStage(selectedStageItem) {
      if (!this.dealConversationId || !selectedStageItem) return;
      const prev = this.dealStage;
      this.dealStage = selectedStageItem.id;
      try {
        const attrs = { ...(this.dealCustomAttributes || {}), deal_stage: selectedStageItem.id };
        await ConversationApi.updateCustomAttributes({
          conversationId: this.dealConversationId,
          customAttributes: attrs,
        });
        this.dealCustomAttributes = attrs;
        useAlert(this.$t('KANBAN.ALERTS.STATUS_UPDATED'));
      } catch (e) {
        this.dealStage = prev;
        useAlert(this.$t('KANBAN.ALERTS.STATUS_FAILED'));
      }
    },

    openCreateDeal() {
      this.showCreateDealModal = true;
    },
    closeCreateDeal() {
      this.showCreateDealModal = false;
    },
    async onDealSubmit(payload) {
      try {
        const conversationId = Number(this.currentChat.id);
        const existingLabels = (this.currentChat?.labels || []).map(l =>
          typeof l === 'string' ? l : l?.title || l?.name
        ).filter(Boolean);
        const labels = Array.from(new Set([...(existingLabels || []), 'deal']));
        await ConversationsApi.updateLabels(conversationId, labels);

        const currentAttrs = this.currentChat?.custom_attributes || {};
        const attrs = {
          ...currentAttrs,
          deal_stage: 'new',
          deal_title: payload.title,
          deal_amount: payload.amount,
          deal_currency: payload.currency,
          deal_close_date: payload.closeDate,
          deal_notes: payload.notes,
        };
        await ConversationApi.updateCustomAttributes({
          conversationId,
          customAttributes: attrs,
        });

        // Update local state so dropdown aparece imediatamente
        this.dealConversationId = conversationId;
        this.dealStage = 'new';
        this.dealCustomAttributes = attrs;
        this.showCreateDealModal = false;
        useAlert(this.$t('KANBAN.DEAL_CREATED'));
      } catch (e) {
        useAlert(this.$t('KANBAN.ALERTS.STATUS_FAILED'));
      }
    },
  },
};
</script>

<template>
  <div class="bg-n-background">
    <div class="multiselect-wrap--small">
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.ASSIGNEE_LABEL')"
      >
        <template #button>
          <NextButton
            v-if="showSelfAssign"
            link
            xs
            icon="i-lucide-arrow-right"
            class="!gap-1"
            :label="$t('CONVERSATION_SIDEBAR.SELF_ASSIGN')"
            @click="onSelfAssign"
          />
        </template>
      </ContactDetailsItem>
      <MultiselectDropdown
        :options="agentsList"
        :selected-item="assignedAgent"
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.AGENT')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.AGENT')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.AGENT')
        "
        @select="onClickAssignAgent"
      />
    </div>
    <div class="multiselect-wrap--small">
      <ContactDetailsItem
        compact
        :title="$t('CONVERSATION_SIDEBAR.TEAM_LABEL')"
      />
      <MultiselectDropdown
        :options="teamsList"
        :selected-item="assignedTeam"
        :multiselector-title="$t('AGENT_MGMT.MULTI_SELECTOR.TITLE.TEAM')"
        :multiselector-placeholder="$t('AGENT_MGMT.MULTI_SELECTOR.PLACEHOLDER')"
        :no-search-result="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.NO_RESULTS.TEAM')
        "
        :input-placeholder="
          $t('AGENT_MGMT.MULTI_SELECTOR.SEARCH.PLACEHOLDER.TEAM')
        "
        @select="onClickAssignTeam"
      />
    </div>
    <div class="multiselect-wrap--small">
      <ContactDetailsItem compact :title="$t('CONVERSATION.PRIORITY.TITLE')" />
      <MultiselectDropdown
        :options="priorityOptions"
        :selected-item="assignedPriority"
        :multiselector-title="$t('CONVERSATION.PRIORITY.TITLE')"
        :multiselector-placeholder="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.SELECT_PLACEHOLDER')
        "
        :no-search-result="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.NO_RESULTS')
        "
        :input-placeholder="
          $t('CONVERSATION.PRIORITY.CHANGE_PRIORITY.INPUT_PLACEHOLDER')
        "
        @select="onClickAssignPriority"
      />
    </div>
    <div
      v-if="dealConversationId && dealStage"
      class="multiselect-wrap--small"
    >
      <ContactDetailsItem compact :title="$t('CONVERSATION.DEAL_STAGE.TITLE')" />
      <MultiselectDropdown
        :options="stageOptions"
        :selected-item="selectedStage"
        :multiselector-title="$t('CONVERSATION.DEAL_STAGE.TITLE')"
        :multiselector-placeholder="$t('KANBAN.CARDS.SELECT_STATUS')"
        :no-search-result="$t('KANBAN.CARDS.SELECT_STATUS')"
        :input-placeholder="$t('KANBAN.CARDS.SELECT_STATUS')"
        @select="onClickMoveStage"
      />
    </div>
    <div v-else class="multiselect-wrap--small">
      <ContactDetailsItem compact :title="$t('CONVERSATION.DEAL_STAGE.TITLE')" />
      <NextButton
        link
        xs
        icon="i-lucide-plus"
        class="!gap-1"
        :label="$t('KANBAN.CREATE_DEAL')"
        @click="openCreateDeal"
      />
    </div>
    <ContactDetailsItem
      compact
      :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS')"
    />
    <ConversationLabels :conversation-id="conversationId" />

    <CreateDealModal
      v-if="showCreateDealModal"
      :show="showCreateDealModal"
      :current-chat="currentChat"
      @cancel="closeCreateDeal"
      @submit="onDealSubmit"
    />
  </div>
</template>
