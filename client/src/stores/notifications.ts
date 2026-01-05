import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Notification, NotificationPreferences } from '@/types'
import { api } from '@/services/api'

export const useNotificationsStore = defineStore('notifications', () => {
  const notifications = ref<Notification[]>([])
  const unreadCount = ref(0)
  const preferences = ref<NotificationPreferences | null>(null)
  const loading = ref(false)
  const isOpen = ref(false)

  const unreadNotifications = computed(() => 
    notifications.value.filter(n => !n.read)
  )

  async function fetchNotifications(unreadOnly = false) {
    loading.value = true
    try {
      const response = await api.listNotifications({ unread_only: unreadOnly, limit: 50 })
      notifications.value = response.data
      unreadCount.value = response.unread_count
    } finally {
      loading.value = false
    }
  }

  async function fetchUnreadCount() {
    const response = await api.getUnreadNotificationCount()
    unreadCount.value = response.count
  }

  async function markAsRead(id: string) {
    const response = await api.markNotificationRead(id)
    const index = notifications.value.findIndex(n => n.id === id)
    if (index !== -1) {
      notifications.value[index] = response.data
    }
    if (unreadCount.value > 0) {
      unreadCount.value--
    }
  }

  async function markAllAsRead() {
    await api.markAllNotificationsRead()
    notifications.value = notifications.value.map(n => ({ ...n, read: true }))
    unreadCount.value = 0
  }

  async function deleteNotification(id: string) {
    const notification = notifications.value.find(n => n.id === id)
    await api.deleteNotification(id)
    notifications.value = notifications.value.filter(n => n.id !== id)
    if (notification && !notification.read && unreadCount.value > 0) {
      unreadCount.value--
    }
  }

  async function fetchPreferences() {
    const response = await api.getNotificationPreferences()
    preferences.value = response.data
  }

  async function updatePreferences(updates: Partial<NotificationPreferences>) {
    const response = await api.updateNotificationPreferences(updates)
    preferences.value = response.data
  }

  function openPanel() {
    isOpen.value = true
  }

  function closePanel() {
    isOpen.value = false
  }

  function togglePanel() {
    isOpen.value = !isOpen.value
  }

  // Add a local notification (for immediate feedback)
  function addLocalNotification(notification: Omit<Notification, 'id' | 'inserted_at'>) {
    const newNotification: Notification = {
      ...notification,
      id: `local-${Date.now()}`,
      inserted_at: new Date().toISOString()
    }
    notifications.value.unshift(newNotification)
    if (!notification.read) {
      unreadCount.value++
    }
  }

  return {
    notifications,
    unreadCount,
    preferences,
    loading,
    isOpen,
    unreadNotifications,
    fetchNotifications,
    fetchUnreadCount,
    markAsRead,
    markAllAsRead,
    deleteNotification,
    fetchPreferences,
    updatePreferences,
    openPanel,
    closePanel,
    togglePanel,
    addLocalNotification
  }
})

