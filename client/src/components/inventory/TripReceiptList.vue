<script setup lang="ts">
import { ref, computed } from 'vue'
import { ChevronDown, ChevronRight, Store, Calendar, Package, ArrowRightLeft } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import type { TripReceipt, InventoryItem } from '@/types'

const props = defineProps<{
  receipts: TripReceipt[]
}>()

const emit = defineEmits<{
  (e: 'transfer', item: InventoryItem): void
}>()

const expandedReceipts = ref<Set<string>>(new Set())

const toggleExpand = (receiptId: string) => {
  const newSet = new Set(expandedReceipts.value)
  if (newSet.has(receiptId)) {
    newSet.delete(receiptId)
  } else {
    newSet.add(receiptId)
  }
  expandedReceipts.value = newSet
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

const getTotalItems = (receipt: TripReceipt) => {
  return receipt.items.reduce((sum, item) => sum + item.quantity, 0)
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
            {{ receipt.items.length }} items ({{ getTotalItems(receipt) }} total)
          </Badge>
        </div>
      </CardHeader>

      <CardContent v-if="expandedReceipts.has(receipt.id)" class="p-0 border-t border-border">
        <!-- Desktop Table View -->
        <div class="hidden md:block overflow-x-auto">
          <table class="w-full">
            <thead class="bg-secondary/50">
              <tr>
                <th class="text-left p-3 text-sm font-medium text-muted-foreground w-36">Brand</th>
                <th class="text-left p-3 text-sm font-medium text-muted-foreground">Name</th>
                <th class="text-left p-3 text-sm font-medium text-muted-foreground w-32">Store</th>
                <th class="text-center p-3 text-sm font-medium text-muted-foreground w-24">Quantity</th>
                <th class="text-center p-3 text-sm font-medium text-muted-foreground w-20">Unit</th>
                <th class="w-24"></th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="item in receipt.items"
                :key="item.id"
                class="border-t border-border hover:bg-secondary/30 transition-colors"
              >
                <td class="p-3 text-muted-foreground text-sm">
                  {{ item.brand || '-' }}
                </td>
                <td class="p-3">
                  <div class="min-w-0">
                    <span class="font-medium">{{ item.name }}</span>
                    <div class="text-xs text-muted-foreground mt-0.5" v-if="item.store_code">Code: {{ item.store_code }}</div>
                    <div v-if="item.tags?.length" class="flex gap-1 mt-1 flex-wrap">
                      <Badge
                        v-for="tag in item.tags"
                        :key="tag.id"
                        :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                        variant="outline"
                        class="text-[9px] px-1 h-4"
                      >
                        {{ tag.name }}
                      </Badge>
                    </div>
                  </div>
                </td>
                <td class="p-3 text-muted-foreground text-sm">
                  {{ item.store || '-' }}
                </td>
                <td class="p-3 text-center">
                  <span class="font-mono text-sm">{{ item.quantity }}</span>
                </td>
                <td class="p-3 text-center text-muted-foreground text-xs">
                  {{ item.unit_of_measure || '-' }}
                </td>
                <td class="p-3">
                  <Button
                    variant="ghost"
                    size="sm"
                    class="h-8 gap-1.5 ml-auto"
                    @click.stop="emit('transfer', item)"
                  >
                    <ArrowRightLeft class="h-4 w-4" />
                    <span class="hidden lg:inline">Transfer</span>
                  </Button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Mobile Item View -->
        <div class="md:hidden divide-y divide-border">
          <div
            v-for="item in receipt.items"
            :key="item.id"
            class="p-3 hover:bg-secondary/30 transition-colors"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex-1 min-w-0">
                <h3 class="font-medium text-sm truncate">{{ item.name }}</h3>
                <div class="flex items-center gap-3 mt-1.5 text-xs text-muted-foreground flex-wrap">
                  <span v-if="item.brand" class="font-medium">{{ item.brand }}</span>
                  <span v-if="item.store">{{ item.store }}</span>
                  <span v-if="item.store_code" class="opacity-70">({{ item.store_code }})</span>
                </div>
                <div v-if="item.tags?.length" class="flex gap-1 mt-1.5 flex-wrap">
                  <Badge
                    v-for="tag in item.tags"
                    :key="tag.id"
                    :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                    variant="outline"
                    class="text-[9px] px-1 h-4"
                  >
                    {{ tag.name }}
                  </Badge>
                </div>
              </div>
              
              <div class="flex flex-col items-end gap-2">
                 <Badge variant="outline" class="font-mono">
                  {{ item.quantity }} {{ item.unit_of_measure || '' }}
                </Badge>
                <Button
                  variant="ghost"
                  size="sm"
                  class="h-7 px-2 text-xs"
                  @click.stop="emit('transfer', item)"
                >
                  <ArrowRightLeft class="h-3 w-3 mr-1" />
                  Transfer
                </Button>
              </div>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  </div>
</template>
