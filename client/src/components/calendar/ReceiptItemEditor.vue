<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { X, ChevronDown, ChevronUp } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Checkbox } from '@/components/ui/checkbox'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import { useReceiptsStore } from '@/stores/receipts'
import type { ReceiptScanItem, Brand } from '@/types'
import { DEFAULT_UNIT_MEASUREMENTS, mergeUnitsWithDefaults } from '@/utils/units'

interface Props {
  item: ReceiptScanItem
  index: number
}

const props = defineProps<Props>()
const emit = defineEmits<{
  update: [index: number, updates: Partial<ReceiptScanItem>]
  remove: [index: number]
}>()

const receiptsStore = useReceiptsStore()
const expanded = ref(true)
const taxableId = `taxable-${props.index}-${Math.random().toString(36).substring(2, 9)}`

// Unit autocomplete - shows defaults + custom units from store
const searchUnits = async (query: string) => {
  const q = query.toLowerCase()
  const allUnits = mergeUnitsWithDefaults(receiptsStore.units)
  return allUnits.filter(u => u.name.toLowerCase().includes(q))
}

const handleUnitCreate = async (name: string) => {
  if (!name) return
  let existing = receiptsStore.units.find(u => u.name.toLowerCase() === name.toLowerCase())
  if (!existing) {
    try {
      await receiptsStore.fetchUnits()
      existing = receiptsStore.units.find(u => u.name.toLowerCase() === name.toLowerCase())
    } catch (e) {
      console.error('Failed to refresh units:', e)
    }
  }
  if (existing) {
    emit('update', props.index, { unit: existing.name })
    return
  }
  try {
    await receiptsStore.createUnit(name)
    emit('update', props.index, { unit: name })
  } catch (error: any) {
    if (error.response?.status === 422 || error.message?.includes('already exist')) {
      emit('update', props.index, { unit: name })
    } else {
      console.error('Failed to create unit:', error)
    }
  }
}

const handleBrandCreate = async (name: string) => {
  if (!name.trim()) return
  const existing = receiptsStore.brands.find(b => b.name.toLowerCase() === name.trim().toLowerCase())
  if (existing) {
    emit('update', props.index, { brand: existing.name })
    return
  }
  try {
    const brand = await receiptsStore.createBrand({ name })
    emit('update', props.index, { brand: brand.name })
  } catch (e) {
    console.error('Failed to create brand', e)
  }
}

const handleItemCreate = async (name: string) => {
  if (!name.trim()) return
  emit('update', props.index, { item: name.trim() })
}

const handleStoreCodeCreate = async (code: string) => {
  if (!code.trim()) return
  emit('update', props.index, { store_code: code.trim() })
}

const handleRawTextCreate = async (text: string) => {
  if (!text.trim()) return
  emit('update', props.index, { raw_text: text.trim() })
}

const selectBrand = async (brand: Brand) => {
  emit('update', props.index, { brand: brand.name })
  
  // Try to apply defaults from brand
  if (brand.default_item && !props.item.item) {
    emit('update', props.index, { item: brand.default_item })
  }
  if (brand.default_unit_measurement && !props.item.unit) {
    emit('update', props.index, { unit: brand.default_unit_measurement })
  }
}

onMounted(async () => {
  if (receiptsStore.units.length === 0) {
    await receiptsStore.fetchUnits()
  }
  if (receiptsStore.brands.length === 0) {
    await receiptsStore.fetchBrands()
  }
})
</script>

