<script setup lang="ts">
import { onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

onMounted(async () => {
  const accessToken = route.query.access_token as string
  const refreshToken = route.query.refresh_token as string
  
  // Also support legacy single token for backwards compatibility
  const legacyToken = route.query.token as string
  
  if (accessToken && refreshToken) {
    authStore.setTokens(accessToken, refreshToken)
    await authStore.checkAuth()
    // Check for pending invite redirect
    const pendingInvite = localStorage.getItem('pendingInvite')
    if (pendingInvite) {
      localStorage.removeItem('pendingInvite')
      router.push(pendingInvite)
    } else {
      router.push('/')
    }
  } else if (legacyToken) {
    // Legacy support - will require re-login when token expires
    authStore.setTokens(legacyToken, '')
    await authStore.checkAuth()
    const pendingInvite = localStorage.getItem('pendingInvite')
    if (pendingInvite) {
      localStorage.removeItem('pendingInvite')
      router.push(pendingInvite)
    } else {
      router.push('/')
    }
  } else {
    router.push('/login')
  }
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-background">
    <div class="text-center space-y-4">
      <div class="h-12 w-12 rounded-2xl bg-primary flex items-center justify-center mx-auto">
        <svg class="h-6 w-6 text-primary-foreground animate-pulse" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 2C6 8 4 12 4 15c0 4.5 3.5 7 8 7s8-2.5 8-7c0-3-2-7-8-13z"/>
          <path d="M12 22V10"/>
        </svg>
      </div>
      <div class="h-8 w-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto"></div>
      <p class="text-sm text-muted-foreground">Completing sign in...</p>
    </div>
  </div>
</template>
