<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { ArrowRightLeft, Package, Loader2 } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Select } from '@/components/ui/select'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import type { InventoryItem, InventorySheet } from '@/types'
import { api } from '@/services/api'
import { useInventoryStore } from '@/stores/inventory'

const props = defineProps<{
  item: InventoryItem | null
  open: boolean
}>()

const emit = defineEmits<{
  (e: 'update:open', value: boolean): void
  (e: 'transferred', quantity: number, mode: 'count' | 'quantity'): void
}>()

const inventoryStore = useInventoryStore()

const transferQuantity = ref(1)
const targetSheetId = ref<string>('')
const isTransferring = ref(false)
const isLoadingMatches = ref(false)
const matchingItems = ref<(InventoryItem & { sheet: { id: string; name: string } })[]>([])
const errorMessage = ref('')

// Transfer mode: 'count', 'quantity', or 'both'
const transferMode = ref<'count' | 'quantity'>('count')
// For "both" mode, we have separate inputs
const transferCount = ref(1)

const nonPurchasesSheets = computed(() => 
  inventoryStore.sheets.filter(s => s.name !== 'Purchases')
)

const sheetOptions = computed(() => 
  nonPurchasesSheets.value.map(sheet => ({
    value: sheet.id,
    label: sheet.name,
    disabled: false
  }))
)

// Source item stats
const sourceCount = computed(() => Number(props.item?.count) || 0)
const sourceQuantity = computed(() => Number(props.item?.quantity) || 0)
const hasCount = computed(() => sourceCount.value > 0)
const hasQuantity = computed(() => sourceQuantity.value > 0)

// Available transfer modes for this item
const availableModes = computed(() => {
  const modes: { value: 'count' | 'quantity'; label: string }[] = []
  if (hasCount.value) {
    modes.push({ value: 'count', label: 'By Count' })
  }
  if (hasQuantity.value) {
    modes.push({ value: 'quantity', label: 'By Quantity' })
  }
  // If nothing is available, default to count
  if (modes.length === 0) {
    modes.push({ value: 'count', label: 'By Count' })
  }
  return modes
})

watch(() => props.item, async (newItem) => {
  if (newItem) {
    // Set default transfer mode based on usage_mode
    const defaultMode = newItem.usage_mode === 'quantity' ? 'quantity' : 'count'
    transferMode.value = defaultMode
    
    // Initialize transfer values
    if (defaultMode === 'count') {
      transferCount.value = Math.min(1, Number(newItem.count) || 1)
      transferQuantity.value = transferCount.value
    } else {
      transferQuantity.value = Math.min(1, Number(newItem.quantity) || 1)
    }
    
    targetSheetId.value = ''
    errorMessage.value = ''
    
    // Fetch matching items across sheets
    isLoadingMatches.value = true
    try {
      const res = await api.findMatchingItems(newItem.brand || '', newItem.name)
      matchingItems.value = res.data
    } catch (err) {
      console.error('Failed to find matching items:', err)
      matchingItems.value = []
    } finally {
      isLoadingMatches.value = false
    }
  }
}, { immediate: true })

onMounted(() => {
  if (inventoryStore.sheets.length === 0) {
    inventoryStore.fetchSheets()
  }
})

// Max values for validation
const maxCount = computed(() => sourceCount.value || 1)
const maxQuantity = computed(() => sourceQuantity.value || 1)

// What we're actually transferring depends on mode
const effectiveTransferValue = computed(() => {
  if (transferMode.value === 'count') {
    return transferCount.value
  }
  return transferQuantity.value
})

// Preview of what will be transferred
const transferPreview = computed(() => {
  if (!props.item) return ''
  
  if (transferMode.value === 'count') {
    const count = transferCount.value
    const unit = props.item.count_unit || 'count'
    const perContainer = sourceQuantity.value
    const perUnit = props.item.unit_of_measure
    
    let preview = `${count} ${unit}`
    if (perContainer > 0 && perUnit) {
      const totalQty = count * perContainer
      preview += ` (${totalQty} ${perUnit} total)`
    }
    return preview
  } else {
    const qty = transferQuantity.value
    const unit = props.item.unit_of_measure || 'units'
    return `${qty} ${unit}`
  }
})

