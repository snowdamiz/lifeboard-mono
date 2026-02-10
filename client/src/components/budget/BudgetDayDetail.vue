<script setup lang="ts">
import { computed, ref } from 'vue'
import { format } from 'date-fns'
import { X, Plus, TrendingUp, TrendingDown, ChevronDown, ChevronRight, Eye, Clock, MapPin, User, Edit2, Trash2 } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { useBudgetStore } from '@/stores/budget'
import { useReceiptsStore } from '@/stores/receipts'
import { formatCurrency } from '@/lib/utils'
import BaseItemEntry from '@/components/shared/BaseItemEntry.vue'
import BaseIconButton from '@/components/shared/BaseIconButton.vue'
import type { BudgetEntry, Purchase, Stop } from '@/types'

interface Props {
  date: Date
  inlineMode?: boolean
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  addEntry: []
  editEntry: [entry: BudgetEntry]
  refresh: []
}>()

const budgetStore = useBudgetStore()
const receiptsStore = useReceiptsStore()

const expandedTripIds = ref<Set<string>>(new Set())

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

const toggleTripExpansion = (tripId: string) => {
  if (expandedTripIds.value.has(tripId)) {
    expandedTripIds.value.delete(tripId)
  } else {
    expandedTripIds.value.add(tripId)
  }
  // Force reactivity
  expandedTripIds.value = new Set(expandedTripIds.value)
}

const isTripExpanded = (tripId: string) => {
  return expandedTripIds.value.has(tripId)
}

const getEntryPurchases = (entry: BudgetEntry): Purchase[] => {
  // The entry object from backend should have stop data
  return (entry as any).stop?.purchases || []
}

const getEntryStop = (entry: BudgetEntry): Stop | null => {
  return (entry as any).stop || null
}

const getEntryTrip = (entry: BudgetEntry) => {
  return (entry as any).stop?.trip || (entry as any).trip || null
}

const formatTime = (dateStr: string | null) => {
  if (!dateStr) return null
  try {
    const date = new Date(dateStr)
    return format(date, 'h:mm a')
  } catch {
    return null
  }
}

const getQuantity = (p: Purchase) => {
  if (p.count) return p.count
  if (p.units) return p.units
  return '1'
}

const getUnitLabel = (p: Purchase) => {
  if (p.unit_measurement) return p.unit_measurement
  return ''
}

const getUnitPrice = (p: Purchase) => {
  if (p.count && p.price_per_count) return p.price_per_count
  if (p.units && p.price_per_unit) return p.price_per_unit
  return null
}

const deleteEntry = async (entry: BudgetEntry) => {
  if (entry.is_trip) return // Trips are handled via expansion & individual purchase deletion
  
  await budgetStore.deleteEntry(entry.id)
  emit('refresh')
}

const deletePurchase = async (purchase: Purchase) => {
  await receiptsStore.deletePurchase(purchase.id)
  emit('refresh')
}
</script>

