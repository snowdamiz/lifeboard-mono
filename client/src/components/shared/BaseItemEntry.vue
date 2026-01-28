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
    <CardContent class="p-2.5">
      <div class="flex gap-3 items-center">
        <!-- Leading slot: icon, checkbox, or custom -->
        <slot name="leading">
          <div class="h-8 w-8 rounded-md bg-primary/10 flex items-center justify-center flex-shrink-0">
            <Package class="h-4 w-4 text-primary" />
          </div>
        </slot>

        <div class="flex-1 min-w-0 flex flex-col gap-1">
          <!-- Line 1: Item Name (Brand) ........... Total/Right Content -->
          <div class="flex items-baseline justify-between gap-2">
            <div class="flex items-baseline gap-2 min-w-0 truncate">
              <span class="font-semibold text-sm truncate" :title="name">{{ name }}</span>
              <span v-if="brand" class="text-xs text-muted-foreground truncate" :title="brand">{{ brand }}</span>
            </div>
            <slot name="right-value">
              <div v-if="total !== undefined" class="font-bold text-sm text-primary whitespace-nowrap">
                {{ formattedTotal }}
              </div>
            </slot>
          </div>

          <!-- Line 2: Details inline -->
          <div class="flex items-center gap-x-3 gap-y-1 text-[11px] text-muted-foreground flex-wrap leading-none">
            <!-- Qty -->
            <div v-if="hasQuantityInfo" class="flex items-center gap-1">
              <span class="font-bold text-[9px] uppercase tracking-wider opacity-70">Qty:</span>
              <span class="font-mono text-foreground">{{ quantity }}<span v-if="unit" class="text-[10px] ml-0.5">{{ unit }}</span></span>
            </div>
            
            <!-- Price -->
            <div v-if="hasPriceInfo" class="flex items-center gap-1">
              <span class="font-bold text-[9px] uppercase tracking-wider opacity-70">Price:</span>
              <span class="font-mono text-foreground">{{ formattedPrice }}</span>
            </div>

            <!-- Store -->
            <div v-if="hasStore" class="flex items-center gap-1 border-l border-border pl-2">
              <span class="font-bold text-[9px] uppercase tracking-wider opacity-70">Store:</span>
              <span class="text-foreground">{{ store }}</span>
            </div>

            <!-- Code -->
            <div v-if="hasStoreCode" class="flex items-center gap-1 border-l border-border pl-2">
              <span class="font-bold text-[9px] uppercase tracking-wider opacity-70">Code:</span>
              <span class="font-mono text-foreground">{{ storeCode }}</span>
            </div>

            <!-- Tax -->
            <div v-if="taxable" class="flex items-center gap-1 border-l border-border pl-2">
              <span class="font-bold text-[9px] uppercase tracking-wider opacity-70">Tax:</span>
              <span class="text-foreground">Yes</span>
            </div>

            <!-- Tags -->
            <div v-if="hasTags" class="flex items-center gap-1 border-l border-border pl-2">
              <Badge
                v-for="tag in tags"
                :key="tag.id"
                variant="outline"
                class="text-[9px] px-1 py-0 h-3.5 border-0 gap-1 rounded-sm"
                :style="{ backgroundColor: tag.color + '15', color: tag.color }"
              >
                <div class="h-1 w-1 rounded-full" :style="{ backgroundColor: tag.color }" />
                {{ tag.name }}
              </Badge>
            </div>
            
            <!-- Additional inline details slot -->
            <slot name="details" />
          </div>

          <!-- Extension slot for quantity controls, min field, etc. -->
          <slot name="extension" />
        </div>

        <!-- Actions slot -->
        <slot name="actions" />
      </div>
    </CardContent>
  </Card>
</template>
