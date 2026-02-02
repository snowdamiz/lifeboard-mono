<script setup lang="ts">
import { computed } from 'vue'
import { ShoppingCart } from 'lucide-vue-next'
import type { Trip } from '@/types'
import { cn } from '@/lib/utils'
import DeleteButton from '@/components/shared/DeleteButton.vue'

interface Props {
  trip: Trip
  compact?: boolean
  showDelete?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  compact: false,
  showDelete: true
})

const emit = defineEmits<{
  click: [tripId: string]
  delete: [tripId: string]
}>()

// Compute trip summary data
const totalPurchases = computed(() => {
  return props.trip.stops.reduce((sum, stop) => sum + (stop.purchases?.length || 0), 0)
})

const totalSpent = computed(() => {
  let total = 0
  for (const stop of props.trip.stops) {
    for (const purchase of stop.purchases || []) {
      total += parseFloat(purchase.total_price || '0')
    }
  }
  return total.toFixed(2)
})

const storeName = computed(() => {
  if (props.trip.stops.length === 0) return 'Shopping Trip'
  if (props.trip.stops.length === 1) return props.trip.stops[0].store_name || 'Shopping Trip'
  return `${props.trip.stops[0].store_name || 'Trip'} +${props.trip.stops.length - 1}`
})

const handleClick = () => {
  emit('click', props.trip.id)
}

const handleDelete = () => {
  emit('delete', props.trip.id)
}
</script>

<template>
  <div
    :class="cn(
      'group relative rounded-lg border transition-all duration-200 cursor-pointer',
      'bg-gradient-to-r from-emerald-500/10 to-teal-500/5',
      'border-emerald-500/20 hover:border-emerald-500/40',
      'hover:bg-emerald-500/15 hover:shadow-md hover:shadow-emerald-500/5',
      compact ? 'px-2 py-1' : 'px-3 py-2'
    )"
    @click="handleClick"
  >
    <div class="flex items-center gap-2">
      <!-- Icon -->
      <div :class="cn(
        'shrink-0 rounded-md bg-emerald-500/20 flex items-center justify-center',
        compact ? 'h-5 w-5' : 'h-6 w-6'
      )">
        <ShoppingCart :class="cn('text-emerald-500', compact ? 'h-3 w-3' : 'h-3.5 w-3.5')" />
      </div>
      
      <!-- Content -->
      <div class="flex-1 min-w-0">
        <p :class="cn(
          'font-medium text-foreground truncate',
          compact ? 'text-[11px] leading-tight' : 'text-xs'
        )">
          {{ storeName }}
        </p>
        <p v-if="!compact" class="text-[10px] text-muted-foreground flex items-center gap-2">
          <span>{{ totalPurchases }} items</span>
          <span class="text-emerald-500 font-medium">${{ totalSpent }}</span>
        </p>
      </div>

      <!-- Compact price -->
      <span v-if="compact" class="text-[10px] text-emerald-500 font-medium shrink-0">
        -${{ totalSpent }}
      </span>

      <!-- Delete button -->
      <DeleteButton
        v-if="showDelete"
        :size="compact ? 'sm' : 'sm'"
        class="-mr-1"
        @click.stop="handleDelete"
      />
    </div>
  </div>
</template>

