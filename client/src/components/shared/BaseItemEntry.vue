<script setup lang="ts">
import { computed } from 'vue'
import { Package } from 'lucide-vue-next'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

interface Tag {
  id: string
  name: string
  color: string
}

interface Props {
  // Core item info
  name: string
  brand?: string | null

  // Quantity/measurement
  quantity?: string | number | null
  unit?: string | null
  
  // Pricing
  price?: string | number | null
  total?: string | number | null
  
  // Store info
  storeCode?: string | null
  store?: string | null
  
  // Tax
  taxable?: boolean
  
  // Tags
  tags?: Tag[]
  
  // Styling
  highlighted?: boolean
  highlightClass?: string
}

const props = withDefaults(defineProps<Props>(), {
  highlighted: false,
  highlightClass: ''
})

const formatCurrency = (amount: string | number | null | undefined) => {
  if (amount === null || amount === undefined) return '$0.00'
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(typeof amount === 'string' ? parseFloat(amount) : amount)
}

const formattedPrice = computed(() => formatCurrency(props.price))
const formattedTotal = computed(() => formatCurrency(props.total))

const hasQuantityInfo = computed(() => props.quantity !== undefined && props.quantity !== null && props.quantity !== '')
const hasPriceInfo = computed(() => props.price !== undefined && props.price !== null)
const hasStoreCode = computed(() => !!props.storeCode)
const hasStore = computed(() => !!props.store)
const hasTags = computed(() => props.tags && props.tags.length > 0)

const cardClass = computed(() => {
  let cls = 'hover:border-primary/50 transition-colors group'
  if (props.highlighted && props.highlightClass) {
    cls += ' ' + props.highlightClass
  }
  return cls
})
</script>

<template>
  <Card :class="cardClass">
    <CardContent class="p-2">
      <div class="flex items-center gap-2">
        <!-- Leading slot: icon, checkbox, or custom -->
        <slot name="leading">
          <div class="h-7 w-7 rounded-md bg-primary/10 flex items-center justify-center flex-shrink-0">
            <Package class="h-3.5 w-3.5 text-primary" />
          </div>
        </slot>

        <!-- Main content: Item | Brand | Quantity on one line -->
        <div class="flex-1 min-w-0">
          <!-- Line 1: Name, Brand, Quantity - all inline -->
          <div class="flex items-center gap-2 min-w-0">
            <span class="font-semibold text-sm truncate flex-shrink min-w-0" :title="name">{{ name }}</span>
            <span v-if="brand" class="text-xs text-muted-foreground truncate flex-shrink-0 max-w-[80px]" :title="brand">{{ brand }}</span>
            <slot name="right-value">
              <Badge v-if="hasQuantityInfo" variant="outline" class="font-mono text-[10px] px-1.5 py-0 h-5 flex-shrink-0">
                {{ quantity }}{{ unit ? ' ' + unit : '' }}
              </Badge>
            </slot>
          </div>

          <!-- Line 2: Details (Store, Code, Tax) - compact inline -->
          <div v-if="hasStore || hasStoreCode || taxable || hasTags" class="flex items-center gap-2 text-[10px] text-muted-foreground mt-0.5">
            <span v-if="hasStore" class="truncate">{{ store }}</span>
            <span v-if="hasStoreCode" class="font-mono">{{ storeCode }}</span>
            <span v-if="taxable" class="text-amber-600">Tax</span>
            <template v-if="hasTags">
              <Badge
                v-for="tag in tags"
                :key="tag.id"
                variant="outline"
                class="text-[8px] px-1 py-0 h-3.5 border-0 gap-0.5 rounded-sm"
                :style="{ backgroundColor: tag.color + '15', color: tag.color }"
              >
                {{ tag.name }}
              </Badge>
            </template>
            <slot name="details" />
          </div>
        </div>

        <!-- Extension slot for quantity controls, min field, etc. -->
        <slot name="extension" />

        <!-- Actions slot -->
        <slot name="actions" />
      </div>
    </CardContent>
  </Card>
</template>
