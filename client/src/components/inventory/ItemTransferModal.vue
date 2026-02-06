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
  (e: 'transferred'): void
}>()

const inventoryStore = useInventoryStore()

const transferQuantity = ref(1)
const targetSheetId = ref<string>('')
const isTransferring = ref(false)
const isLoadingMatches = ref(false)
const matchingItems = ref<(InventoryItem & { sheet: { id: string; name: string } })[]>([])
const errorMessage = ref('')

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

watch(() => props.item, async (newItem) => {
  if (newItem) {
    transferQuantity.value = Math.min(1, Number(newItem.quantity))
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

const maxQuantity = computed(() => Number(props.item?.quantity) || 0)
// maxCount: prioritize quantity (available stock) over count (packaging)
const maxCount = computed(() => Number(props.item?.quantity) || Number(props.item?.count) || 1)




const handleTransfer = async () => {
  if (!props.item || !targetSheetId.value || transferQuantity.value < 1) {
    // We let the user click, but show an error if invalid
    errorMessage.value = 'Please select a destination sheet and valid quantity'
    return
  }
  
  isTransferring.value = true
  errorMessage.value = ''

  try {
    const result = await api.transferItem(props.item.id, targetSheetId.value, transferQuantity.value)

    if ('success' in result && result.success) {
      emit('transferred')
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


const handleTransferAll = () => {
  transferQuantity.value = maxCount.value
}


const handleTransferAllQty = () => {
  if (props.item) {
    transferQuantity.value = Number(props.item.quantity)
  }
}
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
        <div class="bg-muted/50 rounded-lg p-3">
          <div class="font-medium">{{ item.name }}</div>
          <div class="text-sm text-muted-foreground flex items-center gap-2">
            <span v-if="item.brand">{{ item.brand }}</span>
            <Badge variant="outline" class="font-mono">
              {{ item.quantity }} available
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
              <span>{{ match.quantity }} {{ match.unit_of_measure || '' }}</span>
            </div>
          </div>
        </div>

        <!-- Quantity input - changes based on usage_mode -->
        <div class="space-y-2">
          <!-- By Count mode: transfer by individual pieces -->
          <template v-if="item.usage_mode === 'count' || !item.usage_mode">
            <div class="text-sm font-medium">{{ item.count_unit || 'count' }} to transfer</div>
            <div class="flex items-center gap-2">
              <Input
                type="number"
                v-model.number="transferQuantity"
                :min="1"
                :max="maxCount"
                class="w-24"
              />
              <span class="text-sm text-muted-foreground">
                {{ item.count_unit || 'units' }}
                <span v-if="item.quantity && item.unit_of_measure">
                  ({{ item.quantity }} {{ item.unit_of_measure }} each)
                </span>
              </span>
              <Button variant="outline" size="sm" @click="handleTransferAll">
                Transfer All ({{ maxCount }})
              </Button>
            </div>
          </template>
          
          <!-- By Quantity mode: transfer whole units -->
          <template v-else>
            <div class="text-sm font-medium">quantity to transfer</div>
            <div class="flex items-center gap-2">
              <Input
                type="number"
                v-model.number="transferQuantity"
                :min="1"
                :max="Number(item.quantity)"
                class="w-24"
              />
              <span class="text-sm text-muted-foreground">
                {{ item.unit_of_measure || 'units' }}
                <span v-if="item.count && item.count_unit">
                  ({{ item.name }} - {{ item.count }} {{ item.count_unit }})
                </span>
              </span>
              <Button variant="outline" size="sm" @click="handleTransferAllQty">
                Transfer All ({{ item.quantity }})
              </Button>
            </div>
          </template>
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
