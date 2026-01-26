<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { X, Plus, MapPin, Trash } from 'lucide-vue-next'
import type { Trip, Stop, Purchase, Store } from '@/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { useReceiptsStore } from '@/stores/receipts'
import PurchaseForm from '@/components/budget/PurchaseForm.vue'
import PurchaseList from '@/components/budget/PurchaseList.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'

interface Props {
  tripId: string
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
}>()

const receiptsStore = useReceiptsStore()
const router = useRouter()
const route = useRoute()
const loading = ref(false)
const addingStop = ref(false)
const trip = ref<Trip | null>(null)
const stops = ref<Stop[]>([])
const showPurchaseForm = ref(false)
const selectedStopId = ref<string | null>(null)
const editingPurchase = ref<Purchase | null>(null)
const storeSearchMap = ref<Record<string, string>>({})

// Driver state
const driverSearchText = ref('')
const drivers = computed(() => receiptsStore.drivers)

const loadTrip = async () => {
  loading.value = true
  try {
    trip.value = await receiptsStore.fetchTrip(props.tripId)
    stops.value = trip.value.stops
    await receiptsStore.fetchStores()
    await receiptsStore.fetchDrivers()
    
    // Set driver search text from trip
    if (trip.value?.driver_id) {
      const driver = drivers.value.find(d => d.id === trip.value?.driver_id)
      if (driver) {
        driverSearchText.value = driver.name
      }
    }
    
    // Initialize search values from stops
    if (trip.value?.stops) {
      trip.value.stops.forEach(stop => {
        if (stop.store_name) {
          storeSearchMap.value[stop.id] = stop.store_name
        } else if (stop.store_id) {
          const store = receiptsStore.stores.find(s => s.id === stop.store_id)
          if (store) {
            storeSearchMap.value[stop.id] = store.name
          }
        }
      })
    }
  } finally {
    loading.value = false
  }
}

const addStop = async () => {
  if (addingStop.value) return  // Prevent double-clicks
  addingStop.value = true
  try {
    await receiptsStore.createStop(props.tripId, { 
      position: stops.value.length,
      time_arrived: '00:00',
      time_left: '00:00'
    })
    // Reload trip to get updated stops from store
    const updatedTrip = await receiptsStore.fetchTrip(props.tripId)
    stops.value = updatedTrip.stops
  } finally {
    addingStop.value = false
  }
}

const removeStop = async (stopId: string) => {
  await receiptsStore.deleteStop(stopId)
  stops.value = stops.value.filter(s => s.id !== stopId)
}

const updateStop = async (stop: Stop, updates: Partial<Stop>) => {
  // Update API
  await receiptsStore.updateStop(stop.id, updates)
  
  // Update local state without full reload
  const index = stops.value.findIndex(s => s.id === stop.id)
  if (index !== -1) {
    stops.value[index] = { ...stops.value[index], ...updates }
  }
}

const openAddPurchase = (stopId: string) => {
  selectedStopId.value = stopId
  editingPurchase.value = null
  showPurchaseForm.value = true
}

const openEditPurchase = (purchase: Purchase) => {
  selectedStopId.value = purchase.stop_id
  editingPurchase.value = purchase
  showPurchaseForm.value = true
}

const handlePurchaseSaved = async () => {
  showPurchaseForm.value = false
  editingPurchase.value = null
  selectedStopId.value = null
  // Reload trip to refresh purchases list
  await loadTrip()
}

const handleDeletePurchase = async (purchaseId: string) => {
  console.log('handleDeletePurchase called for', purchaseId)
  
  // Checking if confirm is the issue by bypassing it temporarily
  // and logging every step of the async operation
  try {
    console.log('Calling store.deletePurchase...')
    await receiptsStore.deletePurchase(purchaseId)
    console.log('store.deletePurchase completed. Reloading trip...')
    await loadTrip()
    console.log('Trip reloaded.')
  } catch (err) {
    console.error('Error deleting purchase:', err)
  }
}

const availableStores = computed(() => receiptsStore.stores)

const getStoreSearch = (stopId: string) => storeSearchMap.value[stopId] || ''

const setStoreSearch = (stopId: string, value: string) => {
  storeSearchMap.value[stopId] = value
}

const searchDrivers = async (query: string) => {
  const q = query.toLowerCase()
  return drivers.value.filter(d => d.name.toLowerCase().includes(q))
}

const createDriver = async (name: string) => {
  if (!name.trim()) return
  const existing = drivers.value.find(d => d.name.toLowerCase() === name.trim().toLowerCase())
  if (existing) {
    await updateTripDriver(existing.id)
    driverSearchText.value = existing.name
    return
  }
  try {
    const driver = await receiptsStore.createDriver(name)
    await updateTripDriver(driver.id)
    driverSearchText.value = driver.name
  } catch (e) {
    console.error('Failed to create driver', e)
  }
}

