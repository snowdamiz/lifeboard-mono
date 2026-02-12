<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { 
  Calendar, 
  Package, 
  DollarSign, 
  FileText,
  LayoutDashboard,
  ShoppingCart,
  Target,
  Flame,
  BarChart3,
  Settings,
  GripVertical,
  Tag,
  Sun,
  Moon,
  Monitor,
  LogOut,
  User,
  ChevronDown
} from 'lucide-vue-next'
import { cn } from '@/lib/utils'
import { usePreferencesStore } from '@/stores/preferences'
import { useAuthStore } from '@/stores/auth'
import { prefetchForRoute } from '@/utils/prefetch'
import { useTheme } from '@/composables/useTheme'
import PomodoroTimer from '@/components/timer/PomodoroTimer.vue'
import NotificationCenter from '@/components/layout/NotificationCenter.vue'

const { theme, toggleTheme } = useTheme()
const themeIcon = { light: Sun, dark: Moon, system: Monitor }
const authStore = useAuthStore()
const router = useRouter()
const showUserMenu = ref(false)

const handleLogout = () => {
  authStore.logout()
  router.push('/login')
}

const route = useRoute()
const preferencesStore = usePreferencesStore()

// Edit mode for reordering
const isEditMode = ref(false)
const draggedItem = ref<string | null>(null)
const dragOverItem = ref<string | null>(null)

// Base nav items definition
const navItemsMap: Record<string, { name: string; path: string; icon: any; exact?: boolean; id: string }> = {
  'dashboard': { id: 'dashboard', name: 'Dashboard', path: '/', icon: LayoutDashboard, exact: true },
  'calendar': { id: 'calendar', name: 'Calendar', path: '/calendar', icon: Calendar },
  'goals': { id: 'goals', name: 'Goals', path: '/goals', icon: Target, exact: true },
  'habits': { id: 'habits', name: 'Habits', path: '/habits', icon: Flame, exact: true },
  'tags': { id: 'tags', name: 'Tags', path: '/tags', icon: Tag, exact: true },
  'inventory': { id: 'inventory', name: 'Inventory', path: '/inventory', icon: Package, exact: true },
  'shopping-list': { id: 'shopping-list', name: 'Shopping List', path: '/inventory/shopping-list', icon: ShoppingCart },
  'budget': { id: 'budget', name: 'Budget', path: '/budget', icon: DollarSign },
  'notes': { id: 'notes', name: 'Notes', path: '/notes', icon: FileText },
  'reports': { id: 'reports', name: 'Reports', path: '/reports', icon: BarChart3, exact: true },
  'settings': { id: 'settings', name: 'Settings', path: '/settings', icon: Settings, exact: true }
}

// Ordered nav items based on preferences
const orderedNavItems = computed(() => {
  return preferencesStore.navOrder.map(id => navItemsMap[id]).filter(Boolean)
})

onMounted(() => {
  if (!preferencesStore.initialized) {
    preferencesStore.fetchPreferences()
  }
})

const isActive = (item: typeof navItemsMap.dashboard) => {
  if (item.exact) return route.path === item.path
  return route.path.startsWith(item.path)
}

// Drag and drop handlers
const handleDragStart = (e: DragEvent, itemId: string) => {
  if (!isEditMode.value) return
  draggedItem.value = itemId
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', itemId)
  }
}

const handleDragOver = (e: DragEvent, itemId: string) => {
  if (!isEditMode.value) return
  e.preventDefault()
  dragOverItem.value = itemId
}

const handleDragLeave = () => {
  dragOverItem.value = null
}

