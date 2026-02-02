<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { useReceiptsStore } from '@/stores/receipts'
import type { Store } from '@/types'
import { Loader2, Search, ShoppingBag, ClipboardList } from 'lucide-vue-next'
import EditButton from '@/components/shared/EditButton.vue'
import StoreItemEditModal from './StoreItemEditModal.vue'

const props = defineProps<{
  open: boolean
  store: Store | null
}>()

defineEmits<{
  (e: 'update:open', value: boolean): void
}>()

const receiptsStore = useReceiptsStore()
const loading = ref(false)
const showEditModal = ref(false)
const editingItem = ref<any>(null)
const inventory = ref<Array<{
  id: string
  source: string
  brand: string | null
  name: string
  unit: string | null
  price: string | null
  date: string
}>>([])
const searchQuery = ref('')

watch(() => props.open, async (isOpen) => {
  if (isOpen && props.store) {
    loading.value = true
    try {
      inventory.value = await receiptsStore.fetchStoreInventory(props.store.id)
    } finally {
      loading.value = false
    }
  } else {
    inventory.value = []
    searchQuery.value = ''
  }
})

const filteredInventory = computed(() => {
  if (!searchQuery.value) return inventory.value
  
  const query = searchQuery.value.toLowerCase()
  return inventory.value.filter(item => 
    item.name.toLowerCase().includes(query) || 
    (item.brand && item.brand.toLowerCase().includes(query))
  )
})

const formatPrice = (price: string | null) => {
  if (!price) return '-'
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(parseFloat(price))
}

const formatDate = (dateString: string) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleDateString()
}

const openEdit = (item: any) => {
  editingItem.value = item
  showEditModal.value = true
}

const handleSaved = async () => {
  // Refresh inventory
  if (props.store) {
    loading.value = true
    try {
      inventory.value = await receiptsStore.fetchStoreInventory(props.store.id)
    } finally {
      loading.value = false
    }
  }
}
</script>

<template>
  <Dialog :open="open" @update:open="$emit('update:open', $event)">
    <DialogContent class="sm:max-w-[700px] max-h-[85vh] flex flex-col p-0 gap-0">
      <DialogHeader class="p-6 pb-2">
        <DialogTitle class="flex items-center gap-2">
          <span>{{ store?.name }}</span>
          <Badge variant="outline" class="font-normal text-xs">Inventory</Badge>
        </DialogTitle>
        <DialogDescription>
          Items associated with this store from past receipts and manual inventory.
        </DialogDescription>
      </DialogHeader>

      <div class="px-6 py-2">
        <div class="relative">
          <Search class="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input 
            v-model="searchQuery" 
            placeholder="Search items..." 
            class="pl-9"
          />
        </div>
      </div>

      <div class="flex-1 overflow-auto min-h-[300px] p-6 pt-2">
        <div v-if="loading" class="flex flex-col items-center justify-center py-12 text-muted-foreground">
          <Loader2 class="h-8 w-8 animate-spin mb-2" />
          <p>Loading inventory...</p>
        </div>

        <div v-else-if="filteredInventory.length === 0" class="flex flex-col items-center justify-center py-12 text-muted-foreground">
          <div class="bg-muted/50 p-3 rounded-full mb-3">
            <ShoppingBag class="h-6 w-6 opacity-50" />
          </div>
          <p>{{ searchQuery ? 'No items found matching your search' : 'No inventory items found for this store' }}</p>
        </div>

        <div v-else class="rounded-md border">
          <table class="w-full text-sm">
            <thead class="bg-muted/50 sticky top-0">
              <tr class="text-left border-b">
                <th class="h-10 px-4 font-medium text-muted-foreground w-[40px]"></th>
                <th class="h-10 px-4 font-medium text-muted-foreground">Item</th>
                <th class="h-10 px-4 font-medium text-muted-foreground w-[100px]">Unit</th>
                <th class="h-10 px-4 font-medium text-muted-foreground text-right w-[100px]">Price</th>
                <th class="h-10 px-4 font-medium text-muted-foreground text-right w-[120px]">Last Seen</th>
              </tr>
            </thead>
            <tbody>
              <tr 
                v-for="item in filteredInventory" 
                :key="item.id + item.source"
                class="border-b last:border-0 hover:bg-muted/30 transition-colors group"
                @click="openEdit(item)"
              >
                <td class="p-3 text-center">
                  <div class="tooltip" :data-tip="item.source === 'receipt' ? 'From Receipt' : 'From Manual Inventory'">
                    <ClipboardList v-if="item.source === 'manual'" class="h-4 w-4 text-blue-500 mx-auto" title="Manual Inventory" />
                    <ShoppingBag v-else class="h-4 w-4 text-emerald-500 mx-auto" title="Receipt" />
                  </div>
                </td>
                <td class="p-3">
                  <div class="font-medium">{{ item.brand ? `${item.brand} ` : '' }}{{ item.name }}</div>
                  <div class="text-xs text-muted-foreground capitalize">{{ item.source }}</div>
                </td>
                <td class="p-3">
                  <Badge variant="secondary" class="font-normal text-xs" v-if="item.unit">
                    {{ item.unit }}
                  </Badge>
                  <span v-else class="text-muted-foreground">-</span>
                </td>
                <td class="p-3 text-right font-mono text-xs">
                  {{ formatPrice(item.price) }}
                </td>
                <td class="p-3 text-right text-muted-foreground text-xs group relative">
                   <div class="group-hover:hidden">{{ formatDate(item.date) }}</div>
                   <div class="hidden group-hover:block absolute right-2 top-1/2 -translate-y-1/2">
                      <EditButton :adaptive="false" @click.stop="openEdit(item)" />
                   </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="p-6 pt-2 border-t flex justify-end">
        <Button variant="outline" @click="$emit('update:open', false)">Close</Button>
      </div>

      <StoreItemEditModal 
        v-model:open="showEditModal"
        :store="store"
        :item="editingItem"
        @saved="handleSaved"
      />
    </DialogContent>
  </Dialog>
</template>