<template>
  <div class="bg-secondary/20 rounded-lg border border-border/50 overflow-hidden">
    <!-- Header - always visible -->
    <div 
      class="flex items-center gap-2 p-3 cursor-pointer hover:bg-secondary/30 transition-colors"
      @click="expanded = !expanded"
    >
      <component :is="expanded ? ChevronUp : ChevronDown" class="h-4 w-4 text-muted-foreground shrink-0" />
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <span class="font-medium truncate">{{ item.brand || 'No brand' }}</span>
          <span class="text-muted-foreground">—</span>
          <span class="truncate text-muted-foreground">{{ item.item || 'No item' }}</span>
        </div>
      </div>
      <div class="flex items-center gap-2 shrink-0">
        <span class="font-semibold">${{ parseFloat(item.total_price || '0').toFixed(2) }}</span>
        <button
          v-if="item.taxable"
          type="button"
          class="px-1.5 py-0.5 text-xs font-medium rounded bg-blue-500/20 text-blue-600 border border-blue-500/30"
          @click.stop
        >
          T
        </button>
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-7 w-7 text-muted-foreground hover:text-destructive"
          @click.stop="emit('remove', index)"
        >
          <X class="h-4 w-4" />
        </Button>
      </div>
    </div>
    
    <!-- Expanded content - matches PurchaseForm layout -->
    <div v-if="expanded" class="p-4 pt-0 space-y-4 border-t border-border/30">
      <!-- Brand (with autocomplete) -->
      <div>
        <label class="text-sm font-medium">Brand *</label>
        <SearchableInput 
          :model-value="item.brand"
          @update:model-value="(v) => emit('update', index, { brand: v })"
          :search-function="(q) => receiptsStore.searchBrands(q)"
          :display-function="(b) => b.name"
          :value-function="(b) => b.name"
          :show-create-option="true"
          :min-chars="0"
          placeholder="Search or create brand..." 
          class="mt-1" 
          @select="selectBrand"
          @create="handleBrandCreate"
        />
      </div>

      <!-- Item -->
      <div>
        <label class="text-sm font-medium">Item *</label>
        <SearchableInput 
          :model-value="item.item"
          @update:model-value="(v) => emit('update', index, { item: v })"
          :search-function="receiptsStore.searchItemNames"
          :show-create-option="true"
          :min-chars="0"
          placeholder="Search or create item..." 
          class="mt-1"
          @create="handleItemCreate"
        />
      </div>

      <!-- Pricing Grid -->
      <div class="grid grid-cols-2 gap-3">
        <!-- Quantity -->
        <div>
          <label class="text-sm font-medium text-muted-foreground">Quantity</label>
          <Input 
            :model-value="item.quantity"
            @update:model-value="(v) => emit('update', index, { quantity: Number(v) || 1 })"
            type="number" 
            step="1" 
            min="1" 
            placeholder="1" 
            class="mt-1" 
          />
        </div>
        <!-- Unit Price -->
        <div>
          <label class="text-sm font-medium text-muted-foreground">Unit Price</label>
          <Input 
            :model-value="item.unit_price ?? ''"
            @update:model-value="(v) => emit('update', index, { unit_price: v || null })"
            type="number" 
            step="0.01" 
            min="0" 
            placeholder="0.00" 
            class="mt-1" 
          />
        </div>
      </div>

      <!-- Unit Measurement & Total Price -->
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="text-sm font-medium">Unit Measurement</label>
          <SearchableInput 
            :model-value="item.unit ?? ''"
            @update:model-value="(v) => emit('update', index, { unit: v || null })"
            :search-function="searchUnits"
            :display-function="(u) => u.name"
            :value-function="(u) => u.name"
            :show-create-option="true"
            :min-chars="0"
            placeholder="oz, lb, ct..." 
            class="mt-1"
            @create="handleUnitCreate"
          />
        </div>
        <div>
          <label class="text-sm font-medium">Total Price *</label>
          <Input 
            :model-value="item.total_price ?? ''"
            @update:model-value="(v) => emit('update', index, { total_price: v })"
            type="number" 
            step="0.01" 
            min="0" 
            placeholder="0.00" 
            class="mt-1 font-semibold" 
          />
        </div>
      </div>

      <!-- Unit Quantity Row -->
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="text-sm font-medium text-muted-foreground">Unit Quantity</label>
          <Input 
            :model-value="item.unit_quantity ?? ''"
            @update:model-value="(v) => emit('update', index, { unit_quantity: v || null })"
            placeholder="16, 2, 12..." 
            class="mt-1" 
          />
        </div>
        <div class="flex items-end pb-1">
          <!-- Taxable Checkbox -->
          <div class="flex items-center gap-2">
            <Checkbox 
              :id="taxableId"
              :model-value="item.taxable"
              @update:model-value="(v: boolean | 'indeterminate') => emit('update', index, { taxable: v === true })"
            />
            <label 
              v-if="!item.taxable"
              :for="taxableId"
              class="text-sm font-medium cursor-pointer"
            >
              Taxable item
            </label>
            <div v-else class="flex items-center gap-1.5">
              <Input
                :model-value="item.tax_amount ?? ''"
                @update:model-value="(v: string | number) => emit('update', index, { tax_amount: String(v) || null })"
                type="number"
                step="0.01"
                min="0"
                placeholder="Tax $"
                class="h-7 w-20 px-2 text-xs"
                @click.stop
              />
              <span class="text-xs font-medium">tax</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Store Code & Store Item Name -->
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="text-sm font-medium text-muted-foreground">Store Item Code</label>
          <SearchableInput 
            :model-value="item.store_code ?? ''"
            @update:model-value="(v) => emit('update', index, { store_code: v || null })"
            :search-function="receiptsStore.searchStoreCodes"
            :show-create-option="true"
            :min-chars="0"
            placeholder="SKU/Item #" 
            class="mt-1 font-mono text-xs"
            @create="handleStoreCodeCreate"
          />
        </div>
        <div>
          <label class="text-sm font-medium text-muted-foreground">Raw Receipt Text</label>
          <SearchableInput 
            :model-value="item.raw_text ?? ''"
            @update:model-value="(v) => emit('update', index, { raw_text: v || null })"
            :search-function="receiptsStore.searchReceiptItemNames"
            :show-create-option="true"
            :min-chars="0"
            placeholder="Original text" 
            class="mt-1 text-xs"
            @create="handleRawTextCreate"
          />
        </div>
      </div>
    </div>
  </div>
</template>
