<script setup lang="ts">
import { ref, watch, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { 
  Search, X, Calendar, Package, DollarSign, FileText, ArrowRight,
  Plus, Home, BookOpen, ShoppingCart, Target, Zap, Command as CommandIcon
} from 'lucide-vue-next'
import { useSearchStore } from '@/stores/search'
import { useCalendarStore } from '@/stores/calendar'
import { useBudgetStore } from '@/stores/budget'
import { debounce, formatCurrency } from '@/lib/utils'
import { format, addDays, parse, isValid } from 'date-fns'

const searchStore = useSearchStore()
const calendarStore = useCalendarStore()
const budgetStore = useBudgetStore()
const router = useRouter()

const inputValue = ref('')
const inputRef = ref<HTMLInputElement | null>(null)
const selectedIndex = ref(0)
const mode = ref<'search' | 'command'>('search')
const isCreating = ref(false)
const successMessage = ref('')

// Quick commands
const quickCommands = [
  { id: 'nav-dashboard', label: 'Go to Dashboard', icon: Home, action: () => router.push('/'), category: 'navigation' },
  { id: 'nav-calendar', label: 'Go to Calendar', icon: Calendar, action: () => router.push('/calendar'), category: 'navigation' },
  { id: 'nav-inventory', label: 'Go to Inventory', icon: Package, action: () => router.push('/inventory'), category: 'navigation' },
  { id: 'nav-budget', label: 'Go to Budget', icon: DollarSign, action: () => router.push('/budget'), category: 'navigation' },
  { id: 'nav-notes', label: 'Go to Notes', icon: BookOpen, action: () => router.push('/notes'), category: 'navigation' },
  { id: 'nav-shopping', label: 'Go to Shopping List', icon: ShoppingCart, action: () => router.push('/inventory/shopping-list'), category: 'navigation' },
  { id: 'nav-goals', label: 'Go to Goals', icon: Target, action: () => router.push('/goals'), category: 'navigation' },
]

// Parse quick-add commands
const parseQuickAdd = (input: string) => {
  const trimmed = input.trim()
  
  // Task: "task Buy groceries tomorrow" or "/t Buy groceries tomorrow"
  const taskMatch = trimmed.match(/^(?:\/t(?:ask)?|task)\s+(.+)$/i)
  if (taskMatch) {
    return { type: 'task' as const, content: taskMatch[1] }
  }
  
  // Expense: "expense $50 lunch" or "/e $50 lunch"
  const expenseMatch = trimmed.match(/^(?:\/e(?:xpense)?|expense)\s+\$?(\d+(?:\.\d{2})?)\s*(.*)$/i)
  if (expenseMatch) {
    return { type: 'expense' as const, amount: parseFloat(expenseMatch[1]), notes: expenseMatch[2] || null }
  }
  
  // Income: "income $1000 salary" or "/i $1000 salary"
  const incomeMatch = trimmed.match(/^(?:\/i(?:ncome)?|income)\s+\$?(\d+(?:\.\d{2})?)\s*(.*)$/i)
  if (incomeMatch) {
    return { type: 'income' as const, amount: parseFloat(incomeMatch[1]), notes: incomeMatch[2] || null }
  }
  
  return null
}

// Parse date from task content
const parseDateFromContent = (content: string) => {
  const today = new Date()
  let date = format(today, 'yyyy-MM-dd')
  let title = content
  
  // Check for "tomorrow"
  if (/\btomorrow\b/i.test(content)) {
    date = format(addDays(today, 1), 'yyyy-MM-dd')
    title = content.replace(/\s*\btomorrow\b\s*/i, ' ').trim()
  }
  // Check for "today"
  else if (/\btoday\b/i.test(content)) {
    date = format(today, 'yyyy-MM-dd')
    title = content.replace(/\s*\btoday\b\s*/i, ' ').trim()
  }
  // Check for day names (next monday, tuesday, etc.)
  else {
    const dayMatch = content.match(/\b(?:next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i)
    if (dayMatch) {
      const targetDay = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday']
        .indexOf(dayMatch[1].toLowerCase())
      let daysToAdd = targetDay - today.getDay()
      if (daysToAdd <= 0) daysToAdd += 7
      if (dayMatch[0].toLowerCase().startsWith('next')) daysToAdd += 7
      date = format(addDays(today, daysToAdd), 'yyyy-MM-dd')
      title = content.replace(new RegExp(`\\s*\\b${dayMatch[0]}\\b\\s*`, 'i'), ' ').trim()
    }
  }
  
  return { date, title }
}

const quickAddPreview = computed(() => {
  const parsed = parseQuickAdd(inputValue.value)
  if (!parsed) return null
  
  if (parsed.type === 'task') {
    const { date, title } = parseDateFromContent(parsed.content)
    return {
      type: 'task',
      title,
      date,
      displayDate: format(new Date(date), 'EEE, MMM d')
    }
  }
  
  if (parsed.type === 'expense' || parsed.type === 'income') {
    return {
      type: parsed.type,
      amount: parsed.amount,
      notes: parsed.notes,
      displayAmount: formatCurrency(parsed.amount)
    }
  }
  
  return null
})

// Filter commands based on input
const filteredCommands = computed(() => {
  if (!inputValue.value.trim() || quickAddPreview.value) return []
  
  const query = inputValue.value.toLowerCase()
  return quickCommands.filter(cmd => 
    cmd.label.toLowerCase().includes(query)
  )
})

const debouncedSearch = debounce((query: string) => {
  if (!parseQuickAdd(query)) {
    searchStore.search(query)
  }
}, 300)

watch(inputValue, (value) => {
  selectedIndex.value = 0
  if (parseQuickAdd(value)) {
    mode.value = 'command'
  } else {
    mode.value = 'search'
    debouncedSearch(value)
  }
})

// Handle keyboard shortcuts
const handleKeydown = (e: KeyboardEvent) => {
  if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
    e.preventDefault()
    searchStore.openSearch()
  }
  if (e.key === 'Escape' && searchStore.isOpen) {
    close()
  }
}

// Handle keyboard navigation in palette
const handlePaletteKeydown = (e: KeyboardEvent) => {
  const totalItems = getTotalItems()
  
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    selectedIndex.value = (selectedIndex.value + 1) % Math.max(totalItems, 1)
  } else if (e.key === 'ArrowUp') {
    e.preventDefault()
    selectedIndex.value = (selectedIndex.value - 1 + totalItems) % Math.max(totalItems, 1)
  } else if (e.key === 'Enter') {
    e.preventDefault()
    handleEnter()
  }
}

