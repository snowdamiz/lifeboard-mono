<script setup lang="ts">
import { useRouter } from 'vue-router'
import { DollarSign } from 'lucide-vue-next'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { useBudgetStore } from '@/stores/budget'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const budgetStore = useBudgetStore()

const handleClick = () => {
  if (!props.isEditMode) {
    router.push('/budget/sources')
  }
}
</script>

<template>
  <div 
    class="h-full cursor-pointer"
    @click="handleClick"
  >
    <CardHeader class="flex flex-row items-center justify-between pb-1.5 sm:pb-2 p-3 sm:p-4">
      <CardTitle class="text-[11px] sm:text-[13px] font-medium text-muted-foreground">Budget Sources</CardTitle>
      <div class="h-7 w-7 sm:h-9 sm:w-9 rounded-lg bg-violet-500/10 flex items-center justify-center">
        <DollarSign class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-violet-600" />
      </div>
    </CardHeader>
    <CardContent class="p-3 pt-0 sm:p-4 sm:pt-0">
      <div class="flex items-baseline gap-1.5 sm:gap-2">
        <span class="text-2xl sm:text-3xl font-semibold tracking-tight tabular-nums">{{ budgetStore.sources.length }}</span>
        <span class="text-[10px] sm:text-xs text-muted-foreground">sources</span>
      </div>
      <p class="text-[10px] sm:text-xs text-muted-foreground mt-1.5 sm:mt-2">
        income & expenses
      </p>
    </CardContent>
  </div>
</template>