const handleDrop = async (e: DragEvent, targetId: string) => {
  if (!isEditMode.value || !draggedItem.value) return
  e.preventDefault()
  
  if (draggedItem.value === targetId) {
    draggedItem.value = null
    dragOverItem.value = null
    return
  }

  const currentOrder = [...preferencesStore.navOrder]
  const draggedIndex = currentOrder.indexOf(draggedItem.value)
  const targetIndex = currentOrder.indexOf(targetId)
  
  // Remove dragged item and insert at target position
  currentOrder.splice(draggedIndex, 1)
  currentOrder.splice(targetIndex, 0, draggedItem.value)
  
  await preferencesStore.updateNavOrder(currentOrder)
  
  draggedItem.value = null
  dragOverItem.value = null
}

const handleDragEnd = () => {
  draggedItem.value = null
  dragOverItem.value = null
}

const toggleEditMode = () => {
  isEditMode.value = !isEditMode.value
}

// Hover prefetch for nav items
let prefetchTimer: ReturnType<typeof setTimeout> | null = null
const idToRoute: Record<string, string> = {
  'dashboard': 'dashboard',
  'calendar': 'calendar',
  'goals': 'goals',
  'habits': 'habits',
  'tags': 'tags',
  'inventory': 'inventory',
  'shopping-list': 'shopping-list',
  'budget': 'budget',
  'notes': 'notes',
  'reports': 'reports',
  'settings': 'settings'
}

const schedulePrefetch = (itemId: string) => {
  if (isEditMode.value) return
  if (prefetchTimer) clearTimeout(prefetchTimer)
  prefetchTimer = setTimeout(() => {
    const routeId = idToRoute[itemId]
    if (routeId) prefetchForRoute(routeId)
  }, 80)
}

const cancelPrefetch = () => {
  if (prefetchTimer) {
    clearTimeout(prefetchTimer)
    prefetchTimer = null
  }
}
</script>

