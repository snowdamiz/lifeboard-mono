<script setup lang="ts">
import { ref, computed } from 'vue'
import { X, Camera, Upload, Loader2, Check, AlertTriangle, Plus, Trash } from 'lucide-vue-next'
import type { ReceiptScanResult, ReceiptScanItem, Store, Purchase } from '@/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { DateChooser } from '@/components/ui/date-chooser'
import { useReceiptsStore } from '@/stores/receipts'
import ReceiptItemEditor from './ReceiptItemEditor.vue'

interface Props {
  tripId?: string
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  confirmed: [{ store: Store; stop_id?: string; purchases: Purchase[]; created_count: number }]
}>()

const receiptsStore = useReceiptsStore()

// State
const step = ref<'upload' | 'scanning' | 'review' | 'confirming' | 'success' | 'error'>('upload')
const imageData = ref<string | null>(null)
const imagePreview = ref<string | null>(null)
const scanResult = ref<ReceiptScanResult | null>(null)
const errorMessage = ref<string | null>(null)
const confirmResult = ref<{ store: Store; stop_id?: string; purchases: Purchase[]; created_count: number } | null>(null)

// File input ref
const fileInput = ref<HTMLInputElement | null>(null)

// Handlers
const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleFileSelect = async (event: Event) => {
  const input = event.target as HTMLInputElement
  if (!input.files || !input.files[0]) return

  const file = input.files[0]
  
  // Validate file type
  if (!file.type.startsWith('image/')) {
    errorMessage.value = 'Please select an image file'
    step.value = 'error'
    return
  }

  // Validate file size (max 10MB)
  if (file.size > 10 * 1024 * 1024) {
    errorMessage.value = 'Image size must be less than 10MB'
    step.value = 'error'
    return
  }

  // Read file as base64
  const reader = new FileReader()
  reader.onload = async (e) => {
    const result = e.target?.result as string
    imageData.value = result
    imagePreview.value = result
    
    // Start scanning after upload
    await scanReceipt()
  }
  reader.readAsDataURL(file)
}

const scanReceipt = async () => {
  if (!imageData.value) return

  step.value = 'scanning'
  errorMessage.value = null

  try {
    scanResult.value = await receiptsStore.scanReceipt(imageData.value)
    step.value = 'review'
  } catch (error: any) {
    console.error('Receipt scan failed:', error)
    errorMessage.value = error.message || 'Failed to scan receipt. Please try again.'
    step.value = 'error'
  }
}

const confirmScan = async () => {
  if (!scanResult.value) return

  step.value = 'confirming'
  errorMessage.value = null

  try {
    const result = await receiptsStore.confirmReceiptScan(scanResult.value, props.tripId)
    confirmResult.value = result
    step.value = 'success'
    
    // Emit result after short delay to show success state
    setTimeout(() => {
      emit('confirmed', result)
    }, 1500)
  } catch (error: any) {
    console.error('Receipt confirmation failed:', error)
    errorMessage.value = error.message || 'Failed to save receipt data. Please try again.'
    step.value = 'error'
  }
}

const resetAndRetry = () => {
  step.value = 'upload'
  imageData.value = null
  imagePreview.value = null
  scanResult.value = null
  errorMessage.value = null
  confirmResult.value = null
  if (fileInput.value) {
    fileInput.value.value = ''
  }
}

const goBackToReview = () => {
  step.value = 'review'
  errorMessage.value = null
}

// Item editing helpers
const updateItem = (index: number, updates: Partial<ReceiptScanItem>) => {
  if (!scanResult.value) return
  scanResult.value.items[index] = { ...scanResult.value.items[index], ...updates }
}

const removeItem = (index: number) => {
  if (!scanResult.value) return
  scanResult.value.items.splice(index, 1)
}

const addItem = () => {
  if (!scanResult.value) return
  scanResult.value.items.push({
    raw_text: null,
    brand: '',
    item: '',
    quantity: 1,
    count_unit: null,
    unit: null,
    unit_quantity: null,
    unit_price: null,
    total_price: '0.00',
    taxable: false,
    tax_indicator: null,
    tax_amount: null,
    tax_rate: null,
    store_code: null
  })
}