const handleTransfer = async () => {
  if (!props.item || !targetSheetId.value) {
    errorMessage.value = 'Please select a destination sheet'
    return
  }

  const transferValue = effectiveTransferValue.value
  if (transferValue < 1) {
    errorMessage.value = 'Transfer amount must be at least 1'
    return
  }
  
  isTransferring.value = true
  errorMessage.value = ''

  try {
    // The backend transfer_item uses usage_mode to decide behavior:
    // 'count' -> amount is # of containers, proportional qty moves with it
    // 'quantity' -> amount is raw quantity
    const result = await api.transferItem(
      props.item.id, 
      targetSheetId.value, 
      transferValue, 
      transferMode.value
    )

    if ('success' in result && result.success) {
      emit('transferred', transferValue, transferMode.value)
      emit('update:open', false)
    } else if ('error' in result) {
      errorMessage.value = result.error
    } else {
      errorMessage.value = 'Failed to transfer item'
    }
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : 'An unexpected error occurred'
  } finally {
    isTransferring.value = false
  }
}

const handleTransferAllCount = () => {
  transferCount.value = maxCount.value
  transferQuantity.value = maxCount.value
}

const handleTransferAllQty = () => {
  transferQuantity.value = maxQuantity.value
}

// When mode changes, reset the transfer value
watch(transferMode, (mode) => {
  if (mode === 'count') {
    transferCount.value = Math.min(1, maxCount.value)
    transferQuantity.value = transferCount.value
  } else {
    transferQuantity.value = Math.min(1, maxQuantity.value)
  }
})

// Keep transferQuantity in sync when in count mode (for the API call)
watch(transferCount, (count) => {
  if (transferMode.value === 'count') {
    transferQuantity.value = count
  }
})
</script>

