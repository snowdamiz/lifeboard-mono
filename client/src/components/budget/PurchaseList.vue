<script setup lang="ts">
import { computed } from 'vue'
import { ShoppingCart, Tag, DollarSign, Package, Trash2, Edit } from 'lucide-vue-next'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import type { Purchase } from '@/types'

interface Props {
  purchases: Purchase[]
  loading?: boolean
  showActions?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  showActions: true
})

const emit = defineEmits<{
  edit: [purchase: Purchase]
  delete: [id: string]
}>()

const formatCurrency = (amount: string) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(parseFloat(amount))
}

const getPricingInfo = (purchase: Purchase) => {
  if (purchase.count && purchase.price_per_count) {
    return `${purchase.count} × ${formatCurrency(purchase.price_per_count)}`
  } else if (purchase.units && purchase.price_per_unit) {
    return `${purchase.units}${purchase.unit_measurement || ''} × ${formatCurrency(purchase.price_per_unit)}`
  }
  return null
}
</script>

<template>
  <div class="space-y-3">
    <div v-if="loading" class="text-center py-8 text-muted-foreground text-sm">
      Loading purchases...
    </div>

    <div v-else-if="purchases.length === 0" class="text-center py-12">
      <div class="h-16 w-16 rounded-full bg-muted/40 flex items-center justify-center mx-auto mb-4">
        <ShoppingCart class="h-8 w-8 text-muted-foreground/60" />
      </div>
      <h3 class="text-lg font-medium mb-1">No purchases yet</h3>
      <p class="text-sm text-muted-foreground">Add your first purchase to get started</p>
    </div>

    <Card 
      v-for="purchase in purchases" 
      :key="purchase.id"
      class="hover:border-primary/50 transition-colors"
    >
      <CardContent class="p-4">
        <div class="flex items-start justify-between gap-3">
          <div class="flex items-start gap-3 flex-1 min-w-0">
            <div class="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
              <Package class="h-5 w-5 text-primary" />
            </div>
            
            <div class="flex-1 min-w-0">
              <div class="flex items-start justify-between gap-2 mb-1">
                <div class="flex-1 min-w-0">
                  <h4 class="font-semibold text-base truncate">{{ purchase.item }}</h4>
                  <p class="text-sm text-muted-foreground">{{ purchase.brand }}</p>
                </div>
                <div class="text-right flex-shrink-0">
                  <div class="text-lg font-semibold">{{ formatCurrency(purchase.total_price) }}</div>
                  <div v-if="getPricingInfo(purchase)" class="text-xs text-muted-foreground">
                    {{ getPricingInfo(purchase) }}
                  </div>
                </div>
              </div>

              <div class="flex flex-wrap items-center gap-2 mt-2">
                <Badge v-if="purchase.taxable" variant="outline" class="text-xs">
                  Taxable
                </Badge>
                <Badge v-if="purchase.unit_measurement" variant="secondary" class="text-xs">
                  {{ purchase.unit_measurement }}
                </Badge>
                <Badge v-if="purchase.store_code" variant="secondary" class="text-xs font-mono">
                  {{ purchase.store_code }}
                </Badge>
              </div>

              <div v-if="purchase.tags && purchase.tags.length > 0" class="flex flex-wrap gap-1.5 mt-2">
                <Badge
                  v-for="tag in purchase.tags"
                  :key="tag.id"
                  variant="outline"
                  class="text-xs gap-1"
                  :style="{
                    backgroundColor: tag.color + '20',
                    color: tag.color,
                    borderColor: tag.color + '40'
                  }"
                >
                  <div class="h-1.5 w-1.5 rounded-full" :style="{ backgroundColor: tag.color }" />
                  {{ tag.name }}
                </Badge>
              </div>
            </div>
          </div>

          <div v-if="showActions" class="flex gap-1 flex-shrink-0">
            <Button
              variant="ghost"
              size="icon"
              class="h-8 w-8"
              @click="emit('edit', purchase)"
            >
              <Edit class="h-4 w-4" />
            </Button>
            <Button
              variant="ghost"
              size="icon"
              class="h-8 w-8 hover:text-destructive"
              @click="() => { console.log('Delete clicked for', purchase.id); emit('delete', purchase.id); }"
            >
              <Trash2 class="h-4 w-4" />
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  </div>
</template>