const selectDriver = async (driver: any) => {
  await updateTripDriver(driver.id)
  driverSearchText.value = driver.name
}

const updateTripDriver = async (driverId: string | null) => {
  if (!trip.value) return
  await receiptsStore.updateTrip(trip.value.id, {
    driver_id: driverId
  })
  await loadTrip()
}



const isExactStoreMatch = (stopId: string) => {
  const search = (storeSearchMap.value[stopId] || '').toLowerCase()
  return availableStores.value.some(s => s.name.toLowerCase() === search)
}

const searchStopStores = async (query: string) => {
  const q = query.toLowerCase()
  return availableStores.value.filter(s => s.name.toLowerCase().includes(q))
}

const selectStore = async (stop: Stop, store: Store) => {
  storeSearchMap.value[stop.id] = store.name
  await updateStop(stop, { 
    store_id: store.id, 
    store_name: store.name 
  })
}

const createAndSelectStore = async (stop: Stop, storeName?: string) => {
  const name = storeName || storeSearchMap.value[stop.id]
  if (!name || isExactStoreMatch(stop.id)) return
  
  // Redirect to store creation page
  router.push({
    path: '/budget/stores',
    query: {
      new: '1',
      name: name,
      returnTo: route.fullPath
    }
  })
}

const getPurchaseDate = () => {
  if (trip.value?.trip_start) {
    // trip_start is a UTC datetime string like "2026-01-19T06:00:00Z"
    // We need to get the local date string YYYY-MM-DD
    const d = new Date(trip.value.trip_start)
    // Format as local date in YYYY-MM-DD
    const year = d.getFullYear()
    const month = String(d.getMonth() + 1).padStart(2, '0')
    const day = String(d.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
  // Fallback to local today
  const d = new Date()
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

const updateTripDate = async (newDate: string) => {
  if (!trip.value) return
  // Create ISO string from local date (start of day)
  const date = new Date(newDate)
  // Adjust for timezone offset to prevent UTC shift
  const userTimezoneOffset = date.getTimezoneOffset() * 60000
  const adjustedDate = new Date(date.getTime() + userTimezoneOffset)
  
  await receiptsStore.updateTrip(trip.value.id, {
    trip_start: adjustedDate.toISOString()
  })
  await loadTrip()
}

const handleDeleteTrip = async () => {
  if (!trip.value) return
  await receiptsStore.deleteTrip(trip.value.id)
  emit('close')
}

onMounted(() => {
  console.log('[DEBUG] TripDetailModal Mounted')
  loadTrip()
})
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4" style="z-index: 50;">
      <div class="w-full sm:max-w-4xl bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[95vh] sm:max-h-[92vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0 bg-secondary/30">
          <div class="flex-1">
            <h2 class="text-lg font-semibold">Manage Trip</h2>
            <div class="flex items-center gap-3 mt-2">
               <input 
                 type="date"
                 :value="getPurchaseDate()"
                 class="bg-transparent text-sm border border-border rounded px-2 py-0.5"
                 @change="(e) => updateTripDate((e.target as HTMLInputElement).value)"
               />
               <div class="flex items-center gap-2 border-l border-border pl-3">
                 <label class="text-xs font-medium text-muted-foreground">Driver:</label>
                 <SearchableInput 
                   v-model="driverSearchText"
                   @select="selectDriver"
                   @update:model-value="(val) => { if (!val && trip) updateTripDriver(null) }"
                   :search-function="searchDrivers"
                   :display-function="(d) => d.name"
                   :value-function="(d) => d.name"
                   :show-create-option="true"
                   :min-chars="0"
                   placeholder="Select or create driver"
                   class="w-48 text-sm"
                   @create="createDriver"
                 />
               </div>
            </div>
          </div>
          <Button variant="ghost" size="icon" @click="emit('close')">
            <X class="h-4 w-4" />
          </Button>
        </div>

        <!-- Loading State -->
        <div v-if="loading" class="flex-1 flex items-center justify-center py-12">
          <div class="h-8 w-8 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
        </div>

        <!-- Stops List -->
        <div v-else class="flex-1 overflow-auto p-4 space-y-4">
          <div v-for="(stop, index) in stops" :key="stop.id" class="border border-border rounded-lg overflow-hidden">
            <!-- Stop Header -->
            <div class="bg-secondary/30 p-3 border-b border-border">
              <div class="flex items-start gap-3">
                <div class="h-8 w-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0 mt-0.5">
                  <MapPin class="h-4 w-4 text-primary" />
                </div>
                 <div class="flex-1 space-y-3">
                   <!-- Store Selection -->
                   <div class="space-y-2">
                      <SearchableInput 
                        :model-value="getStoreSearch(stop.id)"
                        @update:model-value="(val) => setStoreSearch(stop.id, val)"
                        :search-function="searchStopStores"
                        :display-function="(s) => s.name"
                        :value-function="(s) => s.name"
                        :show-create-option="true"
                        :min-chars="0"
                        placeholder="Search or create store..." 
                        class="flex-1"
                        @select="(store) => selectStore(stop, store)"
                        @create="(name) => createAndSelectStore(stop, name)"
                      />
                   </div>

                   <!-- Time Tracking -->
                   <div class="grid grid-cols-2 gap-2">
                     <div>
                       <label class="text-xs font-medium text-muted-foreground">Time Arrived</label>
                        <Input
                          :model-value="stop.time_arrived || ''"
                          type="text"
                          placeholder="0800 or 08:00"
                          maxlength="5"
                          class="mt-1 text-sm"
                          @blur="(e: FocusEvent) => {
                            const input = (e.target as HTMLInputElement).value.trim()
                            if (!input) return
                            const formatted = input.replace(/^(\d{1,2})(\d{2})$/, '$1:$2').replace(/^(\d):/, '0$1:').replace(/:(\d)$/, ':0$1')
                            if (/^\d{2}:\d{2}$/.test(formatted)) {
                              stop.time_arrived = formatted
                              updateStop(stop, { time_arrived: formatted })
                            }
                          }"
                        />
                     </div>
                     <div>
                       <label class="text-xs font-medium text-muted-foreground">Time Left</label>
                        <Input
                          :model-value="stop.time_left || ''"
                          type="text"
                          placeholder="1700 or 17:00"
                          maxlength="5"
                          class="mt-1 text-sm"
                          @blur="(e: FocusEvent) => {
                            const input = (e.target as HTMLInputElement).value.trim()
                            if (!input) return
                            const formatted = input.replace(/^(\d{1,2})(\d{2})$/, '$1:$2').replace(/^(\d):/, '0$1:').replace(/:(\d)$/, ':0$1')
                            if (/^\d{2}:\d{2}$/.test(formatted)) {
                              stop.time_left = formatted
                              updateStop(stop, { time_left: formatted })
                            }
                          }"
                        />
                     </div>
                   </div>

                   <Input
                     :model-value="stop.notes || ''"
                     @blur="(e: FocusEvent) => updateStop(stop, { notes: (e.target as HTMLInputElement).value })"
                     placeholder="Notes for this stop..."
                   />
                 </div>
                <Button
                  variant="ghost"
                  size="icon"
                  class="shrink-0 text-destructive hover:text-destructive -mt-1 -mr-1"
                  @click="removeStop(stop.id)"
                >
                  <Trash class="h-4 w-4" />
                </Button>
              </div>
            </div>

            <!-- Purchases for this stop -->
            <div class="p-3">
              <div class="flex items-center justify-between mb-2">
                <p class="text-sm font-medium">Purchases ({{ stop.purchases?.length || 0 }})</p>
                <Button size="sm" variant="outline" @click="openAddPurchase(stop.id)">
                  <Plus class="h-3.5 w-3.5 mr-1" />
                  Add Purchase
                </Button>
              </div>
              
              <PurchaseList
                v-if="stop.purchases && stop.purchases.length > 0"
                :purchases="stop.purchases"
                @edit="openEditPurchase"
                @delete="handleDeletePurchase"
              />
              
              <p v-else class="text-sm text-muted-foreground text-center py-4">
                No purchases yet
              </p>
            </div>
          </div>

          <!-- Add Stop Button -->
          <Button variant="outline" class="w-full" @click="addStop" :disabled="addingStop">
            <Plus class="h-4 w-4 mr-2" />
            {{ addingStop ? 'Adding...' : 'Add Stop' }}
          </Button>
        </div>

        <!-- Footer -->
        <div class="flex gap-3 p-4 border-t border-border bg-card shrink-0">
          <Button variant="outline" class="flex-1 sm:flex-none" @click="emit('close')">
            Done
          </Button>
          <div class="flex-1"></div>
          <Button 
            variant="ghost" 
            class="text-destructive hover:text-destructive hover:bg-destructive/10"
            @click="handleDeleteTrip"
          >
            <Trash class="h-4 w-4 mr-2" />
            Delete Trip
          </Button>
        </div>
      </div>
    </div>

    <!-- Purchase Form Modal -->
    <PurchaseForm
      v-if="showPurchaseForm && selectedStopId"
      :stop-id="selectedStopId"
      :purchase="editingPurchase || undefined"
      :initial-date="getPurchaseDate()"
      @close="showPurchaseForm = false"
      @saved="handlePurchaseSaved"
    />
  </Teleport>
</template>
