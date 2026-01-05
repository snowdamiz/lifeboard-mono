import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { User } from '@/types'
import { api } from '@/services/api'

export const useAuthStore = defineStore('auth', () => {
  // Legacy support: migrate old 'token' key immediately on store init
  const oldToken = localStorage.getItem('token')
  if (oldToken && !localStorage.getItem('access_token')) {
    localStorage.setItem('access_token', oldToken)
    localStorage.removeItem('token')
  }

  const user = ref<User | null>(null)
  const accessToken = ref<string | null>(localStorage.getItem('access_token'))
  const refreshToken = ref<string | null>(localStorage.getItem('refresh_token'))
  const loading = ref(false)
  const initialized = ref(false)
  let checkAuthPromise: Promise<void> | null = null

  // Check if we have tokens (for initial route guard before checkAuth completes)
  const hasTokens = computed(() => !!accessToken.value)
  const isAuthenticated = computed(() => !!accessToken.value && !!user.value)

  async function checkAuth() {
    // Prevent concurrent checkAuth calls - return existing promise if already running
    if (checkAuthPromise) {
      return checkAuthPromise
    }

    if (!accessToken.value) {
      initialized.value = true
      return
    }

    api.setTokens(accessToken.value, refreshToken.value)
    loading.value = true

    checkAuthPromise = (async () => {
      try {
        const response = await api.me()
        user.value = response.data
        // Fetch household data and received invitations after successful auth
        // Import dynamically to avoid circular dependency
        const { useHouseholdStore } = await import('./household')
        const householdStore = useHouseholdStore()
        await Promise.all([
          householdStore.fetchHousehold(),
          householdStore.fetchReceivedInvitations()
        ])
      } catch {
        // If me() fails and we have a refresh token, the API client will try to refresh
        // If that also fails, we need to logout
        if (!api.getAccessToken()) {
          logout()
        } else {
          // Token was refreshed, try again
          try {
            const response = await api.me()
            user.value = response.data
            // Fetch household data and received invitations after successful auth
            const { useHouseholdStore } = await import('./household')
            const householdStore = useHouseholdStore()
            await Promise.all([
              householdStore.fetchHousehold(),
              householdStore.fetchReceivedInvitations()
            ])
          } catch {
            logout()
          }
        }
      } finally {
        loading.value = false
        initialized.value = true
        checkAuthPromise = null
      }
    })()

    return checkAuthPromise
  }

  function setTokens(newAccessToken: string, newRefreshToken: string) {
    accessToken.value = newAccessToken
    refreshToken.value = newRefreshToken
    localStorage.setItem('access_token', newAccessToken)
    localStorage.setItem('refresh_token', newRefreshToken)
    api.setTokens(newAccessToken, newRefreshToken)
  }

  function updateAccessToken(newAccessToken: string) {
    accessToken.value = newAccessToken
    localStorage.setItem('access_token', newAccessToken)
    api.updateAccessToken(newAccessToken)
  }

  function logout() {
    user.value = null
    accessToken.value = null
    refreshToken.value = null
    localStorage.removeItem('access_token')
    localStorage.removeItem('refresh_token')
    localStorage.removeItem('token') // Clean up old key too
    api.setTokens(null, null)
    // Reset household store - import dynamically to avoid circular dependency
    import('./household').then(({ useHouseholdStore }) => {
      const householdStore = useHouseholdStore()
      householdStore.$reset()
    })
  }

  // Expose updateAccessToken for API client to call after refresh
  api.onTokenRefresh = updateAccessToken

  return {
    user,
    accessToken,
    refreshToken,
    loading,
    initialized,
    hasTokens,
    isAuthenticated,
    checkAuth,
    setTokens,
    updateAccessToken,
    logout
  }
})

