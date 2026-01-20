<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { ShoppingBag, Plus, MapPin, Calendar, Receipt, PackageCheck } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { useReceiptsStore } from '@/stores/receipts'
import { format } from 'date-fns'
import type { Trip, Purchase } from '@/types'
import PurchaseForm from '@/components/budget/PurchaseForm.vue'
import PurchaseList from '@/components/budget/PurchaseList.vue'
import PurchaseToInventoryModal from '@/components/budget/PurchaseToInventoryModal.vue'

const receiptsStore = useReceiptsStore()
const showTripForm = ref(false)
const showPurchaseForm = ref(false)
const editingPurchase = ref<Purchase | null>(null)
const selectedStopId = ref<string | null>(null)
const showInventoryModal = ref(false)
const inventoryTripId = ref<string | null>(null)

onMounted(async () => {
  await receiptsStore.fetchTrips()
})

const openNewTrip = () => {
  showTripForm.value = true
}

const openTripDetail = (trip: Trip) => {
  // Navigate to trip detail view or open modal
  console.log('Open trip detail:', trip)
}

const openAddPurchase = (stopId: string) => {
  selectedStopId.value = stopId
  editingPurchase.value = null
  showPurchaseForm.value = true
}

const openEditPurchase = (purchase: Purchase) => {
  editingPurchase.value = purchase
  selectedStopId.value = purchase.stop_id
  showPurchaseForm.value = true
}

const handleDeletePurchase = async (purchaseId: string) => {
  if (confirm('Are you sure you want to delete this purchase?')) {
    await receiptsStore.deletePurchase(purchaseId)
  }
}

const handlePurchaseSaved = async () => {
  showPurchaseForm.value = false
  editingPurchase.value = null
  selectedStopId.value = null
  await receiptsStore.fetchTrips()
}

const openInventoryModal = (tripId: string) => {
  inventoryTripId.value = tripId
  showInventoryModal.value = true
}

const handleInventorySaved = async () => {
  showInventoryModal.value = false
  inventoryTripId.value = null
  await receiptsStore.fetchTrips()
}

const formatDateTime = (dateTime: string | null) => {
  if (!dateTime) return 'Not set'
  return format(new Date(dateTime), 'MMM d, h:mm a')
}
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in pb-20 sm:pb-0">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <ShoppingBag class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Shopping Trips</h1>
          <p class="text-muted-foreground text-sm mt-0.5">Track your shopping trips and purchases</p>
        </div>
      </div>

      <div class="flex items-center gap-2 sm:gap-3 w-full sm:w-auto">
        <Button variant="outline" size="sm" @click="$router.push('/budget/stores')">
          <MapPin class="h-4 w-4 sm:mr-2" />
          <span class="hidden sm:inline">Manage Stores</span>
          <span class="sm:hidden">Stores</span>
        </Button>
        <Button size="sm" class="flex-1 sm:flex-none" @click="openNewTrip()">
          <Plus class="h-4 w-4 sm:mr-2" />
          <span>New Trip</span>
        </Button>
      </div>
    </div>

    <!-- Trips List -->
    <div  v-if="receiptsStore.loading" class="text-center py-8 text-muted-foreground">
      Loading trips...
    </div>

    <div v-else-if="receiptsStore.trips.length === 0" class="text-center py-12">
      <div class="h-16 w-16 rounded-full bg-muted/40 flex items-center justify-center mx-auto mb-4">
        <ShoppingBag class="h-8 w-8 text-muted-foreground/60" />
      </div>
      <h3 class="text-lg font-medium mb-1">No trips yet</h3>
      <p class="text-sm text-muted-foreground mb-4">Start tracking your shopping trips</p>
      <Button @click="openNewTrip()">
        <Plus class="h-4 w-4 mr-2" />
        New Trip
      </Button>
    </div>

    <div v-else class="space-y-3">
      <Card 
        v-for="trip in receiptsStore.trips" 
        :key="trip.id"
        class="hover:border-primary/50 transition-colors cursor-pointer"
        @click="openTripDetail(trip)"
      >
        <CardHeader class="pb-3">
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-1 flex-wrap">
                <CardTitle class="text-base">
                  {{ trip.driver || 'Shopping Trip' }}
                </CardTitle>
                <Badge v-if="trip.stops.length > 0" variant="secondary" class="text-xs">
                  {{ trip.stops.length }} {{ trip.stops.length === 1 ? 'stop' : 'stops' }}
                </Badge>
                <Button
                  v-if="trip.stops.some(s => s.purchases && s.purchases.length > 0)"
                  variant="outline"
                  size="sm"
                  class="h-6 text-xs ml-auto"
                  @click.stop="openInventoryModal(trip.id)"
                >
                  <PackageCheck class="h-3 w-3 mr-1" />
                  Add to Inventory
                </Button>
              </div>
              <div class="flex items-center gap-2 text-xs text-muted-foreground">
                <Calendar class="h-3 w-3" />
                <span>{{ formatDateTime(trip.trip_start) }}</span>
                <span v-if="trip.trip_end">→ {{ formatDateTime(trip.trip_end) }}</span>
              </div>
            </div>
          </div>
        </CardHeader>
        
        <CardContent v-if="trip.stops.length > 0" class="pt-0 space-y-4">
          <div v-for="stop in trip.stops" :key="stop.id" class="border-l-2 border-primary/20 pl-3">
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-2 text-sm">
                <MapPin class="h-3 w-3 text-muted-foreground flex-shrink-0" />
                <span class="font-medium">{{ stop.store_name || 'Unknown Store' }}</span>
              </div>
              <Button 
                variant="ghost" 
                size="sm" 
                class="h-7 text-xs"
                @click.stop="openAddPurchase(stop.id)"
              >
                <Receipt class="h-3 w-3 mr-1" />
                Add Purchase
              </Button>
            </div>
            
            <PurchaseList
              v-if="stop.purchases && stop.purchases.length > 0"
              :purchases="stop.purchases"
              @edit="openEditPurchase"
              @delete="handleDeletePurchase"
            />
            <p v-else class="text-xs text-muted-foreground pl-5">No purchases yet</p>
          </div>
          
          <p v-if="trip.notes" class="text-xs text-muted-foreground mt-3 pt-3 border-t">
            {{ trip.notes }}
          </p>
        </CardContent>
      </Card>
    </div>

    <!-- Purchase Form Modal -->
    <PurchaseForm
      v-if="showPurchaseForm"
      :purchase="editingPurchase"
      :stop-id="selectedStopId"
      @close="showPurchaseForm = false; editingPurchase = null; selectedStopId = null"
      @saved="handlePurchaseSaved"
    />

    <!-- Inventory Assignment Modal -->
    <PurchaseToInventoryModal
      v-if="showInventoryModal"
      :trip-id="inventoryTripId || undefined"
      @close="showInventoryModal = false; inventoryTripId = null"
      @saved="handleInventorySaved"
    />

    <!-- Trip Form Modal - Placeholder -->
    <!-- Will be implemented in next iteration -->
  </div>
</template>
