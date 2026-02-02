<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { formatDistanceToNow } from 'date-fns'
import { 
  Bell, X, Check, CheckCheck, Calendar, Package, 
  DollarSign, Flame, Settings, ChevronRight, Users, UserPlus
} from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { useNotificationsStore } from '@/stores/notifications'
import { useHouseholdStore } from '@/stores/household'
import { useAuthStore } from '@/stores/auth'
import DeleteButton from '@/components/shared/DeleteButton.vue'
import type { Notification } from '@/types'

const router = useRouter()
const notificationsStore = useNotificationsStore()
const householdStore = useHouseholdStore()
const authStore = useAuthStore()

const showSettings = ref(false)
const acceptingInviteId = ref<string | null>(null)
const decliningInviteId = ref<string | null>(null)

onMounted(async () => {
  await notificationsStore.fetchNotifications()
  await notificationsStore.fetchPreferences()
  await householdStore.fetchReceivedInvitations()
})

// Combined count of unread notifications + pending invitations
const totalUnreadCount = computed(() => {
  return notificationsStore.unreadCount + householdStore.receivedInvitations.length
})

// Poll for new notifications every 60 seconds
const pollInterval = ref<number | null>(null)

onMounted(() => {
  pollInterval.value = window.setInterval(() => {
    notificationsStore.fetchUnreadCount()
  }, 60000)
})

const getIcon = (type: string) => {
  switch (type) {
    case 'task_due': return Calendar
    case 'low_inventory': return Package
    case 'budget_warning': return DollarSign
    case 'habit_reminder': return Flame
    default: return Bell
  }
}

const getIconColor = (type: string) => {
  switch (type) {
    case 'task_due': return 'bg-blue-500/10 text-blue-600'
    case 'low_inventory': return 'bg-amber-500/10 text-amber-600'
    case 'budget_warning': return 'bg-red-500/10 text-red-600'
    case 'habit_reminder': return 'bg-orange-500/10 text-orange-600'
    default: return 'bg-muted text-muted-foreground'
  }
}

const handleNotificationClick = async (notification: Notification) => {
  // Mark as read
  if (!notification.read) {
    await notificationsStore.markAsRead(notification.id)
  }
  
  // Navigate if there's a link
  if (notification.link_type && notification.link_id) {
    notificationsStore.closePanel()
    switch (notification.link_type) {
      case 'task':
        router.push('/calendar')
        break
      case 'inventory_item':
        router.push('/inventory')
        break
      case 'budget_entry':
        router.push('/budget')
        break
      case 'habit':
        router.push('/habits')
        break
      case 'page':
        router.push(`/notes/page/${notification.link_id}`)
        break
    }
  }
}

const handleMarkAllRead = async () => {
  await notificationsStore.markAllAsRead()
}

const handleDelete = async (id: string, e: Event) => {
  e.stopPropagation()
  await notificationsStore.deleteNotification(id)
}

const handleUpdatePreference = async (key: string, value: boolean | number) => {
  if (!notificationsStore.preferences) return
  await notificationsStore.updatePreferences({ [key]: value })
}

// Invitation handlers
const handleAcceptInvitation = async (id: string) => {
  acceptingInviteId.value = id
  try {
    await householdStore.acceptInvitation(id)
    // Refresh auth to get new household data
    await authStore.checkAuth()
    notificationsStore.closePanel()
  } catch (err) {
    console.error('Failed to accept invitation:', err)
  } finally {
    acceptingInviteId.value = null
  }
}

const handleDeclineInvitation = async (id: string) => {
  decliningInviteId.value = id
  try {
    await householdStore.declineInvitation(id)
  } catch (err) {
    console.error('Failed to decline invitation:', err)
  } finally {
    decliningInviteId.value = null
  }
}
</script>

