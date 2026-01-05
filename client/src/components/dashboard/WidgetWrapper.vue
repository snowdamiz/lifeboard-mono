<script setup lang="ts">
import { X } from 'lucide-vue-next'
import { Card } from '@/components/ui/card'

defineProps<{
  isEditMode: boolean
}>()

const emit = defineEmits<{
  remove: []
}>()
</script>

<template>
  <Card class="h-full w-full overflow-hidden relative group">
    <!-- Edit mode controls -->
    <div v-if="isEditMode" class="absolute inset-0 z-10 pointer-events-none">
      <!-- Drag handle indicator -->
      <div class="absolute top-0 left-0 right-0 h-6 bg-primary/5 border-b border-primary/20 flex items-center justify-center pointer-events-auto cursor-move">
        <div class="flex gap-1">
          <div class="w-1 h-1 rounded-full bg-primary/40" />
          <div class="w-1 h-1 rounded-full bg-primary/40" />
          <div class="w-1 h-1 rounded-full bg-primary/40" />
        </div>
      </div>
      
      <!-- Remove button -->
      <button
        class="absolute top-0.5 right-0.5 p-1 rounded-md bg-destructive/90 text-destructive-foreground hover:bg-destructive transition-colors pointer-events-auto z-20"
        @click.stop="emit('remove')"
        title="Remove widget"
      >
        <X class="h-3 w-3" />
      </button>
    </div>

    <!-- Widget content -->
    <div :class="['h-full overflow-auto', isEditMode && 'pt-6']">
      <slot />
    </div>
  </Card>
</template>
