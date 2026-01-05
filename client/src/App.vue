<script setup lang="ts">
import { RouterView } from 'vue-router'
import ShortcutsHelp from '@/components/shared/ShortcutsHelp.vue'
import { useKeyboardShortcuts } from '@/composables/useKeyboardShortcuts'

// Initialize global keyboard shortcuts
useKeyboardShortcuts()
</script>

<template>
  <RouterView />
  <ShortcutsHelp />
</template>