<template>
  <!-- Bell Button -->
  <div class="relative">
    <Button 
      variant="ghost" 
      size="icon" 
      class="h-9 w-9 text-muted-foreground relative"
      @click="notificationsStore.togglePanel"
    >
      <Bell class="h-[18px] w-[18px]" />
      <span 
        v-if="totalUnreadCount > 0"
        class="absolute -top-0.5 -right-0.5 h-4 w-4 rounded-full bg-destructive text-destructive-foreground text-[10px] font-bold flex items-center justify-center"
      >
        {{ totalUnreadCount > 9 ? '9+' : totalUnreadCount }}
      </span>
    </Button>
  </div>

  <!-- Notification Panel -->
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div 
        v-if="notificationsStore.isOpen"
        class="fixed inset-0 bg-background/40 backdrop-blur-sm z-50"
        @click="notificationsStore.closePanel"
      />
    </Transition>

    <Transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0 translate-x-full"
      enter-to-class="opacity-100 translate-x-0"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100 translate-x-0"
      leave-to-class="opacity-0 translate-x-full"
    >
      <div 
        v-if="notificationsStore.isOpen"
        class="fixed right-0 top-0 bottom-0 w-full max-w-md bg-card border-l border-border shadow-xl z-50 flex flex-col"
      >
        <!-- Header -->
        <div class="flex items-center justify-between px-4 py-3 border-b border-border">
          <div class="flex items-center gap-2">
            <Bell class="h-5 w-5 text-primary" />
            <h2 class="font-semibold">Notifications</h2>
            <span 
              v-if="totalUnreadCount > 0"
              class="px-1.5 py-0.5 rounded-full bg-primary/10 text-primary text-xs font-medium"
            >
              {{ totalUnreadCount }} new
            </span>
          </div>
          <div class="flex items-center gap-1">
            <Button 
              v-if="notificationsStore.unreadCount > 0"
              variant="ghost" 
              size="sm"
              class="text-xs h-8"
              @click="handleMarkAllRead"
            >
              <CheckCheck class="h-3.5 w-3.5 mr-1" />
              Mark all read
            </Button>
            <Button 
              variant="ghost" 
              size="icon"
              class="h-8 w-8"
              @click="showSettings = !showSettings"
            >
              <Settings class="h-4 w-4" />
            </Button>
            <Button 
              variant="ghost" 
              size="icon"
              class="h-8 w-8"
              @click="notificationsStore.closePanel"
            >
              <X class="h-4 w-4" />
            </Button>
          </div>
        </div>

        <!-- Settings Panel -->
        <Transition
          enter-active-class="transition duration-150 ease-out"
          enter-from-class="opacity-0 -translate-y-2"
          enter-to-class="opacity-100 translate-y-0"
          leave-active-class="transition duration-100 ease-in"
          leave-from-class="opacity-100 translate-y-0"
          leave-to-class="opacity-0 -translate-y-2"
        >
          <div v-if="showSettings && notificationsStore.preferences" class="border-b border-border bg-secondary/30 p-4">
            <h3 class="text-sm font-medium mb-3">Notification Settings</h3>
            <div class="space-y-3">
              <label class="flex items-center justify-between">
                <span class="text-sm">Task due reminders</span>
                <input 
                  type="checkbox" 
                  :checked="notificationsStore.preferences.task_due_enabled"
                  class="rounded border-input"
                  @change="handleUpdatePreference('task_due_enabled', !notificationsStore.preferences.task_due_enabled)"
                />
              </label>
              <label class="flex items-center justify-between">
                <span class="text-sm">Low inventory alerts</span>
                <input 
                  type="checkbox" 
                  :checked="notificationsStore.preferences.low_inventory_enabled"
                  class="rounded border-input"
                  @change="handleUpdatePreference('low_inventory_enabled', !notificationsStore.preferences.low_inventory_enabled)"
                />
              </label>
              <label class="flex items-center justify-between">
                <span class="text-sm">Budget warnings</span>
                <input 
                  type="checkbox" 
                  :checked="notificationsStore.preferences.budget_threshold_enabled"
                  class="rounded border-input"
                  @change="handleUpdatePreference('budget_threshold_enabled', !notificationsStore.preferences.budget_threshold_enabled)"
                />
              </label>
              <label class="flex items-center justify-between">
                <span class="text-sm">Habit reminders</span>
                <input 
                  type="checkbox" 
                  :checked="notificationsStore.preferences.habit_reminder_enabled"
                  class="rounded border-input"
                  @change="handleUpdatePreference('habit_reminder_enabled', !notificationsStore.preferences.habit_reminder_enabled)"
                />
              </label>
            </div>
          </div>
        </Transition>

        <!-- Notifications List -->
        <div class="flex-1 overflow-auto">
          <!-- Pending Invitations -->
          <div v-if="householdStore.receivedInvitations.length > 0" class="border-b border-border">
            <div class="px-4 py-2 bg-emerald-500/5">
              <div class="flex items-center gap-2 text-emerald-600 dark:text-emerald-400">
                <UserPlus class="h-4 w-4" />
                <span class="text-xs font-medium">Household Invitations</span>
              </div>
            </div>
            <div class="divide-y divide-border">
              <div
                v-for="invitation in householdStore.receivedInvitations"
                :key="invitation.id"
                class="px-4 py-3 bg-emerald-500/5"
              >
                <div class="flex gap-3">
                  <div class="h-9 w-9 rounded-lg bg-emerald-500/10 flex items-center justify-center shrink-0">
                    <Users class="h-4 w-4 text-emerald-600" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium">
                      Join {{ invitation.household?.name || 'a household' }}
                    </p>
                    <p class="text-xs text-muted-foreground mt-0.5">
                      Invited by {{ invitation.inviter?.name || invitation.inviter?.email || 'someone' }}
                    </p>
                    <div class="flex items-center gap-2 mt-2">
                      <Button
                        size="sm"
                        class="h-7 text-xs"
                        :disabled="acceptingInviteId === invitation.id"
                        @click="handleAcceptInvitation(invitation.id)"
                      >
                        <Check class="h-3 w-3 mr-1" />
                        {{ acceptingInviteId === invitation.id ? 'Accepting...' : 'Accept' }}
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        class="h-7 text-xs"
                        :disabled="decliningInviteId === invitation.id"
                        @click="handleDeclineInvitation(invitation.id)"
                      >
                        <X class="h-3 w-3 mr-1" />
                        Decline
                      </Button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div v-if="notificationsStore.loading" class="flex items-center justify-center py-12">
            <div class="h-5 w-5 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
          </div>

          <div v-else-if="notificationsStore.notifications.length === 0 && householdStore.receivedInvitations.length === 0" class="flex flex-col items-center justify-center py-16 px-4">
            <div class="h-14 w-14 rounded-2xl bg-muted/50 flex items-center justify-center mb-3">
              <Bell class="h-7 w-7 text-muted-foreground/50" />
            </div>
            <p class="font-medium">All caught up!</p>
            <p class="text-sm text-muted-foreground mt-1">No notifications to show</p>
          </div>

          <div v-else-if="notificationsStore.notifications.length > 0" class="divide-y divide-border">
            <button
              v-for="notification in notificationsStore.notifications"
              :key="notification.id"
              :class="[
                'w-full text-left px-4 py-3 hover:bg-secondary/50 transition-colors group',
                !notification.read && 'bg-primary/5'
              ]"
              @click="handleNotificationClick(notification)"
            >
              <div class="flex gap-3">
                <div :class="['h-9 w-9 rounded-lg flex items-center justify-center shrink-0', getIconColor(notification.type)]">
                  <component :is="getIcon(notification.type)" class="h-4 w-4" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-start justify-between gap-2">
                    <p :class="['text-sm font-medium', !notification.read && 'text-foreground']">
                      {{ notification.title }}
                    </p>
                    <DeleteButton 
                      class="opacity-0 group-hover:opacity-100"
                      @click="handleDelete(notification.id, $event)"
                    />
                  </div>
                  <p v-if="notification.message" class="text-xs text-muted-foreground mt-0.5 line-clamp-2">
                    {{ notification.message }}
                  </p>
                  <div class="flex items-center gap-2 mt-1.5">
                    <span class="text-[10px] text-muted-foreground/70">
                      {{ formatDistanceToNow(new Date(notification.inserted_at), { addSuffix: true }) }}
                    </span>
                    <span v-if="!notification.read" class="h-1.5 w-1.5 rounded-full bg-primary" />
                    <ChevronRight v-if="notification.link_type" class="h-3 w-3 text-muted-foreground/50 ml-auto" />
                  </div>
                </div>
              </div>
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

