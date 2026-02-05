<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Store, Plus, MapPin, Receipt, ShoppingBag, Edit2, Trash2 } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { useReceiptsStore } from '@/stores/receipts'
import type { Store as StoreType } from '@/types'
import StoreFormModal from '@/components/budget/StoreFormModal.vue'
import StoreInventoryModal from '@/components/budget/StoreInventoryModal.vue'
import BaseIconButton from '@/components/shared/BaseIconButton.vue'

import { useRoute, useRouter } from 'vue-router'

const router = useRouter()
const route = useRoute()
const receiptsStore = useReceiptsStore()
const showStoreForm = ref(false)
const showInventoryModal = ref(false)
const editingStore = ref<StoreType | null>(null)
const viewingStore = ref<StoreType | null>(null)
const returnTo = ref<string | null>(null)
const initialName = ref<string>('')

onMounted(async () => {
  await receiptsStore.fetchStores()
  
  if (route.query.returnTo) {
    returnTo.value = route.query.returnTo as string
  }
  
  if (route.query.new) {
    if (route.query.name) {
      initialName.value = route.query.name as string
    }
    openNewStore()
  }
})

const handleStoreSaved = () => {
  // If we have a return URL, go back immediately after save
  if (returnTo.value) {
    router.push(returnTo.value)
  }
}

const handleModalClose = () => {
  // If we have a return URL and the modal is closed (either by cancel or save), 
  // we might want to go back. However, 'saved' event fires first, creating a race if we also trigger on close.
  // But if the user CANCELS, we also want to go back?
  // User said: "bring user back to wherever they were before tryin to create store"
  // If I cancel, I should probably go back.
  if (returnTo.value) {
     // A small timeout to let the saved handler fire first if it was a save
     setTimeout(() => {
        // If we are still on the page (meaning saved handler didn't redirect distinctively, usually it does), 
        // OR if clean navigation is needed.
        // Actually, logic: Saved -> redirect. Close -> redirect.
        // If saved, handleStoreSaved redirects. Using 'replac'e or 'push'.
        // If I redirect in handleStoreSaved, component unmounts?
        // Let's just do it here if we verify we haven't redirected yet?
        // Simpler: Just rely on handleModalClose for BOTH? 
        // No, saved gives feedback.
        // Let's check if the route is still the same.
        if (route.path === '/budget/stores') { // Making sure we haven't navigated away
             router.push(returnTo.value!)
        }
     }, 100)
  }
}

const openNewStore = () => {
  editingStore.value = null
  showStoreForm.value = true
}

const openEditStore = (store: StoreType, event?: Event) => {
  event?.stopPropagation()
  editingStore.value = store
  showStoreForm.value = true
}

const openInventory = (store: StoreType) => {
  viewingStore.value = store
  showInventoryModal.value = true
}

const handleDelete = async (id: string, event?: Event) => {
  event?.stopPropagation()
  await receiptsStore.deleteStore(id)
}
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in pb-20 sm:pb-0">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Store class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Stores</h1>
          <p class="text-muted-foreground text-sm mt-0.5">Manage store locations and tax rates</p>
        </div>
      </div>

      <div class="flex items-center gap-2 sm:gap-3 w-full sm:w-auto">
        <Button size="sm" class="flex-1 sm:flex-none" @click="openNewStore()">
          <Plus class="h-4 w-4 sm:mr-2" />
          <span>Add Store</span>
        </Button>
      </div>
    </div>

    <!-- Stores Grid -->
    <div v-if="receiptsStore.loading" class="text-center py-8 text-muted-foreground">
      Loading stores...
    </div>

    <div v-else-if="receiptsStore.stores.length === 0" class="text-center py-12">
      <div class="h-16 w-16 rounded-full bg-muted/40 flex items-center justify-center mx-auto mb-4">
        <Store class="h-8 w-8 text-muted-foreground/60" />
      </div>
      <h3 class="text-lg font-medium mb-1">No stores yet</h3>
      <p class="text-sm text-muted-foreground mb-4">Add your first store to get started</p>
      <Button @click="openNewStore()">
        <Plus class="h-4 w-4 mr-2" />
        Add Store
      </Button>
    </div>

    <div v-else class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <Card 
        v-for="store in receiptsStore.stores" 
        :key="store.id"
        class="hover:border-primary/50 transition-colors cursor-pointer group relative"
        @click="openInventory(store)"
      >
        <CardHeader class="pb-3">
          <div class="flex items-start justify-between">
            <div class="flex items-center gap-3">
              <div class="h-10 w-10 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                <MapPin class="h-5 w-5 text-primary" />
              </div>
              <div class="min-w-0 pr-16">
                <CardTitle class="text-base truncate">{{ store.name }}</CardTitle>
                <p v-if="store.state" class="text-xs text-muted-foreground mt-0.5">
                  {{ store.state }}
                </p>
              </div>
            </div>
            
            <div class="absolute top-4 right-4 opacity-0 group-hover:opacity-100 transition-opacity flex gap-1 bg-background/80 backdrop-blur-sm rounded-md p-1 shadow-sm border">
               <BaseIconButton :icon="Edit2" :adaptive="false" @click.stop="(e: any) => openEditStore(store, e)" />
               <BaseIconButton :icon="Trash2" variant="destructive" :adaptive="false" @click.stop="(e: any) => handleDelete(store.id, e)" />
            </div>
          </div>
        </CardHeader>
        <CardContent class="text-sm space-y-2">
          <div v-if="store.address" class="text-muted-foreground text-xs truncate">
            {{ store.address }}
          </div>
          <div v-if="store.tax_rate" class="flex items-center justify-between">
            <span class="text-xs text-muted-foreground">Tax Rate</span>
            <span class="text-xs font-medium">{{ parseFloat((parseFloat(store.tax_rate) * 100).toFixed(4)) }}%</span>
          </div>
          <div v-if="store.store_code" class="flex items-center justify-between">
            <span class="text-xs text-muted-foreground">Code</span>
            <span class="text-xs font-mono">{{ store.store_code }}</span>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Modals -->
    <StoreFormModal 
      v-model:open="showStoreForm"
      :store="editingStore"
      :initial-name="initialName"
      @saved="handleStoreSaved"
      @update:open="(val) => { showStoreForm = val; if (!val) handleModalClose() }"
    />

    <StoreInventoryModal
      v-model:open="showInventoryModal"
      :store="viewingStore"
    />
  </div>
</template>