<template>
  <aside class="w-44 border-r border-border bg-card/50 hidden md:flex flex-col">
    <div class="p-3 pb-3">
      <div class="flex items-start gap-2">
        <div class="h-9 w-9 rounded-lg bg-gradient-to-br from-primary to-primary/80 flex items-center justify-center shadow-sm shadow-primary/25 shrink-0">
          <svg class="h-[18px] w-[18px] text-primary-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 2C6 8 4 12 4 15c0 4.5 3.5 7 8 7s8-2.5 8-7c0-3-2-7-8-13z"/>
            <path d="M12 22V10"/>
          </svg>
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-[15px] font-bold tracking-tight leading-[18px]">Life</div>
          <div class="text-[15px] font-bold tracking-tight leading-[18px]"><span class="text-primary">Board</span></div>
        </div>
        <!-- Edit mode toggle -->
        <button
          @click="toggleEditMode"
          :class="cn(
            'h-6 w-6 rounded-md flex items-center justify-center transition-colors shrink-0',
            isEditMode ? 'bg-primary/10 text-primary' : 'text-muted-foreground hover:bg-secondary'
          )"
          title="Reorder tabs"
        >
          <GripVertical class="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
    
    <nav class="flex-1 px-2 space-y-0.5">
      <div
        v-for="item in orderedNavItems"
        :key="item.id"
        :draggable="isEditMode"
        @dragstart="handleDragStart($event, item.id)"
        @dragover="handleDragOver($event, item.id)"
        @dragleave="handleDragLeave"
        @drop="handleDrop($event, item.id)"
        @dragend="handleDragEnd"
        :class="cn(
          'relative transition-all',
          isEditMode && 'cursor-grab active:cursor-grabbing',
          dragOverItem === item.id && draggedItem !== item.id && 'before:absolute before:inset-x-0 before:top-0 before:h-0.5 before:bg-primary before:rounded-full'
        )"
      >
        <RouterLink
          :to="isEditMode ? route.path : item.path"
          @click.prevent="isEditMode ? null : undefined"
          @pointerenter="schedulePrefetch(item.id)"
          @pointerleave="cancelPrefetch"
          :class="cn(
            'group flex items-center gap-2 px-2.5 py-2 rounded-lg text-[12px] font-medium transition-all duration-150 relative',
            isActive(item) && !isEditMode
              ? 'bg-primary/10 text-primary' 
              : 'text-muted-foreground hover:bg-secondary/80 hover:text-foreground',
            draggedItem === item.id && 'opacity-50',
            isEditMode && 'select-none'
          )"
        >
          <!-- Drag handle in edit mode -->
          <div v-if="isEditMode" class="flex items-center justify-center w-7 h-7 rounded-md bg-secondary">
            <GripVertical class="h-4 w-4 text-muted-foreground" />
          </div>
          <div v-else :class="cn(
            'flex items-center justify-center w-7 h-7 rounded-md transition-colors',
            isActive(item) 
              ? 'bg-primary/15' 
              : 'bg-secondary group-hover:bg-secondary-foreground/10'
          )">
            <component 
              :is="item.icon" 
              :class="cn(
                'h-4 w-4 transition-colors', 
                isActive(item) ? 'text-primary' : 'text-muted-foreground group-hover:text-foreground'
              )" 
            />
          </div>
          {{ item.name }}
          
          <!-- Active indicator -->
          <div 
            v-if="isActive(item) && !isEditMode"
            class="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-5 bg-primary rounded-r-full"
          />
        </RouterLink>
      </div>
    </nav>

    <!-- Edit mode indicator -->
    <div v-if="isEditMode" class="px-4 py-2 bg-primary/5 border-t border-primary/20">
      <p class="text-xs text-primary text-center">Drag to reorder tabs</p>
    </div>
    <!-- Utility buttons -->
    <div class="px-2 py-2 border-t border-border/50 flex items-center justify-center gap-1">
      <PomodoroTimer />
      <NotificationCenter />
      <button
        class="h-8 w-8 rounded-lg flex items-center justify-center text-muted-foreground hover:bg-secondary transition-colors"
        :title="`Theme: ${theme}`"
        @click="toggleTheme"
      >
        <component :is="themeIcon[theme]" class="h-4 w-4" />
      </button>
    </div>

    <!-- User Menu -->
    <div class="px-2 py-2 border-t border-border/50 relative">
      <button 
        class="w-full flex items-center gap-2 py-1.5 px-2 rounded-lg hover:bg-secondary/80 transition-colors"
        @click="showUserMenu = !showUserMenu"
      >
        <img 
          v-if="authStore.user?.avatar_url" 
          :src="authStore.user.avatar_url" 
          :alt="authStore.user.name || 'User'"
          class="h-6 w-6 rounded-full ring-2 ring-border shrink-0"
        />
        <div v-else class="h-6 w-6 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
          <User class="h-3 w-3 text-primary" />
        </div>
        <span class="text-[12px] font-medium truncate flex-1 text-left">{{ authStore.user?.name?.split(' ')[0] }}</span>
        <ChevronDown class="h-3 w-3 text-muted-foreground/60 shrink-0" />
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
          class="absolute left-2 right-2 bottom-full mb-2 origin-bottom rounded-xl border border-border/80 bg-card shadow-lg overflow-hidden z-50"
        >
          <div class="px-3 py-2 bg-secondary/30">
            <p class="text-xs font-medium">{{ authStore.user?.name }}</p>
            <p class="text-[10px] text-muted-foreground truncate mt-0.5">{{ authStore.user?.email }}</p>
          </div>
          <div class="p-1">
            <button 
              class="w-full flex items-center gap-2 px-2.5 py-1.5 text-[11px] text-destructive hover:bg-destructive/10 rounded-lg transition-colors"
              @click="handleLogout"
            >
              <LogOut class="h-3.5 w-3.5" />
              Sign out
            </button>
          </div>
        </div>
      </Transition>
    </div>

    <div class="px-3 py-1.5 border-t border-border/50">
      <div class="flex items-center justify-between text-[10px] text-muted-foreground/60">
        <span>LifeBoard</span>
        <span class="font-mono">v0.1.0</span>
      </div>
    </div>
  </aside>
</template>
