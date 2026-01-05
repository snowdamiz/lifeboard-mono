<script setup lang="ts">
import { Sun, Moon, Monitor } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardHeader, CardDescription, CardContent } from '@/components/ui/card'
import { useTheme } from '@/composables/useTheme'

const { theme, toggleTheme } = useTheme()

// Backend URL for OAuth (full page redirect, can't use Vite proxy)
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4000'

const loginWithGoogle = () => {
  window.location.href = `${API_URL}/auth/google`
}

const themeIcon = {
  light: Sun,
  dark: Moon,
  system: Monitor,
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-background p-4 relative overflow-hidden">
    <!-- Subtle gradient background -->
    <div class="absolute inset-0 bg-gradient-to-br from-primary/[0.03] via-transparent to-primary/[0.02]" />
    
    <!-- Decorative shapes -->
    <div class="absolute top-1/4 left-1/4 w-96 h-96 bg-primary/5 rounded-full blur-3xl" />
    <div class="absolute bottom-1/4 right-1/4 w-80 h-80 bg-primary/3 rounded-full blur-3xl" />
    
    <Card class="w-full max-w-sm relative z-10 animate-slide-up border-border/60 shadow-xl bg-card/95 backdrop-blur-sm">
      <CardHeader class="text-center space-y-5 pb-0 pt-8">
        <!-- Logo -->
        <div class="flex items-center justify-center">
          <div class="h-14 w-14 rounded-2xl bg-gradient-to-br from-primary to-primary/80 flex items-center justify-center shadow-lg shadow-primary/20">
            <svg class="h-7 w-7 text-primary-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 2C6 8 4 12 4 15c0 4.5 3.5 7 8 7s8-2.5 8-7c0-3-2-7-8-13z"/>
              <path d="M12 22V10"/>
            </svg>
          </div>
        </div>
        
        <!-- Title -->
        <div class="space-y-2">
          <h1 class="text-2xl font-semibold tracking-tight">
            Life<span class="text-primary">Board</span>
          </h1>
          <CardDescription class="text-sm">
            Your personal life management system
          </CardDescription>
        </div>
      </CardHeader>
      
      <CardContent class="space-y-5 pt-8 pb-8">
        <Button 
          variant="outline" 
          class="w-full h-11 text-[15px] gap-3 bg-background hover:bg-secondary border-border/80"
          @click="loginWithGoogle"
        >
          <svg class="h-5 w-5 shrink-0" viewBox="0 0 24 24">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
          Continue with Google
        </Button>

        <p class="text-[11px] text-center text-muted-foreground/70 leading-relaxed">
          By continuing, you agree to our Terms of Service and Privacy Policy.
        </p>
      </CardContent>
    </Card>
    
    <!-- Theme Toggle -->
    <Button 
      variant="ghost" 
      size="icon" 
      class="absolute top-4 right-4 h-9 w-9 text-muted-foreground/60 hover:text-muted-foreground"
      :title="`Theme: ${theme}`"
      @click="toggleTheme"
    >
      <component :is="themeIcon[theme]" class="h-[18px] w-[18px]" />
    </Button>
    
    <!-- Footer -->
    <div class="absolute bottom-6 left-1/2 -translate-x-1/2 text-[11px] text-muted-foreground/50">
      LifeBoard v0.3.0
    </div>
  </div>
</template>
