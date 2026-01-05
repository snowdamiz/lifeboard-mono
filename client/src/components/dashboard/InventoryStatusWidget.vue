<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { Package, AlertTriangle, CheckCircle2 } from 'lucide-vue-next'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { useInventoryStore } from '@/stores/inventory'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const inventoryStore = useInventoryStore()

const lowInventoryItems = computed(() => {
  if (!inventoryStore.currentSheet?.items) return []
  return inventoryStore.currentSheet.items
    .filter(item => item.is_necessity && item.quantity < item.min_quantity)
})

const handleClick = () => {
  if (!props.isEditMode) {
    router.push('/inventory')
  }
}
</script>

<template>
  <div 
    class="h-full cursor-pointer"
    @click="handleClick"
  >
    <CardHeader class="flex flex-row items-center justify-between pb-1.5 sm:pb-2 p-3 sm:p-4">
      <CardTitle class="text-[11px] sm:text-[13px] font-medium text-muted-foreground">Inventory</CardTitle>
      <div class="h-7 w-7 sm:h-9 sm:w-9 rounded-lg bg-amber-500/10 flex items-center justify-center">
        <Package class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-amber-600" />
      </div>
    </CardHeader>
    <CardContent class="p-3 pt-0 sm:p-4 sm:pt-0">
      <div class="flex items-baseline gap-1.5 sm:gap-2">
        <span class="text-2xl sm:text-3xl font-semibold tracking-tight tabular-nums">{{ inventoryStore.sheets.length }}</span>
        <span class="text-[10px] sm:text-xs text-muted-foreground">sheets</span>
      </div>
      <p class="text-[10px] sm:text-xs mt-1.5 sm:mt-2 flex items-center gap-1">
        <span v-if="lowInventoryItems.length > 0" class="text-amber-600 flex items-center gap-1">
          <AlertTriangle class="h-3 w-3" />
          {{ lowInventoryItems.length }} low
        </span>
        <span v-else class="text-muted-foreground flex items-center gap-1">
          <CheckCircle2 class="h-3 w-3 text-primary" />
          Stocked
        </span>
      </p>
    </CardContent>
  </div>
</template>

