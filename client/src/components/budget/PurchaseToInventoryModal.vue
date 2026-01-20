<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { X, Package, Check } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Select, type SelectOption } from '@/components/ui/select'
import { useReceiptsStore } from '@/stores/receipts'
import { useInventoryStore } from '@/stores/inventory'
import type { Purchase } from '@/types'

interface Props {
  tripId?: string
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  saved: []
}>()

const receiptsStore = useReceiptsStore()
const inventoryStore = useInventoryStore()

const loading = ref(false)
const saving = ref(false)
const error = ref<string | null>(null)
const purchases = ref<Purchase[]>([])
const selectedPurchases = ref<Set<string>>(new Set())
const sheetAssignments = ref<Record<string, string>>({})

onMounted(async () => {
  loading.value = true
  error.value = null
  try {
    await inventoryStore.fetchSheets()
    
    // Fetch purchases for the trip or all unassigned purchases
    if (props.tripId) {
      const trip = await receiptsStore.fetchTrip(props.tripId)
      purchases.value = trip.stops.flatMap(stop => stop.purchases || [])
    } else {
      // Fetch all purchases without filters
      await receiptsStore.fetchPurchases({})
      purchases.value = receiptsStore.purchases
    }
  } catch (e) {
    error.value = 'Failed to load purchases. Please try again.'
    console.error('Error loading purchases:', e)
  } finally {
    loading.value = false
  }
})

const sheetOptions = computed<SelectOption[]>(() => [
  { value: '', label: 'Select sheet...' },
  ...inventoryStore.sheets.map(s => ({ value: s.id, label: s.name }))
])

const togglePurchase = (purchaseId: string) => {
  if (selectedPurchases.value.has(purchaseId)) {
    selectedPurchases.value.delete(purchaseId)
    delete sheetAssignments.value[purchaseId]
  } else {
    selectedPurchases.value.add(purchaseId)
  }
}

const selectSheet = (purchaseId: string, sheetId: string) => {
  if (sheetId) {
    sheetAssignments.value[purchaseId] = sheetId
  } else {
    delete sheetAssignments.value[purchaseId]
  }
}

const canSave = computed(() => {
  if (selectedPurchases.value.size === 0) return false
  // All selected purchases must have a sheet assigned
  return Array.from(selectedPurchases.value).every(id => sheetAssignments.value[id])
})

const save = async () => {
  if (!canSave.value) return
  
  saving.value = true
  error.value = null
  try {
    await receiptsStore.addToInventory(
      Array.from(selectedPurchases.value),
      sheetAssignments.value
    )
    emit('saved')
  } catch (e) {
    error.value = 'Failed to add purchases to inventory. Please try again.'
    console.error('Error adding to inventory:', e)
  } finally {
    saving.value = false
  }
}

const formatCurrency = (amount: string) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(parseFloat(amount))
}
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="w-full sm:max-w-3xl bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[90vh] sm:max-h-[85vh] flex flex-col">
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0">
          <div>
            <h2 class="text-lg font-semibold">Add Purchases to Inventory</h2>
            <p class="text-sm text-muted-foreground mt-0.5">
              Select purchases and assign them to inventory sheets
            </p>
          </div>
          <Button variant="ghost" size="icon" @click="emit('close')">
            <X class="h-4 w-4" />
          </Button>
        </div>

        <!-- Error Message -->
        <div v-if="error" class="mx-4 mt-4 p-3 bg-destructive/10 border border-destructive/20 rounded-lg">
          <p class="text-sm text-destructive">{{ error }}</p>
        </div>

        <div v-if="loading" class="flex-1 flex items-center justify-center py-12">
          <div class="h-8 w-8 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
        </div>

        <div v-else-if="purchases.length === 0" class="flex-1 flex flex-col items-center justify-center py-12">
          <div class="h-16 w-16 rounded-full bg-muted/40 flex items-center justify-center mb-4">
            <Package class="h-8 w-8 text-muted-foreground/60" />
          </div>
          <p class="text-muted-foreground">No purchases available</p>
        </div>

        <div v-else class="flex-1 overflow-auto p-4 space-y-2">
          <Card 
            v-for="purchase in purchases" 
            :key="purchase.id"
            :class="
              selectedPurchases.has(purchase.id)
                ? 'cursor-pointer transition-colors border-primary bg-primary/5'
                : 'cursor-pointer transition-colors hover:border-primary/50'
            "
            @click="togglePurchase(purchase.id)"
          >
            <CardContent class="p-3">
              <div class="flex items-start gap-3">
                <div 
                  :class="[
                    'h-5 w-5 rounded border-2 flex items-center justify-center flex-shrink-0 mt-0.5',
                    selectedPurchases.has(purchase.id) 
                      ? 'bg-primary border-primary text-primary-foreground' 
                      : 'border-border'
                  ]"
                >
                  <Check v-if="selectedPurchases.has(purchase.id)" class="h-3 w-3" />
                </div>

                <div class="flex-1 min-w-0">
                  <div class="flex items-start justify-between gap-2 mb-2">
                    <div class="flex-1 min-w-0">
                      <h4 class="font-medium text-sm">{{ purchase.item }}</h4>
                      <p class="text-xs text-muted-foreground">{{ purchase.brand }}</p>
                    </div>
                    <div class="text-right flex-shrink-0">
                      <div class="font-semibold text-sm">{{ formatCurrency(purchase.total_price) }}</div>
                    </div>
                  </div>

                  <div 
                    v-if="selectedPurchases.has(purchase.id)" 
                    class="pt-2 border-t border-border"
                    @click.stop
                  >
                    <label class="text-xs font-medium text-muted-foreground mb-1 block">
                      Assign to Sheet:
                    </label>
                    <Select
                      :model-value="sheetAssignments[purchase.id] || ''"
                      :options="sheetOptions"
                      placeholder="Select sheet..."
                      size="sm"
                      @update:model-value="(value) => selectSheet(purchase.id, String(value))"
                    />
                  </div>

                  <div v-if="purchase.tags && purchase.tags.length > 0" class="flex flex-wrap gap-1 mt-2">
                    <Badge
                      v-for="tag in purchase.tags.slice(0, 3)"
                      :key="tag.id"
                      variant="outline"
                      class="text-xs"
                      :style="{
                        backgroundColor: tag.color + '20',
                        color: tag.color,
                        borderColor: tag.color + '40'
                      }"
                    >
                      {{ tag.name }}
                    </Badge>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        <!-- Fixed Footer -->
        <div class="flex flex-col gap-2 p-4 border-t border-border bg-card shrink-0">
          <div v-if="selectedPurchases.size > 0" class="text-sm text-muted-foreground">
            {{ selectedPurchases.size }} {{ selectedPurchases.size === 1 ? 'purchase' : 'purchases' }} selected
          </div>
          <div class="flex gap-3">
            <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="emit('close')">
              Cancel
            </Button>
            <Button 
              type="submit" 
              class="flex-1 sm:flex-none sm:ml-auto" 
              :disabled="!canSave || saving" 
              @click="save"
            >
              {{ saving ? 'Adding...' : `Add to Inventory (${selectedPurchases.size})` }}
            </Button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
