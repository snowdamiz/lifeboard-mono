<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Bell, ChevronRight, CheckCheck, AlertCircle, Calendar, Package } from 'lucide-vue-next'
import { formatDistanceToNow } from 'date-fns'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { useNotificationsStore } from '@/stores/notifications'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const notificationsStore = useNotificationsStore()

const recentNotifications = computed(() => 
  notificationsStore.notifications.slice(0, 5)
)

const getIcon = (type: string) => {
  switch (type) {
    case 'task_due': return Calendar
    case 'low_inventory': return Package
    default: return AlertCircle
  }
}

onMounted(() => {
  if (notificationsStore.notifications.length === 0) {
    notificationsStore.fetchNotifications()
  }
})
</script>

<template>
  <div class="h-full flex flex-col">
    <CardHeader class="flex flex-row items-center justify-between pb-2 sm:pb-3 p-3 sm:p-4">
      <CardTitle class="text-sm sm:text-base font-medium flex items-center gap-2">
        <Bell class="h-4 w-4 text-rose-500" />
        Notifications
        <Badge v-if="notificationsStore.unreadCount > 0" variant="destructive" class="text-[10px] px-1.5">
          {{ notificationsStore.unreadCount }}
        </Badge>
      </CardTitle>
      <Button 
        v-if="notificationsStore.unreadCount > 0"
        variant="ghost" 
        size="sm" 
        class="text-muted-foreground hover:text-foreground -mr-2 h-8 px-2 sm:px-3" 
        @click="!isEditMode && notificationsStore.markAllAsRead()"
      >
        <CheckCheck class="h-4 w-4" />
      </Button>
    </CardHeader>
    <CardContent class="pt-0 p-3 sm:p-4 sm:pt-0 flex-1 overflow-auto">
      <div v-if="recentNotifications.length === 0" class="text-center py-4">
        <div class="h-10 w-10 rounded-xl bg-rose-500/10 mx-auto mb-2 flex items-center justify-center">
          <Bell class="h-5 w-5 text-rose-500/60" />
        </div>
        <p class="font-medium text-foreground text-sm">All caught up!</p>
        <p class="text-xs text-muted-foreground mt-0.5">No notifications</p>
      </div>
      <div v-else class="space-y-1">
        <div
          v-for="notification in recentNotifications"
          :key="notification.id"
          :class="[
            'flex items-start gap-3 p-2.5 rounded-lg transition-colors cursor-pointer',
            notification.read ? 'opacity-60' : 'bg-rose-500/5 hover:bg-rose-500/10'
          ]"
          @click="!isEditMode && notificationsStore.markAsRead(notification.id)"
        >
          <div :class="[
            'h-8 w-8 rounded-lg flex items-center justify-center shrink-0',
            notification.read ? 'bg-secondary' : 'bg-rose-500/10'
          ]">
            <component :is="getIcon(notification.type)" :class="['h-4 w-4', notification.read ? 'text-muted-foreground' : 'text-rose-600']" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium truncate">{{ notification.title }}</p>
            <p class="text-[10px] text-muted-foreground truncate">
              {{ formatDistanceToNow(new Date(notification.inserted_at), { addSuffix: true }) }}
            </p>
          </div>
          <div v-if="!notification.read" class="w-2 h-2 rounded-full bg-rose-500 shrink-0 mt-2" />
        </div>
      </div>
    </CardContent>
  </div>
</template>

