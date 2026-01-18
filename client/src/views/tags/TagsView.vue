<script setup lang="ts">
import { Tag } from 'lucide-vue-next'
import TagManager from '@/components/shared/TagManager.vue'
</script>

<template>
  <div class="min-h-screen bg-background p-4 md:p-6">
    <div class="max-w-2xl mx-auto">
      <!-- Header -->
      <div class="flex items-center gap-3 mb-6">
        <Tag class="h-6 w-6 text-primary" />
        <h1 class="text-2xl font-bold">Tags</h1>
      </div>

      <!-- Unified Tag Manager -->
      <TagManager :embedded="true" />
    </div>
  </div>
</template>
