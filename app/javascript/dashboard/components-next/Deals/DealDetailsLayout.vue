<script setup>
import { computed, useSlots, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  selectedDeal: {
    type: Object,
    default: () => ({}),
  },
  isUpdating: {
    type: Boolean,
    default: false,
  },
  showBackButton: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['close', 'goBack']);

const { t } = useI18n();
const slots = useSlots();

const isSidebarOpen = ref(false);

const dealTitle = computed(() => {
  return props.selectedDeal?.custom_attributes?.deal_title || t('DEAL_DETAILS.UNTITLED');
});

const handleClose = () => {
  emit('close');
};

const handleBack = () => {
  emit('goBack');
};

const handleSidebarToggle = () => {
  isSidebarOpen.value = !isSidebarOpen.value;
};

const closeMobileSidebar = () => {
  if (!isSidebarOpen.value) return;
  isSidebarOpen.value = false;
};
</script>

<template>
  <section
    class="flex w-full h-full overflow-hidden justify-evenly bg-n-background"
  >
    <div
      class="flex flex-col w-full h-full transition-all duration-300 ltr:2xl:ml-56 rtl:2xl:mr-56"
    >
      <header class="sticky top-0 z-10 px-6 3xl:px-0 bg-n-background border-b border-n-weak">
        <div class="w-full mx-auto max-w-[40.625rem]">
          <div
            class="flex flex-col xs:flex-row items-start xs:items-center justify-between w-full py-4 gap-2"
          >
            <div class="flex items-center gap-3">
              <Button
                v-if="showBackButton"
                ghost
                slate
                sm
                icon="i-lucide-arrow-left"
                @click="handleBack"
              />
              <div>
                <h1 class="text-lg font-semibold text-n-slate-12">
                  {{ dealTitle }}
                </h1>
                <p class="text-xs text-n-slate-11">
                  {{ $t('DEAL_DETAILS.SUBTITLE') }}
                </p>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <Button
                ghost
                slate
                sm
                icon="i-lucide-x"
                @click="handleClose"
              />
            </div>
          </div>
        </div>
      </header>
      <main class="flex-1 px-6 overflow-y-auto 3xl:px-0">
        <div class="w-full py-4 mx-auto max-w-[40.625rem]">
          <slot name="default" />
        </div>
      </main>
    </div>

    <!-- Desktop sidebar -->
    <div
      v-if="slots.sidebar"
      class="hidden lg:block overflow-y-auto justify-end min-w-52 w-full py-6 max-w-md border-l border-n-weak bg-n-solid-2"
    >
      <slot name="sidebar" />
    </div>

    <!-- Mobile sidebar container -->
    <div
      v-if="slots.sidebar"
      class="lg:hidden fixed top-0 ltr:right-0 rtl:left-0 h-full z-50 flex justify-end transition-all duration-200 ease-in-out"
      :class="isSidebarOpen ? 'w-full' : 'w-16'"
    >
      <!-- Toggle button -->
      <div
        v-on-click-outside="[
          closeMobileSidebar,
          { ignore: ['#deal-sidebar-content'] },
        ]"
        class="flex items-start p-1 w-fit h-fit relative order-1 xs:top-24 top-28 transition-all bg-n-solid-2 border border-n-weak duration-500 ease-in-out"
        :class="[
          isSidebarOpen
            ? 'justify-end ltr:rounded-l-full rtl:rounded-r-full ltr:rounded-r-none rtl:rounded-l-none'
            : 'justify-center rounded-full ltr:mr-6 rtl:ml-6',
        ]"
      >
        <Button
          ghost
          slate
          sm
          class="!rounded-full rtl:rotate-180"
          :class="{ 'bg-n-alpha-2': isSidebarOpen }"
          :icon="
            isSidebarOpen
              ? 'i-lucide-panel-right-close'
              : 'i-lucide-panel-right-open'
          "
          data-deal-sidebar-toggle
          @click="handleSidebarToggle"
        />
      </div>

      <Transition
        enter-active-class="transition-transform duration-200 ease-in-out"
        leave-active-class="transition-transform duration-200 ease-in-out"
        enter-from-class="ltr:translate-x-full rtl:-translate-x-full"
        enter-to-class="ltr:translate-x-0 rtl:-translate-x-0"
        leave-from-class="ltr:translate-x-0 rtl:-translate-x-0"
        leave-to-class="ltr:translate-x-full rtl:-translate-x-full"
      >
        <div
          v-if="isSidebarOpen"
          id="deal-sidebar-content"
          class="order-2 w-[85%] sm:w-[50%] bg-n-solid-2 ltr:border-l rtl:border-r border-n-weak overflow-y-auto py-6 shadow-lg"
        >
          <slot name="sidebar" />
        </div>
      </Transition>
    </div>
  </section>
</template>

