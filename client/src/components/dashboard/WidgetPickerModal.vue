<script setup lang="ts">
import { computed } from 'vue'
import { 
  Calendar, Package, TrendingUp, DollarSign, Flame, Target, 
  FileText, CalendarDays, Bell, Trophy, CalendarRange, Plus, X,
  AlertTriangle
} from 'lucide-vue-next'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { usePreferencesStore } from '@/stores/preferences'
import { widgetMeta } from './widgetConfig'
import type { WidgetType } from '@/types'

const props = defineProps<{
  open: boolean
}>()

const emit = defineEmits<{
  'update:open': [value: boolean]
  'add': [type: WidgetType]
}>()

const preferencesStore = usePreferencesStore()

const availableWidgets = computed(() => {
  const usedTypes = new Set(preferencesStore.dashboardWidgets.map(w => w.type))
  return widgetMeta.filter(m => !usedTypes.has(m.type))
})

const categorizedWidgets = computed(() => {
  return {
    stats: availableWidgets.value.filter(w => w.category === 'stats'),
    lists: availableWidgets.value.filter(w => w.category === 'lists'),
    actions: availableWidgets.value.filter(w => w.category === 'actions'),
  }
})

const iconMap: Record<string, typeof Calendar> = {
  Calendar,
  Package,
  TrendingUp,
  DollarSign,
  Flame,
  Target,
  FileText,
  CalendarDays,
  Bell,
  Trophy,
  CalendarRange,
  Plus,
  AlertTriangle,
}

const getIcon = (iconName: string) => {
  return iconMap[iconName] || Calendar
}

const handleAdd = (type: WidgetType) => {
  emit('add', type)
}

const handleClose = () => {
  emit('update:open', false)
}
</script>

<template>
  <Dialog :open="open" @update:open="emit('update:open', $event)">
    <DialogContent class="max-w-2xl max-h-[80vh] overflow-hidden flex flex-col">
      <DialogHeader>
        <DialogTitle class="flex items-center gap-2">
          <Plus class="h-5 w-5" />
          Add Widget
        </DialogTitle>
        <DialogDescription>
          Choose a widget to add to your dashboard
        </DialogDescription>
      </DialogHeader>

      <div class="flex-1 overflow-auto py-4 space-y-6">
        <!-- Stats Widgets -->
        <div v-if="categorizedWidgets.stats.length > 0">
          <h3 class="text-sm font-medium text-muted-foreground mb-3">Stats & Metrics</h3>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <button
              v-for="widget in categorizedWidgets.stats"
              :key="widget.type"
              class="flex flex-col items-start gap-2 p-4 rounded-xl border bg-card hover:bg-secondary/50 hover:border-primary/30 transition-colors text-left"
              @click="handleAdd(widget.type)"
            >
              <div class="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center">
                <component :is="getIcon(widget.icon)" class="h-5 w-5 text-primary" />
              </div>
              <div>
                <p class="font-medium text-sm">{{ widget.name }}</p>
                <p class="text-xs text-muted-foreground line-clamp-2">{{ widget.description }}</p>
              </div>
              <Badge variant="secondary" class="text-[10px]">{{ widget.defaultSize }}</Badge>
            </button>
          </div>
        </div>

        <!-- List Widgets -->
        <div v-if="categorizedWidgets.lists.length > 0">
          <h3 class="text-sm font-medium text-muted-foreground mb-3">Lists & Details</h3>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <button
              v-for="widget in categorizedWidgets.lists"
              :key="widget.type"
              class="flex flex-col items-start gap-2 p-4 rounded-xl border bg-card hover:bg-secondary/50 hover:border-primary/30 transition-colors text-left"
              @click="handleAdd(widget.type)"
            >
              <div class="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center">
                <component :is="getIcon(widget.icon)" class="h-5 w-5 text-primary" />
              </div>
              <div>
                <p class="font-medium text-sm">{{ widget.name }}</p>
                <p class="text-xs text-muted-foreground line-clamp-2">{{ widget.description }}</p>
              </div>
              <Badge variant="secondary" class="text-[10px]">{{ widget.defaultSize }}</Badge>
            </button>
          </div>
        </div>

        <!-- Action Widgets -->
        <div v-if="categorizedWidgets.actions.length > 0">
          <h3 class="text-sm font-medium text-muted-foreground mb-3">Actions</h3>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <button
              v-for="widget in categorizedWidgets.actions"
              :key="widget.type"
              class="flex flex-col items-start gap-2 p-4 rounded-xl border bg-card hover:bg-secondary/50 hover:border-primary/30 transition-colors text-left"
              @click="handleAdd(widget.type)"
            >
              <div class="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center">
                <component :is="getIcon(widget.icon)" class="h-5 w-5 text-primary" />
              </div>
              <div>
                <p class="font-medium text-sm">{{ widget.name }}</p>
                <p class="text-xs text-muted-foreground line-clamp-2">{{ widget.description }}</p>
              </div>
              <Badge variant="secondary" class="text-[10px]">{{ widget.defaultSize }}</Badge>
            </button>
          </div>
        </div>

        <!-- Empty state -->
        <div 
          v-if="availableWidgets.length === 0" 
          class="text-center py-8"
        >
          <div class="h-12 w-12 rounded-xl bg-secondary mx-auto mb-3 flex items-center justify-center">
            <Plus class="h-6 w-6 text-muted-foreground" />
          </div>
          <p class="font-medium">All widgets added</p>
          <p class="text-sm text-muted-foreground mt-1">You have all available widgets on your dashboard</p>
        </div>
      </div>

      <div class="border-t pt-4 flex justify-end">
        <Button variant="outline" @click="handleClose">
          Cancel
        </Button>
      </div>
    </DialogContent>
  </Dialog>
</template>

