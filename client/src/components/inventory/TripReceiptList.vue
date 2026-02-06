<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { ChevronDown, ChevronRight, Store, Calendar, Package, ArrowRightLeft, Trash } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import BaseItemEntry from '@/components/shared/BaseItemEntry.vue'
import type { TripReceipt, InventoryItem } from '@/types'

const props = defineProps<{
  receipts: TripReceipt[]
  expandedIds?: Set<string>
}>()

const emit = defineEmits<{
  (e: 'transfer', item: InventoryItem): void
  (e: 'delete', item: InventoryItem): void
  (e: 'deleteTrip', tripId: string): void
  (e: 'update:expandedIds', ids: Set<string>): void
}>()

// Use prop if provided, otherwise local state
const localExpanded = ref<Set<string>>(new Set())
const expandedReceipts = computed(() => props.expandedIds ?? localExpanded.value)

const toggleExpand = (receiptId: string) => {
  const newSet = new Set(expandedReceipts.value)
  if (newSet.has(receiptId)) {
    newSet.delete(receiptId)
  } else {
    newSet.add(receiptId)
  }
  if (props.expandedIds !== undefined) {
    emit('update:expandedIds', newSet)
  } else {
    localExpanded.value = newSet
  }
}

const formatDate = (dateStr: string | null) => {
  if (!dateStr) return 'Unknown date'
  const date = new Date(dateStr)
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit'
  }).format(date)
}


</script>

<template>
  <div class="space-y-3">
    <div v-if="receipts.length === 0" class="text-center py-8 text-muted-foreground">
      <Package class="h-12 w-12 mx-auto mb-3 opacity-50" />
      <p>No trip receipts found</p>
      <p class="text-sm mt-1">Purchase items on shopping trips to see them here</p>
    </div>

    <Card
      v-for="receipt in receipts"
      :key="receipt.id"
      class="overflow-hidden"
    >
      <CardHeader
        class="py-3 px-4 cursor-pointer hover:bg-muted/50 transition-colors"
        @click="toggleExpand(receipt.id)"
      >
        <div class="flex items-center gap-3">
          <div class="flex-shrink-0">
            <component
              :is="expandedReceipts.has(receipt.id) ? ChevronDown : ChevronRight"
              class="h-5 w-5 text-muted-foreground"
            />
          </div>
          <div class="flex-1 min-w-0">
            <CardTitle class="text-base flex items-center gap-2">
              <Store class="h-4 w-4 text-primary" />
              <span class="truncate">{{ receipt.store_name || 'Unknown Store' }}</span>
            </CardTitle>
            <div class="flex items-center gap-2 mt-1 text-sm text-muted-foreground">
              <Calendar class="h-3.5 w-3.5" />
              <span>{{ formatDate(receipt.trip_start || receipt.date) }}</span>
            </div>
          </div>
          <Badge variant="secondary" class="shrink-0">
            {{ receipt.items.length }} ITEMS
          </Badge>
          <Button
            v-if="receipt.trip_id"
            variant="ghost"
            size="icon"
            class="h-8 w-8 shrink-0 text-destructive hover:text-destructive hover:bg-destructive/10"
            @click.stop="emit('deleteTrip', receipt.trip_id!)"
          >
            <Trash class="h-4 w-4" />
          </Button>
        </div>
      </CardHeader>

      <CardContent v-if="expandedReceipts.has(receipt.id)" class="p-2 border-t border-border space-y-1.5">
        <BaseItemEntry
          v-for="item in receipt.items"
          :key="item.id"
          :name="item.name"
          :brand="item.brand"
          :count="item.count"
          :count-unit="item.count_unit"
          :units="item.quantity"
          :unit-measurement="item.unit_of_measure"
          :store="item.store"
          :store-code="item.store_code"
          :price="item.price_per_unit"
          :total="item.total_price"
          :taxable="item.taxable ?? false"
          :tags="item.tags"
        >
          <!-- Right value: Quantity badge (compact) - uses BaseItemEntry default now -->
          

          <!-- Actions (icon-only on mobile) -->
          <template #actions>
            <div class="flex items-center gap-0.5 flex-shrink-0">
              <Button
                variant="ghost"
                size="icon"
                class="h-6 w-6"
                @click.stop="emit('transfer', item)"
              >
                <ArrowRightLeft class="h-3 w-3" />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                class="h-6 w-6 text-destructive hover:text-destructive"
                @click.stop="emit('delete', item)"
              >
                <Trash class="h-3 w-3" />
              </Button>
            </div>
          </template>
        </BaseItemEntry>
      </CardContent>
    </Card>
  </div>
</template>

