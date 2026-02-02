<script setup lang="ts">
/**
 * TripDetailModal - Modal/inline wrapper for trip details
 * 
 * This component handles the modal/inline presentation layer only.
 * All trip management logic is in TripDetailContent.vue for reuse.
 */
import TripDetailContent from './TripDetailContent.vue'

interface Props {
  tripId: string
  inlineMode?: boolean
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
}>()
</script>

<template>
  <!-- Inline mode: render directly without Teleport -->
  <div v-if="inlineMode" class="h-full flex flex-col">
    <TripDetailContent 
      :trip-id="tripId" 
      :inline-mode="true"
      @close="emit('close')" 
    />
  </div>

  <!-- Modal mode: use Teleport -->
  <Teleport v-else to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4" style="z-index: 50;">
      <div class="w-full sm:max-w-4xl bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[95vh] sm:max-h-[92vh] flex flex-col">
        <TripDetailContent 
          :trip-id="tripId" 
          :inline-mode="false"
          @close="emit('close')" 
        />
      </div>
    </div>
  </Teleport>
</template>
