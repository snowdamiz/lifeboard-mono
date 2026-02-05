<script setup lang="ts">
import { ShoppingCart, Edit2, Trash2 } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import BaseItemEntry from '@/components/shared/BaseItemEntry.vue'
import BaseIconButton from '@/components/shared/BaseIconButton.vue'
import type { Purchase } from '@/types'

interface Props {
  purchases: Purchase[]
  loading?: boolean
  showActions?: boolean
}

withDefaults(defineProps<Props>(), {
  loading: false,
  showActions: true
})

const emit = defineEmits<{
  edit: [purchase: Purchase]
  delete: [id: string]
}>()

const getQuantity = (p: Purchase) => {
  if (p.count) return p.count
  if (p.units) return p.units
  return '1'
}

const getUnitLabel = (p: Purchase) => {
  if (p.unit_measurement) return p.unit_measurement
  return ''
}

const getUnitPrice = (p: Purchase) => {
  if (p.count && p.price_per_count) return p.price_per_count
  if (p.units && p.price_per_unit) return p.price_per_unit
  return null
}
</script>

<template>
  <div class="space-y-1.5">
    <div v-if="loading" class="text-center py-4 text-muted-foreground text-xs">
      Loading purchases...
    </div>

    <div v-else-if="purchases.length === 0" class="text-center py-8">
      <div class="h-10 w-10 rounded-full bg-muted/40 flex items-center justify-center mx-auto mb-2">
        <ShoppingCart class="h-5 w-5 text-muted-foreground/60" />
      </div>
      <h3 class="text-sm font-medium mb-0.5">No purchases yet</h3>
      <p class="text-xs text-muted-foreground">Add your first purchase to get started</p>
    </div>

    <BaseItemEntry
      v-for="purchase in purchases"
      :key="purchase.id"
      :name="purchase.item"
      :brand="purchase.brand"
      :quantity="getQuantity(purchase)"
      :unit="getUnitLabel(purchase)"
      :price="getUnitPrice(purchase)"
      :total="purchase.total_price"
      :store-code="purchase.store_code"
      :taxable="purchase.taxable"
      :tags="purchase.tags"
    >
      <template #actions v-if="showActions">
        <div class="flex gap-0.5 flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity self-center pl-1">
          <BaseIconButton :icon="Edit2" :adaptive="false" @click="emit('edit', purchase)" />
          <BaseIconButton :icon="Trash2" variant="destructive" :adaptive="false" @click="emit('delete', purchase.id)" />
        </div>
      </template>
    </BaseItemEntry>
  </div>
</template>