<template>
  <!-- INLINE MODE: renders as a plain panel filling parent container -->
  <div v-if="inlineMode" class="h-full flex flex-col overflow-hidden bg-card">
    <!-- Header -->
    <div class="flex items-center justify-between px-3 py-2 border-b border-border shrink-0">
      <div>
        <h2 class="text-sm font-semibold">{{ format(date, 'EEEE') }}</h2>
        <p class="text-xs text-muted-foreground">{{ format(date, 'MMMM d, yyyy') }}</p>
      </div>
      <Button variant="ghost" size="icon" class="h-7 w-7" @click="emit('close')">
        <X class="h-4 w-4" />
      </Button>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-3 gap-2 px-3 py-2 bg-secondary/30 border-b border-border shrink-0">
      <div class="text-center">
        <p class="text-[10px] text-muted-foreground">Income</p>
        <p class="text-xs font-semibold text-emerald-600 tabular-nums">{{ formatCurrency(totalIncome) }}</p>
      </div>
      <div class="text-center">
        <p class="text-[10px] text-muted-foreground">Expenses</p>
        <p class="text-xs font-semibold text-red-500 tabular-nums">{{ formatCurrency(totalExpense) }}</p>
      </div>
      <div class="text-center">
        <p class="text-[10px] text-muted-foreground">Net</p>
        <p :class="['text-xs font-semibold tabular-nums', netAmount >= 0 ? 'text-emerald-600' : 'text-red-500']">
          {{ formatCurrency(netAmount) }}
        </p>
      </div>
    </div>

    <!-- Entries List -->
    <div class="flex-1 overflow-auto p-3">
      <div v-if="dayEntries.length === 0" class="text-center py-8">
        <div class="h-10 w-10 rounded-full bg-muted/50 flex items-center justify-center mx-auto mb-2">
          <TrendingUp class="h-5 w-5 text-muted-foreground/50" />
        </div>
        <p class="text-muted-foreground text-xs">No entries for this day</p>
        <Button size="sm" class="mt-3 text-xs" @click="emit('addEntry')">
          <Plus class="h-3 w-3 mr-1" />
          Add Entry
        </Button>
      </div>

      <div v-else class="space-y-3">
        <!-- Income Section -->
        <div v-if="incomeEntries.length > 0">
          <h3 class="text-[10px] font-medium text-muted-foreground uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
            <TrendingUp class="h-3 w-3 text-emerald-600" />
            Income
          </h3>
          <div class="space-y-1.5">
            <div
              v-for="entry in incomeEntries"
              :key="entry.id"
              class="flex items-center justify-between p-2 rounded-lg bg-emerald-500/5 border border-emerald-500/20 group"
            >
              <div class="flex items-center gap-2 min-w-0">
                <div class="h-6 w-6 rounded bg-emerald-500/10 flex items-center justify-center shrink-0">
                  <TrendingUp class="h-3 w-3 text-emerald-600" />
                </div>
                <div class="min-w-0 flex-1">
                  <p class="text-xs font-medium truncate">{{ entry.source?.name || 'No source' }}</p>
                  <div v-if="entry.tags && entry.tags.length > 0" class="flex flex-wrap gap-0.5 mt-0.5">
                    <Badge 
                      v-for="tag in entry.tags" 
                      :key="tag.id"
                      variant="secondary"
                      class="text-[9px] px-1 h-3.5 font-normal"
                      :style="{ backgroundColor: tag.color + '20', color: tag.color }"
                    >
                      {{ tag.name }}
                    </Badge>
                  </div>
                  <p v-if="entry.notes" class="text-[10px] text-muted-foreground truncate mt-0.5">{{ entry.notes }}</p>
                </div>
              </div>
              <div class="flex items-center gap-1">
                <span class="text-xs font-semibold text-emerald-600 tabular-nums">+{{ formatCurrency(entry.amount) }}</span>
                <BaseIconButton :icon="Edit2" @click="emit('editEntry', entry)" />
                <BaseIconButton :icon="Trash2" variant="destructive" @click="deleteEntry(entry)" />
              </div>
            </div>
          </div>
        </div>

        <!-- Expense Section -->
        <div v-if="expenseEntries.length > 0">
          <h3 class="text-[10px] font-medium text-muted-foreground uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
            <TrendingDown class="h-3 w-3 text-red-500" />
            Expenses
          </h3>
          <div class="space-y-1.5">
            <div
              v-for="entry in expenseEntries"
              :key="entry.id"
            >
              <div class="flex items-center justify-between p-2 rounded-lg bg-red-500/5 border border-red-500/20 group">
                <div class="flex items-center gap-2 min-w-0 flex-1">
                  <div class="h-6 w-6 rounded bg-red-500/10 flex items-center justify-center shrink-0">
                    <TrendingDown class="h-3 w-3 text-red-500" />
                  </div>
                  <div class="min-w-0 flex-1">
                    <div class="flex items-center gap-1.5">
                      <Button
                        v-if="entry.is_trip && getEntryPurchases(entry).length > 1"
                        variant="ghost"
                        size="icon"
                        class="h-4 w-4 shrink-0"
                        @click="toggleTripExpansion(entry.id)"
                      >
                        <ChevronDown v-if="isTripExpanded(entry.id)" class="h-3 w-3" />
                        <ChevronRight v-else class="h-3 w-3" />
                      </Button>
                      <p class="text-xs font-medium truncate">
                        {{ entry.source?.name || 'No source' }}
                        <span v-if="entry.is_trip && getEntryPurchases(entry).length > 1" class="text-[10px] text-muted-foreground ml-1">
                          ({{ getEntryPurchases(entry).length }} items)
                        </span>
                      </p>
                    </div>
                    <div v-if="entry.tags && entry.tags.length > 0" class="flex flex-wrap gap-0.5 mt-0.5">
                      <Badge 
                        v-for="tag in entry.tags" 
                        :key="tag.id"
                        variant="secondary"
                        class="text-[9px] px-1 h-3.5 font-normal"
                        :style="{ backgroundColor: tag.color + '20', color: tag.color }"
                      >
                        {{ tag.name }}
                      </Badge>
                    </div>
                    <p v-if="entry.notes" class="text-[10px] text-muted-foreground truncate mt-0.5">{{ entry.notes }}</p>
                  </div>
                </div>
                <div class="flex items-center gap-1">
                  <span class="text-xs font-semibold text-red-500 tabular-nums">-{{ formatCurrency(entry.amount) }}</span>
                  <BaseIconButton v-if="!entry.is_trip" :icon="Edit2" @click="emit('editEntry', entry)" />
                  <Button
                    v-if="entry.is_trip"
                    variant="ghost"
                    size="icon"
                    class="h-6 w-6 opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground hover:text-primary"
                    @click="toggleTripExpansion(entry.id)"
                    :title="isTripExpanded(entry.id) ? 'Collapse purchases' : 'View purchases'"
                  >
                    <Eye class="h-3 w-3" />
                  </Button>
                  <BaseIconButton v-if="!entry.is_trip" :icon="Trash2" variant="destructive" @click="deleteEntry(entry)" />
                </div>
              </div>

              <!-- Expanded Trip Purchases (inline) -->
              <div 
                v-if="entry.is_trip && isTripExpanded(entry.id)"
                class="ml-2 mt-2 space-y-2 max-h-[40vh] overflow-auto"
              >
                <div v-if="getEntryStop(entry) || getEntryTrip(entry)" class="bg-secondary/50 rounded-lg p-2 space-y-1.5">
                  <h4 class="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">Trip Details</h4>
                  <div v-if="getEntryStop(entry)?.store_name" class="flex items-center gap-1.5 text-xs">
                    <MapPin class="h-3 w-3 text-primary" />
                    <span class="font-medium">Store:</span>
                    <span>{{ getEntryStop(entry)?.store_name }}</span>
                  </div>
                  <div v-if="getEntryStop(entry)?.store_address" class="flex items-center gap-1.5 text-xs text-muted-foreground">
                    <span class="ml-4">{{ getEntryStop(entry)?.store_address }}</span>
                  </div>
                  <div v-if="getEntryTrip(entry)?.trip_start || getEntryTrip(entry)?.trip_end" class="flex items-center gap-1.5 text-xs">
                    <Clock class="h-3 w-3 text-primary" />
                    <span class="font-medium">Time:</span>
                    <span v-if="formatTime(getEntryTrip(entry)?.trip_start)">
                      {{ formatTime(getEntryTrip(entry)?.trip_start) }}
                      <span v-if="formatTime(getEntryTrip(entry)?.trip_end)"> - {{ formatTime(getEntryTrip(entry)?.trip_end) }}</span>
                    </span>
                  </div>
                  <div v-if="getEntryTrip(entry)?.driver" class="flex items-center gap-1.5 text-xs">
                    <User class="h-3 w-3 text-primary" />
                    <span class="font-medium">Driver:</span>
                    <span>{{ getEntryTrip(entry)?.driver }}</span>
                  </div>
                </div>
                
                <div v-if="getEntryPurchases(entry).length > 0" class="space-y-1">
                  <h4 class="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">Purchases ({{ getEntryPurchases(entry).length }})</h4>
                  <BaseItemEntry
                    v-for="purchase in getEntryPurchases(entry)"
                    :key="purchase.id"
                    :name="purchase.item"
                    :brand="purchase.brand"
                    :count="purchase.count"
                    :count-unit="purchase.count_unit"
                    :units="purchase.units"
                    :unit-measurement="purchase.unit_measurement"
                    :price="getUnitPrice(purchase)"
                    :total="purchase.total_price"
                    :price-per-count="purchase.price_per_count"
                    :price-per-unit="purchase.price_per_unit"
                    :store-code="purchase.store_code"
                    :taxable="purchase.taxable"
                    :tags="purchase.tags"
                  >
                    <template #right-value>
                      <span class="text-xs font-semibold text-red-500 tabular-nums whitespace-nowrap">
                        -{{ formatCurrency(purchase.total_price) }}
                      </span>
                    </template>
                    <template #actions>
                      <BaseIconButton :icon="Trash2" variant="destructive" @click="deletePurchase(purchase)" />
                    </template>
                  </BaseItemEntry>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div class="flex gap-2 px-3 py-2 border-t border-border bg-card shrink-0">
      <Button variant="outline" size="sm" class="flex-1 text-xs" @click="emit('close')">
        Close
      </Button>
      <Button size="sm" class="flex-1 text-xs" @click="emit('addEntry')">
        <Plus class="h-3 w-3 mr-1" />
        Add Entry
      </Button>
    </div>
  </div>

  <!-- MODAL MODE: original Teleport modal -->
  <Teleport v-else to="body">
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
            <p class="text-sm font-semibold text-emerald-600 tabular-nums">{{ formatCurrency(totalIncome) }}</p>
          </div>
          <div class="text-center">
            <p class="text-xs text-muted-foreground mb-0.5">Expenses</p>
            <p class="text-sm font-semibold text-red-500 tabular-nums">{{ formatCurrency(totalExpense) }}</p>
          </div>
          <div class="text-center">
            <p class="text-xs text-muted-foreground mb-0.5">Net</p>
            <p :class="['text-sm font-semibold tabular-nums', netAmount >= 0 ? 'text-emerald-600' : 'text-red-500']">
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
                    <div class="min-w-0 flex-1">
                      <p class="text-sm font-medium truncate">{{ entry.source?.name || 'No source' }}</p>
                      <div v-if="entry.tags && entry.tags.length > 0" class="flex flex-wrap gap-1 mt-1">
                        <Badge 
                          v-for="tag in entry.tags" 
                          :key="tag.id"
                          variant="secondary"
                          class="text-[10px] px-1 h-4 font-normal"
                          :style="{ backgroundColor: tag.color + '20', color: tag.color }"
                        >
                          {{ tag.name }}
                        </Badge>
                      </div>
                      <p v-if="entry.notes" class="text-xs text-muted-foreground truncate mt-0.5">{{ entry.notes }}</p>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-semibold text-emerald-600 tabular-nums">+{{ formatCurrency(entry.amount) }}</span>
                    <BaseIconButton :icon="Edit2" @click="emit('editEntry', entry)" />
                    <BaseIconButton :icon="Trash2" variant="destructive" @click="deleteEntry(entry)" />
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
                >
                  <div class="flex items-center justify-between p-3 rounded-lg bg-red-500/5 border border-red-500/20 group">
                    <div class="flex items-center gap-3 min-w-0 flex-1">
                      <div class="h-8 w-8 rounded-lg bg-red-500/10 flex items-center justify-center shrink-0">
                        <TrendingDown class="h-4 w-4 text-red-500" />
                      </div>
                      <div class="min-w-0 flex-1">
                        <div class="flex items-center gap-2">
                          <Button
                            v-if="entry.is_trip && getEntryPurchases(entry).length > 1"
                            variant="ghost"
                            size="icon"
                            class="h-5 w-5 shrink-0"
                            @click="toggleTripExpansion(entry.id)"
                          >
                            <ChevronDown v-if="isTripExpanded(entry.id)" class="h-4 w-4" />
                            <ChevronRight v-else class="h-4 w-4" />
                          </Button>
                          <p class="text-sm font-medium truncate">
                            {{ entry.source?.name || 'No source' }}
                            <span v-if="entry.is_trip && getEntryPurchases(entry).length > 1" class="text-xs text-muted-foreground ml-1">
                              ({{ getEntryPurchases(entry).length }} items)
                            </span>
                          </p>
                        </div>
                        <div v-if="entry.tags && entry.tags.length > 0" class="flex flex-wrap gap-1 mt-1">
                          <Badge 
                            v-for="tag in entry.tags" 
                            :key="tag.id"
                            variant="secondary"
                            class="text-[10px] px-1 h-4 font-normal"
                            :style="{ backgroundColor: tag.color + '20', color: tag.color }"
                          >
                            {{ tag.name }}
                          </Badge>
                        </div>
                        <p v-if="entry.notes" class="text-xs text-muted-foreground truncate mt-0.5">{{ entry.notes }}</p>
                      </div>
                    </div>
                    <div class="flex items-center gap-2">
                      <span class="text-sm font-semibold text-red-500 tabular-nums">-{{ formatCurrency(entry.amount) }}</span>
                      <BaseIconButton v-if="!entry.is_trip" :icon="Edit2" @click="emit('editEntry', entry)" />
                      <Button
                        v-if="entry.is_trip"
                        variant="ghost"
                        size="icon"
                        class="h-7 w-7 opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground hover:text-primary"
                        @click="toggleTripExpansion(entry.id)"
                        :title="isTripExpanded(entry.id) ? 'Collapse purchases' : 'View purchases'"
                      >
                        <Eye class="h-3.5 w-3.5" />
                      </Button>
                      <BaseIconButton v-if="!entry.is_trip" :icon="Trash2" variant="destructive" @click="deleteEntry(entry)" />
                    </div>
                  </div>

                  <!-- Expanded Trip Info & Purchases List -->
                  <div 
                    v-if="entry.is_trip && isTripExpanded(entry.id)"
                    class="ml-2 mt-3 space-y-3 max-h-[50vh] overflow-auto"
                  >
                    <div v-if="getEntryStop(entry) || getEntryTrip(entry)" class="bg-secondary/50 rounded-lg p-3 space-y-2">
                      <h4 class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Trip Details</h4>
                      <div v-if="getEntryStop(entry)?.store_name" class="flex items-center gap-2 text-sm">
                        <MapPin class="h-3.5 w-3.5 text-primary" />
                        <span class="font-medium">Store:</span>
                        <span>{{ getEntryStop(entry)?.store_name }}</span>
                      </div>
                      <div v-if="getEntryStop(entry)?.store_address" class="flex items-center gap-2 text-sm text-muted-foreground">
                        <span class="ml-5">{{ getEntryStop(entry)?.store_address }}</span>
                      </div>
                      <div v-if="getEntryTrip(entry)?.trip_start || getEntryTrip(entry)?.trip_end" class="flex items-center gap-2 text-sm">
                        <Clock class="h-3.5 w-3.5 text-primary" />
                        <span class="font-medium">Time:</span>
                        <span v-if="formatTime(getEntryTrip(entry)?.trip_start)">
                          {{ formatTime(getEntryTrip(entry)?.trip_start) }}
                          <span v-if="formatTime(getEntryTrip(entry)?.trip_end)"> - {{ formatTime(getEntryTrip(entry)?.trip_end) }}</span>
                        </span>
                      </div>
                      <div v-if="getEntryTrip(entry)?.driver" class="flex items-center gap-2 text-sm">
                        <User class="h-3.5 w-3.5 text-primary" />
                        <span class="font-medium">Driver:</span>
                        <span>{{ getEntryTrip(entry)?.driver }}</span>
                      </div>
                      <div v-if="getEntryTrip(entry)?.notes || getEntryStop(entry)?.notes" class="text-sm text-muted-foreground mt-2 pt-2 border-t border-border/50">
                        <span class="font-medium text-foreground">Notes:</span>
                        {{ getEntryTrip(entry)?.notes || getEntryStop(entry)?.notes }}
                      </div>
                    </div>
                    
                    <div v-if="getEntryPurchases(entry).length > 0" class="space-y-1.5">
                      <h4 class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Purchases ({{ getEntryPurchases(entry).length }})</h4>
                      <BaseItemEntry
                        v-for="purchase in getEntryPurchases(entry)"
                        :key="purchase.id"
                        :name="purchase.item"
                        :brand="purchase.brand"
                        :count="purchase.count"
                        :count-unit="purchase.count_unit"
                        :units="purchase.units"
                        :unit-measurement="purchase.unit_measurement"
                        :price="getUnitPrice(purchase)"
                        :total="purchase.total_price"
                        :price-per-count="purchase.price_per_count"
                        :price-per-unit="purchase.price_per_unit"
                        :store-code="purchase.store_code"
                        :taxable="purchase.taxable"
                        :tags="purchase.tags"
                      >
                        <template #right-value>
                          <span class="text-sm font-semibold text-red-500 tabular-nums whitespace-nowrap">
                            -{{ formatCurrency(purchase.total_price) }}
                          </span>
                        </template>
                        <template #actions>
                          <BaseIconButton :icon="Trash2" variant="destructive" @click="deletePurchase(purchase)" />
                        </template>
                      </BaseItemEntry>
                    </div>
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