const getTotalItems = () => {
  if (quickAddPreview.value) return 1
  if (filteredCommands.value.length) return filteredCommands.value.length
  if (searchStore.results) {
    return (
      searchStore.results.tasks.length +
      searchStore.results.inventory_items.length +
      searchStore.results.budget_sources.length +
      searchStore.results.pages.length +
      (searchStore.results.goals?.length || 0) +
      (searchStore.results.habits?.length || 0)
    )
  }
  return 0
}

const handleEnter = async () => {
  // Quick add
  if (quickAddPreview.value) {
    await executeQuickAdd()
    return
  }
  
  // Command execution
  if (filteredCommands.value.length > 0) {
    const cmd = filteredCommands.value[selectedIndex.value]
    if (cmd) {
      cmd.action()
      close()
    }
    return
  }
  
  // Navigate to first search result
  if (searchStore.results && searchStore.results.total > 0) {
    const allResults = [
      ...searchStore.results.tasks,
      ...searchStore.results.inventory_items,
      ...searchStore.results.budget_sources,
      ...searchStore.results.pages,
      ...(searchStore.results.goals || []),
      ...(searchStore.results.habits || [])
    ]
    if (allResults[selectedIndex.value]) {
      navigateTo(allResults[selectedIndex.value].type, allResults[selectedIndex.value].id)
    }
  }
}

const executeQuickAdd = async () => {
  if (!quickAddPreview.value || isCreating.value) return
  
  isCreating.value = true
  
  try {
    if (quickAddPreview.value.type === 'task') {
      await calendarStore.createTask({
        title: quickAddPreview.value.title,
        date: quickAddPreview.value.date,
        task_type: 'todo',
        priority: 1,
        status: 'not_started'
      })
      successMessage.value = `Task "${quickAddPreview.value.title}" created!`
    } else if (quickAddPreview.value.type === 'expense' || quickAddPreview.value.type === 'income') {
      await budgetStore.createEntry({
        date: format(new Date(), 'yyyy-MM-dd'),
        amount: String(quickAddPreview.value.amount),
        type: quickAddPreview.value.type,
        notes: quickAddPreview.value.notes
      })
      successMessage.value = `${quickAddPreview.value.type === 'expense' ? 'Expense' : 'Income'} of ${quickAddPreview.value.displayAmount} added!`
    }
    
    // Show success briefly then close
    setTimeout(() => {
      close()
    }, 1200)
  } catch (error) {
    console.error('Quick add failed:', error)
  } finally {
    isCreating.value = false
  }
}

onMounted(() => {
  document.addEventListener('keydown', handleKeydown)
})

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown)
})

