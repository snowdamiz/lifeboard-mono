import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/auth/LoginView.vue'),
      meta: { public: true }
    },
    {
      path: '/auth/callback',
      name: 'auth-callback',
      component: () => import('@/views/auth/CallbackView.vue'),
      meta: { public: true }
    },
    {
      path: '/',
      component: () => import('@/components/layout/AppShell.vue'),
      children: [
        {
          path: '',
          name: 'dashboard',
          component: () => import('@/views/DashboardView.vue')
        },
        {
          path: 'calendar',
          name: 'calendar',
          component: () => import('@/views/calendar/CalendarView.vue')
        },
        {
          path: 'calendar/day/:date?',
          name: 'calendar-day',
          component: () => import('@/views/calendar/DayView.vue')
        },
        {
          path: 'inventory',
          name: 'inventory',
          component: () => import('@/views/inventory/InventoryView.vue')
        },
        {
          path: 'inventory/sheet/:id',
          name: 'inventory-sheet',
          component: () => import('@/views/inventory/SheetView.vue')
        },
        {
          path: 'inventory/shopping-list',
          name: 'shopping-list',
          component: () => import('@/views/inventory/ShoppingListView.vue')
        },
        {
          path: 'budget',
          name: 'budget',
          component: () => import('@/views/budget/BudgetView.vue')
        },
        {
          path: 'budget/sources',
          name: 'budget-sources',
          component: () => import('@/views/budget/SourcesView.vue')
        },
        {
          path: 'notes',
          name: 'notes',
          component: () => import('@/views/notes/NotebooksView.vue')
        },
        {
          path: 'notes/page/:id',
          name: 'page',
          component: () => import('@/views/notes/PageView.vue')
        },
        {
          path: 'goals',
          name: 'goals',
          component: () => import('@/views/goals/GoalsView.vue')
        },
        {
          path: 'goals/:id',
          name: 'goal-detail',
          component: () => import('@/views/goals/GoalDetailView.vue')
        },
        {
          path: 'goals/:id/history',
          name: 'goal-history',
          component: () => import('@/views/goals/GoalHistoryView.vue')
        },
        {
          path: 'habits',
          name: 'habits',
          component: () => import('@/views/goals/HabitsView.vue')
        },
        {
          path: 'reports',
          name: 'reports',
          component: () => import('@/views/reports/ReportsView.vue')
        },
        {
          path: 'settings',
          name: 'settings',
          component: () => import('@/views/settings/SettingsView.vue')
        }
      ]
    }
  ]
})

router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()
  
  if (to.meta.public) {
    next()
    return
  }
  
  // Wait for auth to initialize if we have tokens but haven't checked them yet
  if (!authStore.initialized && authStore.hasTokens) {
    await authStore.checkAuth()
  }
  
  if (!authStore.isAuthenticated) {
    next({ name: 'login' })
    return
  }
  
  next()
})

export default router