<template>
  <Dialog :open="open" @update:open="emit('update:open', $event)">
    <DialogContent class="sm:max-w-md">
      <DialogHeader>
        <DialogTitle class="flex items-center gap-2">
          <ArrowRightLeft class="h-5 w-5 text-primary" />
          Transfer Item
        </DialogTitle>
        <DialogDescription>
          Move items from this trip receipt to another inventory sheet
        </DialogDescription>
      </DialogHeader>

      <div v-if="item" class="space-y-4 py-4">
        <!-- Source item info -->
        <div class="bg-muted/50 rounded-lg p-3 space-y-1.5">
          <div class="font-medium">{{ item.name }}</div>
          <div v-if="item.brand" class="text-sm text-muted-foreground">{{ item.brand }}</div>
          <div class="flex flex-wrap items-center gap-2">
            <Badge v-if="hasCount" variant="outline" class="font-mono">
              {{ sourceCount }} {{ item.count_unit || 'count' }}
            </Badge>
            <Badge v-if="hasQuantity && item.unit_of_measure" variant="outline" class="font-mono">
              {{ sourceQuantity }} {{ item.unit_of_measure }}
            </Badge>
            <Badge v-if="hasCount && hasQuantity && item.unit_of_measure" variant="secondary" class="text-xs">
              {{ sourceQuantity }} {{ item.unit_of_measure }} each
            </Badge>
          </div>
        </div>

        <!-- Matching items across sheets -->
        <div v-if="isLoadingMatches" class="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 class="h-4 w-4 animate-spin" />
          Finding matches across sheets...
        </div>
        <div v-else-if="matchingItems.length > 0" class="space-y-2">
          <div class="text-xs text-muted-foreground">Found in other sheets:</div>
          <div class="space-y-1">
            <div
              v-for="match in matchingItems"
              :key="match.id"
              class="text-sm flex items-center gap-2 p-2 bg-green-500/10 rounded border border-green-500/20"
            >
              <Package class="h-4 w-4 text-green-600" />
              <span class="font-medium">{{ match.sheet.name }}</span>
              <span class="text-muted-foreground">·</span>
              <span v-if="Number(match.count) > 0">{{ Number(match.count) }} {{ match.count_unit || 'count' }}</span>
              <span v-if="Number(match.count) > 0 && Number(match.quantity) > 0" class="text-muted-foreground">·</span>
              <span v-if="Number(match.quantity) > 0">{{ match.quantity }} {{ match.unit_of_measure || '' }}</span>
            </div>
          </div>
        </div>

        <!-- Transfer mode selector - only show if item has both count and quantity -->
        <div v-if="availableModes.length > 1" class="space-y-2">
          <div class="text-sm font-medium">Transfer by</div>
          <div class="flex rounded-lg border border-border overflow-hidden">
            <button
              v-for="mode in availableModes"
              :key="mode.value"
              type="button"
              class="flex-1 px-3 py-2 text-sm font-medium transition-colors"
              :class="[
                transferMode === mode.value 
                  ? 'bg-primary text-primary-foreground' 
                  : 'bg-muted/30 hover:bg-muted',
                mode.value !== availableModes[0].value ? 'border-l border-border' : ''
              ]"
              @click="transferMode = mode.value"
            >
              {{ mode.label }}
            </button>
          </div>
        </div>

        <!-- Transfer amount input -->
        <div class="space-y-2">
          <!-- Count mode -->
          <template v-if="transferMode === 'count'">
            <div class="text-sm font-medium">Count to transfer</div>
            <div class="flex items-center gap-2">
              <Input
                type="number"
                v-model.number="transferCount"
                :min="1"
                :max="maxCount"
                class="w-24"
              />
              <span class="text-sm text-muted-foreground">
                {{ item.count_unit || 'count' }}
                <span v-if="sourceQuantity > 0 && item.unit_of_measure" class="text-xs">
                  ({{ sourceQuantity }} {{ item.unit_of_measure }} each)
                </span>
              </span>
              <Button variant="outline" size="sm" @click="handleTransferAllCount">
                All ({{ maxCount }})
              </Button>
            </div>
          </template>
          
          <!-- Quantity mode -->
          <template v-else>
            <div class="text-sm font-medium">Quantity to transfer</div>
            <div class="flex items-center gap-2">
              <Input
                type="number"
                v-model.number="transferQuantity"
                :min="1"
                :max="maxQuantity"
                step="any"
                class="w-24"
              />
              <span class="text-sm text-muted-foreground">
                {{ item.unit_of_measure || 'units' }}
              </span>
              <Button variant="outline" size="sm" @click="handleTransferAllQty">
                All ({{ maxQuantity }})
              </Button>
            </div>
          </template>

          <!-- Transfer preview -->
          <div v-if="transferPreview" class="text-xs text-muted-foreground bg-muted/30 rounded px-2.5 py-1.5">
            Transferring: <span class="font-medium text-foreground">{{ transferPreview }}</span>
          </div>
        </div>

        <!-- Target sheet selection -->
        <div class="space-y-2">
          <div class="text-sm font-medium">Destination sheet</div>
          <Select 
            v-model="targetSheetId" 
            :options="sheetOptions"
            placeholder="Select a sheet..."
          />
          <p v-if="nonPurchasesSheets.length === 0" class="text-sm text-muted-foreground">
            No sheets available. Create an inventory sheet first.
          </p>
        </div>
      </div>

      <div v-if="errorMessage" class="p-3 mb-4 text-sm text-destructive bg-destructive/10 border border-destructive/20 rounded-md">
        {{ errorMessage }}
      </div>

      <DialogFooter>
        <Button variant="outline" @click="emit('update:open', false)">
          Cancel
        </Button>
        <Button
          @click="handleTransfer"
          :disabled="isTransferring"
        >
          <Loader2 v-if="isTransferring" class="h-4 w-4 mr-2 animate-spin" />
          Transfer
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