// Focus input when opened
watch(() => searchStore.isOpen, (isOpen) => {
  if (isOpen) {
    successMessage.value = ''
    nextTick(() => inputRef.value?.focus())
  }
})

const getIcon = (type: string) => {
  switch (type) {
    case 'task': return Calendar
    case 'inventory_item': return Package
    case 'budget_source': return DollarSign
    case 'page': return FileText
    case 'goal': return Target
    case 'habit': return Zap
    default: return Search
  }
}

const navigateTo = (type: string, id: string) => {
  close()
  switch (type) {
    case 'task':
      router.push('/calendar')
      break
    case 'inventory_item':
      router.push('/inventory')
      break
    case 'budget_source':
      router.push('/budget/sources')
      break
    case 'page':
      router.push(`/notes/page/${id}`)
      break
    case 'goal':
      router.push(`/goals/${id}`)
      break
    case 'habit':
      router.push('/habits')
      break
  }
}

const close = () => {
  inputValue.value = ''
  selectedIndex.value = 0
  mode.value = 'search'
  successMessage.value = ''
  searchStore.closeSearch()
}
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-150 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-100 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div 
        v-if="searchStore.isOpen" 
        class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-start justify-center pt-4 sm:pt-[15vh] px-2 sm:px-4"
        @click="close"
      >
        <div 
          class="w-full max-w-xl bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden animate-slide-up"
          @click.stop
          @keydown="handlePaletteKeydown"
        >
          <!-- Success Message -->
          <Transition
            enter-active-class="transition duration-200 ease-out"
            enter-from-class="opacity-0 -translate-y-2"
            enter-to-class="opacity-100 translate-y-0"
            leave-active-class="transition duration-150 ease-in"
            leave-from-class="opacity-100 translate-y-0"
            leave-to-class="opacity-0 -translate-y-2"
          >
            <div v-if="successMessage" class="flex items-center gap-3 px-4 py-3 bg-primary/10 border-b border-primary/20">
              <div class="h-6 w-6 rounded-full bg-primary/20 flex items-center justify-center">
                <Zap class="h-3.5 w-3.5 text-primary" />
              </div>
              <span class="text-sm font-medium text-primary">{{ successMessage }}</span>
            </div>
          </Transition>

          <!-- Input -->
          <div class="flex items-center gap-3 px-4 py-3 border-b border-border/60">
            <div class="h-5 w-5 shrink-0 flex items-center justify-center">
              <CommandIcon v-if="mode === 'command'" class="h-5 w-5 text-primary" />
              <Search v-else class="h-5 w-5 text-muted-foreground/60" />
            </div>
            <input
              ref="inputRef"
              v-model="inputValue"
              type="text"
              :placeholder="mode === 'command' ? 'Creating...' : 'Search or type a command...'"
              class="flex-1 bg-transparent outline-none text-foreground placeholder:text-muted-foreground/60"
              :disabled="isCreating"
            />
            <div class="flex items-center gap-1.5">
              <kbd class="hidden sm:inline-flex items-center px-1.5 py-0.5 rounded border border-border/50 bg-secondary/50 text-[10px] font-mono text-muted-foreground/60">
                ESC
              </kbd>
            </div>
          </div>

          <!-- Quick Add Preview -->
          <div v-if="quickAddPreview && !successMessage" class="p-3 border-b border-border/40 bg-primary/5">
            <div class="flex items-center gap-3">
              <div class="h-10 w-10 rounded-lg bg-primary/15 flex items-center justify-center shrink-0">
                <Plus class="h-5 w-5 text-primary" />
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span class="text-xs font-semibold uppercase tracking-wider text-primary">
                    {{ quickAddPreview.type === 'task' ? 'New Task' : quickAddPreview.type === 'expense' ? 'New Expense' : 'New Income' }}
                  </span>
                </div>
                <p v-if="quickAddPreview.type === 'task'" class="text-sm font-medium truncate mt-0.5">
                  {{ quickAddPreview.title }}
                  <span class="text-muted-foreground font-normal ml-2">{{ quickAddPreview.displayDate }}</span>
                </p>
                <p v-else class="text-sm font-medium mt-0.5">
                  <span :class="quickAddPreview.type === 'expense' ? 'text-red-500' : 'text-emerald-600'">
                    {{ quickAddPreview.displayAmount }}
                  </span>
                  <span v-if="quickAddPreview.notes" class="text-muted-foreground font-normal ml-2">{{ quickAddPreview.notes }}</span>
                </p>
              </div>
              <kbd class="hidden sm:inline-flex items-center gap-0.5 px-2 py-1 rounded border border-primary/30 bg-primary/10 text-[11px] font-medium text-primary">
                Enter to create
              </kbd>
            </div>
          </div>

          <!-- Results -->
          <div class="max-h-[360px] overflow-auto scrollbar-thin">
            <!-- Loading State -->
            <div v-if="searchStore.loading && mode === 'search'" class="flex items-center justify-center py-12 text-muted-foreground">
              <div class="h-5 w-5 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
            </div>

            <!-- Commands List -->
            <div v-else-if="filteredCommands.length > 0" class="py-2">
              <div class="px-3 py-1.5 text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider">Commands</div>
              <button
                v-for="(cmd, index) in filteredCommands"
                :key="cmd.id"
                :class="[
                  'group w-full flex items-center gap-3 px-3 py-2 transition-colors text-left',
                  selectedIndex === index ? 'bg-secondary/80' : 'hover:bg-secondary/60'
                ]"
                @click="cmd.action(); close()"
                @mouseenter="selectedIndex = index"
              >
                <div class="h-8 w-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                  <component :is="cmd.icon" class="h-4 w-4 text-primary" />
                </div>
                <span class="text-sm font-medium">{{ cmd.label }}</span>
                <ArrowRight class="h-4 w-4 text-muted-foreground/40 ml-auto opacity-0 group-hover:opacity-100 transition-opacity" />
              </button>
            </div>

            <!-- Search Results List -->
            <div v-else-if="searchStore.results && searchStore.results.total > 0 && !quickAddPreview" class="py-2">
              <template v-if="searchStore.results.tasks.length">
                <div class="px-3 py-1.5 text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider">Tasks</div>
                <button
                  v-for="item in searchStore.results.tasks"
                  :key="item.id"
                  class="group w-full flex items-center gap-3 px-3 py-2 hover:bg-secondary/60 transition-colors text-left"
                  @click="navigateTo(item.type, item.id)"
                >
                  <div class="h-8 w-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
                    <component :is="getIcon(item.type)" class="h-4 w-4 text-primary" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium truncate">{{ item.title }}</p>
                    <p v-if="item.description" class="text-xs text-muted-foreground truncate">{{ item.description }}</p>
                  </div>
                  <ArrowRight class="h-4 w-4 text-muted-foreground/40 opacity-0 group-hover:opacity-100 transition-opacity" />
                </button>
              </template>

              <template v-if="searchStore.results.inventory_items.length">
                <div class="px-3 py-1.5 text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider mt-1">Inventory</div>
                <button
                  v-for="item in searchStore.results.inventory_items"
                  :key="item.id"
                  class="group w-full flex items-center gap-3 px-3 py-2 hover:bg-secondary/60 transition-colors text-left"
                  @click="navigateTo(item.type, item.id)"
                >
                  <div class="h-8 w-8 rounded-lg bg-amber-500/10 flex items-center justify-center shrink-0">
                    <component :is="getIcon(item.type)" class="h-4 w-4 text-amber-600" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium truncate">{{ item.title }}</p>
                    <p v-if="item.description" class="text-xs text-muted-foreground truncate">{{ item.description }}</p>
                  </div>
                  <ArrowRight class="h-4 w-4 text-muted-foreground/40 opacity-0 group-hover:opacity-100 transition-opacity" />
                </button>
              </template>

              <template v-if="searchStore.results.budget_sources.length">
                <div class="px-3 py-1.5 text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider mt-1">Budget</div>
                <button
                  v-for="item in searchStore.results.budget_sources"
                  :key="item.id"
                  class="group w-full flex items-center gap-3 px-3 py-2 hover:bg-secondary/60 transition-colors text-left"
                  @click="navigateTo(item.type, item.id)"
                >
                  <div class="h-8 w-8 rounded-lg bg-emerald-500/10 flex items-center justify-center shrink-0">
                    <component :is="getIcon(item.type)" class="h-4 w-4 text-emerald-600" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium truncate">{{ item.title }}</p>
                    <p v-if="item.description" class="text-xs text-muted-foreground truncate">{{ item.description }}</p>
                  </div>
                  <ArrowRight class="h-4 w-4 text-muted-foreground/40 opacity-0 group-hover:opacity-100 transition-opacity" />
                </button>
              </template>

              <template v-if="searchStore.results.pages.length">
                <div class="px-3 py-1.5 text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider mt-1">Notes</div>
                <button
                  v-for="item in searchStore.results.pages"
                  :key="item.id"
                  class="group w-full flex items-center gap-3 px-3 py-2 hover:bg-secondary/60 transition-colors text-left"
                  @click="navigateTo(item.type, item.id)"
                >
                  <div class="h-8 w-8 rounded-lg bg-violet-500/10 flex items-center justify-center shrink-0">
                    <component :is="getIcon(item.type)" class="h-4 w-4 text-violet-600" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium truncate">{{ item.title }}</p>
                    <p v-if="item.description" class="text-xs text-muted-foreground truncate">{{ item.description }}</p>
                  </div>
                  <ArrowRight class="h-4 w-4 text-muted-foreground/40 opacity-0 group-hover:opacity-100 transition-opacity" />
                </button>
              </template>

              <template v-if="searchStore.results.goals?.length">
                <div class="px-3 py-1.5 text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider mt-1">Goals</div>
                <button
                  v-for="item in searchStore.results.goals"
                  :key="item.id"
                  class="group w-full flex items-center gap-3 px-3 py-2 hover:bg-secondary/60 transition-colors text-left"
                  @click="navigateTo(item.type, item.id)"
                >
                  <div class="h-8 w-8 rounded-lg bg-rose-500/10 flex items-center justify-center shrink-0">
                    <component :is="getIcon(item.type)" class="h-4 w-4 text-rose-600" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium truncate">{{ item.title }}</p>
                    <p v-if="item.description" class="text-xs text-muted-foreground truncate">{{ item.description }}</p>
                  </div>
                  <ArrowRight class="h-4 w-4 text-muted-foreground/40 opacity-0 group-hover:opacity-100 transition-opacity" />
                </button>
              </template>

              <template v-if="searchStore.results.habits?.length">
                <div class="px-3 py-1.5 text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider mt-1">Habits</div>
                <button
                  v-for="item in searchStore.results.habits"
                  :key="item.id"
                  class="group w-full flex items-center gap-3 px-3 py-2 hover:bg-secondary/60 transition-colors text-left"
                  @click="navigateTo(item.type, item.id)"
                >
                  <div class="h-8 w-8 rounded-lg bg-cyan-500/10 flex items-center justify-center shrink-0">
                    <component :is="getIcon(item.type)" class="h-4 w-4 text-cyan-600" />
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium truncate">{{ item.title }}</p>
                    <p v-if="item.description" class="text-xs text-muted-foreground truncate">{{ item.description }}</p>
                  </div>
                  <ArrowRight class="h-4 w-4 text-muted-foreground/40 opacity-0 group-hover:opacity-100 transition-opacity" />
                </button>
              </template>
            </div>

            <!-- No Results -->
            <div v-else-if="inputValue && !searchStore.loading && !quickAddPreview" class="py-12 text-center">
              <p class="text-sm text-muted-foreground">No results for "<span class="font-medium text-foreground">{{ inputValue }}</span>"</p>
            </div>

            <!-- Empty State / Help -->
            <div v-else-if="!quickAddPreview && !successMessage" class="py-6 px-4">
              <p class="text-xs font-semibold text-muted-foreground/70 uppercase tracking-wider mb-3">Quick Commands</p>
              <div class="space-y-2 text-sm text-muted-foreground">
                <div class="flex items-center gap-3">
                  <kbd class="px-2 py-0.5 rounded bg-secondary text-[11px] font-mono">task</kbd>
                  <span>Create a task (e.g., "task Buy milk tomorrow")</span>
                </div>
                <div class="flex items-center gap-3">
                  <kbd class="px-2 py-0.5 rounded bg-secondary text-[11px] font-mono">expense</kbd>
                  <span>Add expense (e.g., "expense $25 lunch")</span>
                </div>
                <div class="flex items-center gap-3">
                  <kbd class="px-2 py-0.5 rounded bg-secondary text-[11px] font-mono">income</kbd>
                  <span>Add income (e.g., "income $500 freelance")</span>
                </div>
              </div>
              <div class="mt-4 pt-4 border-t border-border/40">
                <p class="text-xs text-muted-foreground/60">Or just type to search across all your data</p>
              </div>
            </div>
          </div>

          <!-- Footer hint -->
          <div class="hidden sm:block px-4 py-2 border-t border-border/40 bg-secondary/30">
            <div class="flex items-center justify-between text-[11px] text-muted-foreground/60">
              <div class="flex items-center gap-3">
                <span class="flex items-center gap-1">
                  <kbd class="px-1 py-0.5 rounded bg-background/80 border border-border/50">↑↓</kbd>
                  Navigate
                </span>
                <span class="flex items-center gap-1">
                  <kbd class="px-1 py-0.5 rounded bg-background/80 border border-border/50">↵</kbd>
                  Select
                </span>
              </div>
              <span class="flex items-center gap-1">
                <kbd class="px-1 py-0.5 rounded bg-background/80 border border-border/50">esc</kbd>
                Close
              </span>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

