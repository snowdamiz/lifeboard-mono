<script setup lang="ts">
import { Plus, X } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import type { Component } from 'vue'

interface Props {
  icon: Component
  title: string
  description?: string
  actionLabel?: string
  showClearAction?: boolean
  clearLabel?: string
}

const props = withDefaults(defineProps<Props>(), {
  actionLabel: 'Create',
  showClearAction: false,
  clearLabel: 'Clear Filters'
})

const emit = defineEmits<{
  action: []
  clear: []
}>()
</script>

<template>
  <div class="text-center py-16 sm:py-20">
    <!-- Icon Container -->
    <div class="h-16 w-16 rounded-2xl bg-primary/5 mx-auto mb-5 flex items-center justify-center">
      <component :is="icon" class="h-8 w-8 text-primary/50" />
    </div>
    
    <!-- Title -->
    <h2 class="text-lg font-medium mb-2">{{ title }}</h2>
    
    <!-- Description -->
    <p v-if="description" class="text-muted-foreground text-sm mb-6 max-w-sm mx-auto">
      {{ description }}
    </p>
    
    <!-- Action Button -->
    <Button @click="showClearAction ? emit('clear') : emit('action')">
      <component :is="showClearAction ? X : Plus" class="h-4 w-4 mr-2" />
      {{ showClearAction ? clearLabel : actionLabel }}
    </Button>
  </div>
</template>
