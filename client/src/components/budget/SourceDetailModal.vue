<script setup lang="ts">
import { ref, watch, onMounted } from 'vue'
import { Receipt, X } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { useReceiptsStore } from '@/stores/receipts'
import { useBudgetStore } from '@/stores/budget'
import { formatCurrency } from '@/lib/utils'
import PurchaseList from './PurchaseList.vue'
import PurchaseForm from './PurchaseForm.vue'
import type { BudgetSource, Purchase } from '@/types'

interface Props {
  source: BudgetSource
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  refresh: []
}>()

const receiptsStore = useReceiptsStore()
const budgetStore = useBudgetStore()
const loading = ref(false)
const purchases = ref<Purchase[]>([])
const showPurchaseForm = ref(false)
const editingPurchase = ref<Purchase | null>(null)

const loadPurchases = async () => {
  loading.value = true
  try {
    await receiptsStore.fetchPurchases({ source_id: props.source.id })
    purchases.value = receiptsStore.purchases
  } finally {
    loading.value = false
  }
}

watch(() => props.source.id, loadPurchases, { immediate: true })

const totalAmount = () => {
  return purchases.value.reduce((sum, p) => sum + parseFloat(p.total_price || '0'), 0)
}

const handleEditPurchase = (purchase: Purchase) => {
  editingPurchase.value = purchase
  showPurchaseForm.value = true
}

const handleDeletePurchase = async (id: string) => {
  if (confirm('Are you sure you want to delete this purchase?')) {
    await receiptsStore.deletePurchase(id)
    await loadPurchases()
    emit('refresh')
  }
}

const handlePurchaseSaved = async () => {
  showPurchaseForm.value = false
  editingPurchase.value = null
  await loadPurchases()
  await budgetStore.fetchSources()
  emit('refresh')
}
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="w-full sm:max-w-2xl bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[90vh] sm:max-h-[85vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0">
          <div class="flex items-center gap-3">
            <div class="h-10 w-10 rounded-xl bg-red-500/10 flex items-center justify-center">
              <Receipt class="h-5 w-5 text-red-500" />
            </div>
            <div>
              <h2 class="text-lg font-semibold">{{ source.name }}</h2>
              <p class="text-sm text-muted-foreground">Store Receipt</p>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <span class="text-lg font-semibold text-red-500">
              {{ formatCurrency(totalAmount()) }}
            </span>
            <Button variant="ghost" size="icon" @click="emit('close')">
              <X class="h-4 w-4" />
            </Button>
          </div>
        </div>

        <!-- Summary -->
        <div class="px-4 py-3 bg-secondary/30 border-b border-border shrink-0">
          <div class="flex items-center justify-between text-sm">
            <span class="text-muted-foreground">
              {{ purchases.length }} {{ purchases.length === 1 ? 'purchase' : 'purchases' }}
            </span>
            <span class="text-muted-foreground">
              Total: <span class="font-semibold text-foreground">{{ formatCurrency(totalAmount()) }}</span>
            </span>
          </div>
        </div>

        <!-- Purchases List -->
        <div class="flex-1 overflow-auto p-4">
          <div v-if="loading" class="text-center py-8 text-muted-foreground">
            Loading purchases...
          </div>
          <PurchaseList
            v-else
            :purchases="purchases"
            :loading="loading"
            @edit="handleEditPurchase"
            @delete="handleDeletePurchase"
          />
        </div>

        <!-- Footer -->
        <div class="flex gap-3 p-4 border-t border-border bg-card shrink-0">
          <Button variant="outline" class="flex-1" @click="emit('close')">
            Close
          </Button>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- Purchase Form Modal -->
  <PurchaseForm
    v-if="showPurchaseForm"
    :purchase="editingPurchase"
    @close="showPurchaseForm = false; editingPurchase = null"
    @saved="handlePurchaseSaved"
  />
</template>
