<script setup lang="ts">
import { useRouter } from 'vue-router'
import { Plus, Calendar, Target, Flame, FileText, Package, DollarSign } from 'lucide-vue-next'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()

const actions = [
  { icon: Calendar, label: 'Task', route: '/calendar', color: 'bg-primary/10 text-primary hover:bg-primary/20' },
  { icon: Target, label: 'Goal', route: '/goals', color: 'bg-blue-500/10 text-blue-600 hover:bg-blue-500/20' },
  { icon: Flame, label: 'Habit', route: '/habits', color: 'bg-orange-500/10 text-orange-600 hover:bg-orange-500/20' },
  { icon: FileText, label: 'Note', route: '/notes', color: 'bg-cyan-500/10 text-cyan-600 hover:bg-cyan-500/20' },
  { icon: Package, label: 'Item', route: '/inventory', color: 'bg-amber-500/10 text-amber-600 hover:bg-amber-500/20' },
  { icon: DollarSign, label: 'Entry', route: '/budget', color: 'bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20' },
]

const handleAction = (route: string) => {
  if (!props.isEditMode) {
    router.push(route)
  }
}
</script>

<template>
  <div class="h-full flex flex-col">
    <CardHeader class="flex flex-row items-center justify-between pb-2 sm:pb-3 p-3 sm:p-4">
      <CardTitle class="text-sm sm:text-base font-medium flex items-center gap-2">
        <Plus class="h-4 w-4 text-primary" />
        Quick Actions
      </CardTitle>
    </CardHeader>
    <CardContent class="pt-0 p-3 sm:p-4 sm:pt-0 flex-1">
      <div class="grid grid-cols-3 gap-2">
        <button
          v-for="action in actions"
          :key="action.label"
          :class="[
            'flex flex-col items-center gap-2 p-3 rounded-xl transition-colors',
            action.color
          ]"
          @click="handleAction(action.route)"
        >
          <component :is="action.icon" class="h-5 w-5" />
          <span class="text-xs font-medium">{{ action.label }}</span>
        </button>
      </div>
    </CardContent>
  </div>
</template>

