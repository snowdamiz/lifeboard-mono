<script setup lang="ts">
import type { Component } from 'vue'

interface Props {
  title: string
  subtitle?: string
  icon: Component
}

defineProps<Props>()
</script>

<template>
  <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
    <div class="flex items-center gap-3">
      <!-- Icon Container -->
      <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
        <component :is="icon" class="h-5 w-5 text-primary" />
      </div>
      <div>
        <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">{{ title }}</h1>
        <p v-if="subtitle" class="text-muted-foreground text-sm mt-0.5">{{ subtitle }}</p>
      </div>
    </div>
    
    <!-- Actions Slot -->
    <div class="flex items-center gap-2 sm:gap-3 w-full sm:w-auto">
      <slot name="actions" />
    </div>
  </div>
</template>
