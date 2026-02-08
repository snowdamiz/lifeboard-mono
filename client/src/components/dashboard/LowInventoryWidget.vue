<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { ChevronRight, AlertTriangle, CheckCircle2 } from 'lucide-vue-next'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
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
    .slice(0, 5)
})
</script>

<template>
  <div class="h-full flex flex-col">
    <CardHeader class="flex flex-row items-center justify-between pb-2 sm:pb-3 p-3 sm:p-4">
      <CardTitle class="text-sm sm:text-base font-medium">Low Inventory</CardTitle>
      <Button 
        variant="ghost" 
        size="sm" 
        class="text-muted-foreground hover:text-foreground -mr-2 h-8 px-2 sm:px-3" 
        @click="!isEditMode && router.push('/inventory/shopping-list')"
      >
        <span class="hidden sm:inline">Shopping list</span>
        <ChevronRight class="h-4 w-4 sm:ml-0.5" />
      </Button>
    </CardHeader>
    <CardContent class="pt-0 p-3 sm:p-4 sm:pt-0 flex-1 overflow-auto">
      <div v-if="lowInventoryItems.length === 0" class="text-center py-4">
        <div class="h-10 w-10 rounded-xl bg-primary/5 mx-auto mb-2 flex items-center justify-center">
          <CheckCircle2 class="h-5 w-5 text-primary/60" />
        </div>
        <p class="font-medium text-foreground text-sm">All stocked up</p>
        <p class="text-xs text-muted-foreground mt-0.5">Inventory is looking good</p>
      </div>
      <div v-else class="space-y-1">
        <div
          v-for="item in lowInventoryItems"
          :key="item.id"
          class="flex items-center gap-2.5 sm:gap-3 p-2.5 sm:p-3 rounded-lg hover:bg-secondary/60 active:bg-secondary transition-colors touch-manipulation"
        >
          <div class="h-8 w-8 sm:h-9 sm:w-9 rounded-lg bg-destructive/8 flex items-center justify-center shrink-0">
            <AlertTriangle class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-destructive" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-xs sm:text-sm font-medium truncate">{{ item.name }}</p>
            <p class="text-[10px] sm:text-xs text-muted-foreground mt-0.5">
              <span class="text-destructive font-medium">{{ (item.usage_mode === 'count' || !item.usage_mode) ? (Number(item.count) || 0) : item.quantity }}</span> / {{ item.min_quantity }} min
            </p>
          </div>
          <Badge variant="destructive" class="shrink-0 text-[10px] sm:text-xs px-1.5 sm:px-2">Low</Badge>
        </div>
      </div>
    </CardContent>
  </div>
</template>

