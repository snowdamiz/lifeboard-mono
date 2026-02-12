<script setup lang="ts">
import { onMounted } from 'vue'
import { RouterView } from 'vue-router'
import Sidebar from './Sidebar.vue'
import MobileNav from './MobileNav.vue'
import CommandPalette from '@/components/shared/CommandPalette.vue'
import { useTagsStore } from '@/stores/tags'
import { usePreferencesStore } from '@/stores/preferences'

// Boot prefetch: load universally-needed data as early as possible.
// The staleness guard ensures these are no-ops if already fetched.
onMounted(() => {
  useTagsStore().fetchTags()
  usePreferencesStore().fetchPreferences()
})
</script>

<template>
  <div class="flex h-screen bg-background">
    <Sidebar />
    <div class="flex-1 flex flex-col overflow-hidden">
      <main class="flex-1 overflow-auto scrollbar-thin">
        <div class="min-h-full p-2 sm:p-3 md:px-4 md:py-3 pb-20 md:pb-3">
          <RouterView />
        </div>
      </main>
      <!-- Mobile Bottom Navigation -->
      <MobileNav class="md:hidden" />
    </div>
    <CommandPalette />
  </div>
</template>