// Computed
const itemCount = computed(() => scanResult.value?.items.length || 0)
const hasNewStore = computed(() => scanResult.value?.store?.is_new ?? false)
const hasNewBrands = computed(() => 
  scanResult.value?.items.some(item => item.brand_is_new) ?? false
)
const totalAmount = computed(() => {
  if (!scanResult.value?.items) return '0.00'
  return scanResult.value.items
    .reduce((sum, item) => sum + parseFloat(item.total_price || '0'), 0)
    .toFixed(2)
})
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4" style="z-index: 60;">
      <div class="w-full max-w-2xl bg-card border border-border rounded-xl shadow-xl overflow-hidden flex flex-col max-h-[90vh]">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0 bg-secondary/30">
          <div>
            <h2 class="text-lg font-semibold flex items-center gap-2">
              <Camera class="h-5 w-5 text-primary" />
              Scan Receipt
            </h2>
            <p class="text-sm text-muted-foreground mt-0.5">
              Upload a receipt photo to automatically extract items
            </p>
          </div>
          <Button variant="ghost" size="icon" @click="emit('close')">
            <X class="h-4 w-4" />
          </Button>
        </div>

        <!-- Content based on step -->
        <div class="flex-1 overflow-auto p-4">
          <!-- Upload Step -->
          <div v-if="step === 'upload'" class="flex flex-col items-center justify-center py-8 space-y-4">
            <div 
              class="w-full max-w-md aspect-[3/4] border-2 border-dashed border-border rounded-xl flex flex-col items-center justify-center cursor-pointer hover:border-primary/50 transition-colors"
              @click="triggerFileInput"
            >
              <Upload class="h-12 w-12 text-muted-foreground mb-4" />
              <p class="text-sm font-medium">Click to upload receipt image</p>
              <p class="text-xs text-muted-foreground mt-1">JPEG, PNG up to 10MB</p>
            </div>
            
            <input 
              ref="fileInput"
              type="file"
              accept="image/*"
              class="hidden"
              @change="handleFileSelect"
            />
          </div>

          <!-- Scanning Step -->
          <div v-else-if="step === 'scanning'" class="flex flex-col items-center justify-center py-12 space-y-4">
            <div class="relative">
              <img 
                v-if="imagePreview" 
                :src="imagePreview" 
                alt="Receipt" 
                class="w-32 h-40 object-cover rounded-lg opacity-50"
              />
              <div class="absolute inset-0 flex items-center justify-center">
                <Loader2 class="h-8 w-8 text-primary animate-spin" />
              </div>
            </div>
            <p class="text-sm font-medium">Analyzing receipt...</p>
            <p class="text-xs text-muted-foreground">This may take a few seconds</p>
          </div>

          <!-- Review Step -->
          <div v-else-if="step === 'review' && scanResult" class="space-y-6">
            <!-- Store Info -->
            <div class="bg-secondary/30 rounded-lg p-4">
              <div class="flex items-center gap-2 mb-3">
                <h3 class="font-medium">Store Information</h3>
                <span v-if="hasNewStore" class="px-2 py-0.5 bg-amber-500/20 text-amber-600 text-xs rounded-full">
                  New Store
                </span>
              </div>
              <div class="grid grid-cols-3 gap-3">
                <div>
                  <label class="text-xs font-medium text-muted-foreground">Store Name</label>
                  <Input 
                    :model-value="scanResult.store.name ?? ''"
                    @update:model-value="(v) => scanResult!.store.name = v || null"
                    class="mt-1"
                    placeholder="Store name"
                  />
                </div>
                <div>
                  <label class="text-xs font-medium text-muted-foreground">Address</label>
                  <Input 
                    :model-value="scanResult.store.address ?? ''"
                    @update:model-value="(v) => scanResult!.store.address = v || null"
                    class="mt-1"
                    placeholder="Address"
                  />
                </div>
                <div>
                  <label class="text-xs font-medium text-muted-foreground">Store Code</label>
                  <Input 
                    :model-value="scanResult.store.store_code ?? ''"
                    @update:model-value="(v) => scanResult!.store.store_code = v || null"
                    class="mt-1"
                    placeholder="e.g. 02010"
                  />
                </div>
              </div>
            </div>

            <!-- Transaction Info -->
            <div class="bg-secondary/30 rounded-lg p-4">
              <h3 class="font-medium mb-3">Transaction Details</h3>
              <div class="grid grid-cols-3 gap-3">
                <div>
                  <label class="text-xs font-medium text-muted-foreground">Date</label>
                  <DateChooser 
                    :model-value="scanResult.transaction.date ?? ''"
                    @update:model-value="(v) => scanResult!.transaction.date = v || null"
                    class="mt-1"
                  />
                </div>
                <div>
                  <label class="text-xs font-medium text-muted-foreground">Subtotal</label>
                  <Input 
                    :model-value="scanResult.transaction.subtotal ?? ''"
                    @update:model-value="(v) => scanResult!.transaction.subtotal = v || null"
                    class="mt-1"
                    placeholder="0.00"
                  />
                </div>
                <div>
                  <label class="text-xs font-medium text-muted-foreground">Tax</label>
                  <Input 
                    :model-value="scanResult.transaction.tax ?? ''"
                    @update:model-value="(v) => scanResult!.transaction.tax = v || null"
                    class="mt-1"
                    placeholder="0.00"
                  />
                </div>
              </div>
            </div>

            <!-- Items List -->
            <div>
              <div class="flex items-center justify-between mb-3">
                <h3 class="font-medium">Items ({{ itemCount }})</h3>
                <div class="flex items-center gap-2">
                  <span class="text-sm text-muted-foreground">Total: ${{ totalAmount }}</span>
                  <Button size="sm" variant="outline" @click="addItem">
                    <Plus class="h-3.5 w-3.5 mr-1" />
                    Add Item
                  </Button>
                </div>
              </div>

              <div v-if="hasNewBrands" class="flex items-center gap-2 px-3 py-2 bg-amber-500/10 border border-amber-500/30 rounded-lg mb-3">
                <AlertTriangle class="h-4 w-4 text-amber-500 shrink-0" />
                <p class="text-xs text-amber-600">Some brands will be created as new entries</p>
              </div>

              <div class="space-y-3 max-h-[400px] overflow-y-auto">
                <ReceiptItemEditor 
                  v-for="(item, index) in scanResult.items" 
                  :key="index"
                  :item="item"
                  :index="index"
                  @update="updateItem"
                  @remove="removeItem"
                />
              </div>
            </div>
          </div>

          <!-- Confirming Step -->
          <div v-else-if="step === 'confirming'" class="flex flex-col items-center justify-center py-12 space-y-4">
            <Loader2 class="h-8 w-8 text-primary animate-spin" />
            <p class="text-sm font-medium">Saving purchases...</p>
          </div>

          <!-- Success Step -->
          <div v-else-if="step === 'success'" class="flex flex-col items-center justify-center py-12 space-y-4">
            <div class="h-16 w-16 rounded-full bg-green-500/20 flex items-center justify-center">
              <Check class="h-8 w-8 text-green-500" />
            </div>
            <p class="text-lg font-medium">Receipt Saved!</p>
            <p class="text-sm text-muted-foreground">
              {{ confirmResult?.created_count }} items added successfully
            </p>
          </div>

          <!-- Error Step -->
          <div v-else-if="step === 'error'" class="flex flex-col items-center justify-center py-12 space-y-4">
            <div class="h-16 w-16 rounded-full bg-destructive/20 flex items-center justify-center">
              <AlertTriangle class="h-8 w-8 text-destructive" />
            </div>
            <p class="text-lg font-medium">Something went wrong</p>
            <p class="text-sm text-muted-foreground text-center max-w-sm">
              {{ errorMessage }}
            </p>
            <div class="flex gap-2">
              <Button variant="outline" @click="resetAndRetry">Try Again</Button>
              <Button v-if="scanResult" variant="outline" @click="goBackToReview">Back to Review</Button>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="flex gap-3 p-4 border-t border-border bg-card shrink-0">
          <Button v-if="step === 'upload'" variant="outline" @click="emit('close')">
            Cancel
          </Button>
          
          <Button v-else-if="step === 'review'" variant="outline" @click="resetAndRetry">
            Start Over
          </Button>
          
          <div class="flex-1"></div>
          
          <Button 
            v-if="step === 'review'" 
            @click="confirmScan"
            :disabled="!scanResult?.items.length"
          >
            <Check class="h-4 w-4 mr-2" />
            Confirm & Save ({{ itemCount }} items)
          </Button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
