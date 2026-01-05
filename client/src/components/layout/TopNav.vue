<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Search, LogOut, User, ChevronDown, Command, Sun, Moon, Monitor } from 'lucide-vue-next'
import { useAuthStore } from '@/stores/auth'
import { useSearchStore } from '@/stores/search'
import { useTheme } from '@/composables/useTheme'
import { Button } from '@/components/ui/button'
import CommandPalette from '@/components/shared/CommandPalette.vue'
import NotificationCenter from '@/components/layout/NotificationCenter.vue'
import PomodoroTimer from '@/components/timer/PomodoroTimer.vue'

const authStore = useAuthStore()
const searchStore = useSearchStore()
const { theme, toggleTheme } = useTheme()
const router = useRouter()
const showUserMenu = ref(false)

const handleLogout = () => {
  authStore.logout()
  router.push('/login')
}

const themeIcon = {
  light: Sun,
  dark: Moon,
  system: Monitor,
}
</script>

<template>
  <header class="h-14 border-b border-border/60 bg-background/95 backdrop-blur-sm flex items-center justify-between px-4 md:px-5 sticky top-0 z-40">
    <div class="flex items-center gap-2 sm:gap-3 flex-1 max-w-sm">
      <button 
        class="group flex items-center gap-2 sm:gap-3 flex-1 px-2.5 sm:px-3 py-2 rounded-lg bg-secondary/60 hover:bg-secondary border border-transparent hover:border-border/50 transition-all text-left"
        @click="searchStore.openSearch()"
      >
        <Search class="h-4 w-4 text-muted-foreground/60 group-hover:text-muted-foreground shrink-0" />
        <span class="text-sm text-muted-foreground/70 flex-1 truncate">Search...</span>
        <kbd class="hidden sm:inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded border border-border/50 bg-background/80 text-[10px] font-mono text-muted-foreground/60 shrink-0">
          <Command class="h-2.5 w-2.5" />K
        </kbd>
      </button>
    </div>

    <div class="flex items-center gap-1">
      <!-- Pomodoro Timer -->
      <PomodoroTimer />

      <!-- Notifications -->
      <NotificationCenter />

      <!-- Theme Toggle -->
      <Button 
        variant="ghost" 
        size="icon" 
        class="h-9 w-9 text-muted-foreground"
        :title="`Theme: ${theme}`"
        @click="toggleTheme"
      >
        <component :is="themeIcon[theme]" class="h-[18px] w-[18px]" />
      </Button>

      <!-- User Menu -->
      <div class="relative">
        <button 
          class="flex items-center gap-2.5 py-1.5 px-2 pr-3 rounded-lg hover:bg-secondary/80 transition-colors"
          @click="showUserMenu = !showUserMenu"
        >
          <img 
            v-if="authStore.user?.avatar_url" 
            :src="authStore.user.avatar_url" 
            :alt="authStore.user.name || 'User'"
            class="h-7 w-7 rounded-full ring-2 ring-border"
          />
          <div v-else class="h-7 w-7 rounded-full bg-primary/10 flex items-center justify-center">
            <User class="h-3.5 w-3.5 text-primary" />
          </div>
          <span class="text-[13px] font-medium hidden sm:block">{{ authStore.user?.name?.split(' ')[0] }}</span>
          <ChevronDown class="h-3.5 w-3.5 text-muted-foreground/60" />
        </button>

        <Transition
          enter-active-class="transition duration-100 ease-out"
          enter-from-class="opacity-0 scale-95"
          enter-to-class="opacity-100 scale-100"
          leave-active-class="transition duration-75 ease-in"
          leave-from-class="opacity-100 scale-100"
          leave-to-class="opacity-0 scale-95"
        >
          <div 
            v-if="showUserMenu" 
            class="absolute right-0 top-full mt-2 w-56 origin-top-right rounded-xl border border-border/80 bg-card shadow-lg overflow-hidden z-50"
          >
            <div class="px-4 py-3 bg-secondary/30">
              <p class="text-sm font-medium">{{ authStore.user?.name }}</p>
              <p class="text-xs text-muted-foreground truncate mt-0.5">{{ authStore.user?.email }}</p>
            </div>
            <div class="p-1.5">
              <button 
                class="w-full flex items-center gap-2.5 px-3 py-2 text-[13px] text-destructive hover:bg-destructive/10 rounded-lg transition-colors"
                @click="handleLogout"
              >
                <LogOut class="h-4 w-4" />
                Sign out
              </button>
            </div>
          </div>
        </Transition>
      </div>
    </div>

    <CommandPalette />
  </header>
</template>
