<script setup lang="ts">
import { computed } from 'vue'
import { format } from 'date-fns'
import { X, Plus, TrendingUp, TrendingDown, Trash2 } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { useBudgetStore } from '@/stores/budget'
import { formatCurrency } from '@/lib/utils'

interface Props {
  date: Date
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  addEntry: []
  refresh: []
}>()

const budgetStore = useBudgetStore()

const dateKey = computed(() => format(props.date, 'yyyy-MM-dd'))

const dayEntries = computed(() => {
  return budgetStore.entriesByDate[dateKey.value] || []
})

const incomeEntries = computed(() => 
  dayEntries.value.filter(e => e.type === 'income')
)

const expenseEntries = computed(() => 
  dayEntries.value.filter(e => e.type === 'expense')
)

const totalIncome = computed(() => 
  incomeEntries.value.reduce((sum, e) => sum + parseFloat(e.amount), 0)
)

const totalExpense = computed(() => 
  expenseEntries.value.reduce((sum, e) => sum + parseFloat(e.amount), 0)
)

const netAmount = computed(() => totalIncome.value - totalExpense.value)

const deleteEntry = async (id: string) => {
  if (!confirm('Delete this entry?')) return
  await budgetStore.deleteEntry(id)
  emit('refresh')
}
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="w-full sm:max-w-lg bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[90vh] sm:max-h-[85vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0">
          <div>
            <h2 class="text-lg font-semibold">{{ format(date, 'EEEE') }}</h2>
            <p class="text-sm text-muted-foreground">{{ format(date, 'MMMM d, yyyy') }}</p>
          </div>
          <Button variant="ghost" size="icon" @click="emit('close')">
            <X class="h-4 w-4" />
          </Button>
        </div>

        <!-- Summary -->
        <div class="grid grid-cols-3 gap-2 p-4 bg-secondary/30 border-b border-border shrink-0">
          <div class="text-center">
            <p class="text-xs text-muted-foreground mb-0.5">Income</p>
            <p class="text-sm font-semibold text-emerald-600 tabular-nums">
              {{ formatCurrency(totalIncome) }}
            </p>
          </div>
          <div class="text-center">
            <p class="text-xs text-muted-foreground mb-0.5">Expenses</p>
            <p class="text-sm font-semibold text-red-500 tabular-nums">
              {{ formatCurrency(totalExpense) }}
            </p>
          </div>
          <div class="text-center">
            <p class="text-xs text-muted-foreground mb-0.5">Net</p>
            <p :class="[
              'text-sm font-semibold tabular-nums',
              netAmount >= 0 ? 'text-emerald-600' : 'text-red-500'
            ]">
              {{ formatCurrency(netAmount) }}
            </p>
          </div>
        </div>

        <!-- Entries List -->
        <div class="flex-1 overflow-auto p-4">
          <div v-if="dayEntries.length === 0" class="text-center py-12">
            <div class="h-12 w-12 rounded-full bg-muted/50 flex items-center justify-center mx-auto mb-3">
              <TrendingUp class="h-6 w-6 text-muted-foreground/50" />
            </div>
            <p class="text-muted-foreground text-sm">No entries for this day</p>
            <Button size="sm" class="mt-4" @click="emit('addEntry')">
              <Plus class="h-4 w-4 mr-2" />
              Add Entry
            </Button>
          </div>

          <div v-else class="space-y-4">
            <!-- Income Section -->
            <div v-if="incomeEntries.length > 0">
              <h3 class="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2 flex items-center gap-2">
                <TrendingUp class="h-3.5 w-3.5 text-emerald-600" />
                Income
              </h3>
              <div class="space-y-2">
                <div
                  v-for="entry in incomeEntries"
                  :key="entry.id"
                  class="flex items-center justify-between p-3 rounded-lg bg-emerald-500/5 border border-emerald-500/20 group"
                >
                  <div class="flex items-center gap-3 min-w-0">
                    <div class="h-8 w-8 rounded-lg bg-emerald-500/10 flex items-center justify-center shrink-0">
                      <TrendingUp class="h-4 w-4 text-emerald-600" />
                    </div>
                    <div class="min-w-0">
                      <p class="text-sm font-medium truncate">
                        {{ entry.source?.name || 'No source' }}
                      </p>
                      <p v-if="entry.notes" class="text-xs text-muted-foreground truncate">
                        {{ entry.notes }}
                      </p>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-semibold text-emerald-600 tabular-nums">
                      +{{ formatCurrency(entry.amount) }}
                    </span>
                    <Button
                      variant="ghost"
                      size="icon"
                      class="h-7 w-7 opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground hover:text-red-500"
                      @click="deleteEntry(entry.id)"
                    >
                      <Trash2 class="h-3.5 w-3.5" />
                    </Button>
                  </div>
                </div>
              </div>
            </div>

            <!-- Expense Section -->
            <div v-if="expenseEntries.length > 0">
              <h3 class="text-xs font-medium text-muted-foreground uppercase tracking-wider mb-2 flex items-center gap-2">
                <TrendingDown class="h-3.5 w-3.5 text-red-500" />
                Expenses
              </h3>
              <div class="space-y-2">
                <div
                  v-for="entry in expenseEntries"
                  :key="entry.id"
                  class="flex items-center justify-between p-3 rounded-lg bg-red-500/5 border border-red-500/20 group"
                >
                  <div class="flex items-center gap-3 min-w-0">
                    <div class="h-8 w-8 rounded-lg bg-red-500/10 flex items-center justify-center shrink-0">
                      <TrendingDown class="h-4 w-4 text-red-500" />
                    </div>
                    <div class="min-w-0">
                      <p class="text-sm font-medium truncate">
                        {{ entry.source?.name || 'No source' }}
                      </p>
                      <p v-if="entry.notes" class="text-xs text-muted-foreground truncate">
                        {{ entry.notes }}
                      </p>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-semibold text-red-500 tabular-nums">
                      -{{ formatCurrency(entry.amount) }}
                    </span>
                    <Button
                      variant="ghost"
                      size="icon"
                      class="h-7 w-7 opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground hover:text-red-500"
                      @click="deleteEntry(entry.id)"
                    >
                      <Trash2 class="h-3.5 w-3.5" />
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="flex gap-3 p-4 border-t border-border bg-card shrink-0">
          <Button variant="outline" class="flex-1" @click="emit('close')">
            Close
          </Button>
          <Button class="flex-1" @click="emit('addEntry')">
            <Plus class="h-4 w-4 mr-2" />
            Add Entry
          </Button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

