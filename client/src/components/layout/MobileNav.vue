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
  MoreHorizontal,
  X
} from 'lucide-vue-next'
import { cn } from '@/lib/utils'
import { usePreferencesStore } from '@/stores/preferences'

const route = useRoute()
const router = useRouter()
const preferencesStore = usePreferencesStore()
const showMoreMenu = ref(false)

// Icon map
const iconMap: Record<string, any> = {
  'dashboard': LayoutDashboard,
  'calendar': Calendar,
  'goals': Target,
  'habits': Flame,
  'inventory': Package,
  'shopping-list': ShoppingCart,
  'budget': DollarSign,
  'notes': FileText,
  'reports': BarChart3,
  'settings': Settings
}

// Nav items map with path and name
const navItemsMap: Record<string, { name: string; path: string; icon: any; exact?: boolean }> = {
  'dashboard': { name: 'Home', path: '/', icon: LayoutDashboard, exact: true },
  'calendar': { name: 'Calendar', path: '/calendar', icon: Calendar },
  'goals': { name: 'Goals', path: '/goals', icon: Target },
  'habits': { name: 'Habits', path: '/habits', icon: Flame },
  'inventory': { name: 'Inventory', path: '/inventory', icon: Package },
  'shopping-list': { name: 'Shopping', path: '/inventory/shopping-list', icon: ShoppingCart },
  'budget': { name: 'Budget', path: '/budget', icon: DollarSign },
  'notes': { name: 'Notes', path: '/notes', icon: FileText },
  'reports': { name: 'Reports', path: '/reports', icon: BarChart3 },
  'settings': { name: 'Settings', path: '/settings', icon: Settings }
}

// Get ordered items based on preferences, take first 4 for main nav, rest for more
const orderedItems = computed(() => {
  return preferencesStore.navOrder.map(id => navItemsMap[id]).filter(Boolean)
})

// First 4 items go in main nav
const navItems = computed(() => orderedItems.value.slice(0, 4))

// Rest go in more menu
const moreItems = computed(() => orderedItems.value.slice(4))

onMounted(() => {
  if (!preferencesStore.initialized) {
    preferencesStore.fetchPreferences()
  }
})

const isActive = (item: { path: string; exact?: boolean }) => {
  if (item.exact) return route.path === item.path
  return route.path.startsWith(item.path)
}

const isMoreActive = () => {
  return moreItems.value.some(item => route.path.startsWith(item.path))
}

const handleMoreItemClick = (path: string) => {
  showMoreMenu.value = false
  router.push(path)
}
</script>

<template>
  <nav class="fixed bottom-0 left-0 right-0 z-40 bg-card/95 backdrop-blur-lg border-t border-border/60 safe-area-bottom">
    <div class="flex items-center justify-around h-16 px-2">
      <RouterLink
        v-for="item in navItems"
        :key="item.path"
        :to="item.path"
        :class="cn(
          'flex flex-col items-center justify-center gap-0.5 flex-1 h-full transition-colors touch-manipulation',
          isActive(item) 
            ? 'text-primary' 
            : 'text-muted-foreground active:text-foreground'
        )"
      >
        <div :class="cn(
          'flex items-center justify-center w-10 h-7 rounded-full transition-colors',
          isActive(item) && 'bg-primary/15'
        )">
          <component 
            :is="item.icon" 
            :class="cn(
              'h-5 w-5', 
              isActive(item) && 'text-primary'
            )" 
          />
        </div>
        <span :class="cn(
          'text-[10px] font-medium',
          isActive(item) && 'text-primary'
        )">
          {{ item.name }}
        </span>
      </RouterLink>

      <!-- More Button -->
      <button
        :class="cn(
          'flex flex-col items-center justify-center gap-0.5 flex-1 h-full transition-colors touch-manipulation',
          isMoreActive() 
            ? 'text-primary' 
            : 'text-muted-foreground active:text-foreground'
        )"
        @click="showMoreMenu = !showMoreMenu"
      >
        <div :class="cn(
          'flex items-center justify-center w-10 h-7 rounded-full transition-colors',
          isMoreActive() && 'bg-primary/15'
        )">
          <MoreHorizontal :class="cn('h-5 w-5', isMoreActive() && 'text-primary')" />
        </div>
        <span :class="cn('text-[10px] font-medium', isMoreActive() && 'text-primary')">
          More
        </span>
      </button>
    </div>

    <!-- More Menu Popup -->
    <Transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0 translate-y-4"
      enter-to-class="opacity-100 translate-y-0"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100 translate-y-0"
      leave-to-class="opacity-0 translate-y-4"
    >
      <div 
        v-if="showMoreMenu"
        class="absolute bottom-full right-2 mb-2 w-48 bg-card border border-border rounded-xl shadow-xl overflow-hidden"
      >
        <div class="flex items-center justify-between px-3 py-2 border-b border-border">
          <span class="text-sm font-medium">More</span>
          <button 
            class="h-6 w-6 flex items-center justify-center rounded-full hover:bg-secondary"
            @click="showMoreMenu = false"
          >
            <X class="h-4 w-4" />
          </button>
        </div>
        <div class="py-1">
          <button
            v-for="item in moreItems"
            :key="item.path"
            :class="cn(
              'w-full flex items-center gap-3 px-3 py-2.5 text-sm transition-colors',
              isActive(item)
                ? 'text-primary bg-primary/10'
                : 'text-foreground hover:bg-secondary'
            )"
            @click="handleMoreItemClick(item.path)"
          >
            <component :is="item.icon" class="h-4 w-4" />
            {{ item.name }}
          </button>
        </div>
      </div>
    </Transition>

    <!-- Backdrop -->
    <Transition
      enter-active-class="transition duration-150"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div 
        v-if="showMoreMenu"
        class="fixed inset-0 -z-10"
        @click="showMoreMenu = false"
      />
    </Transition>
  </nav>
</template>

