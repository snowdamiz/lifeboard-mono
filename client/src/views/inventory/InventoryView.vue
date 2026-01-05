<script setup lang="ts">
import { onMounted, ref, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, Package, MoreVertical, Trash, Edit, ChevronRight, Layers } from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useInventoryStore } from '@/stores/inventory'

const router = useRouter()
const inventoryStore = useInventoryStore()
const showNewSheet = ref(false)
const newSheetName = ref('')
const menuOpenId = ref<string | null>(null)
const editingId = ref<string | null>(null)
const editName = ref('')
const sheetNameInput = ref<InstanceType<typeof Input> | null>(null)

onMounted(() => {
  inventoryStore.fetchSheets()
})

// Focus input when modal opens
watch(showNewSheet, async (isOpen) => {
  if (isOpen) {
    await nextTick()
    sheetNameInput.value?.$el?.focus?.()
  }
})

const createSheet = async () => {
  if (!newSheetName.value.trim()) return
  const sheet = await inventoryStore.createSheet(newSheetName.value)
  newSheetName.value = ''
  showNewSheet.value = false
  router.push(`/inventory/sheet/${sheet.id}`)
}

const startEdit = (sheet: { id: string; name: string }) => {
  editingId.value = sheet.id
  editName.value = sheet.name
  menuOpenId.value = null
}

const saveEdit = async () => {
  if (!editingId.value || !editName.value.trim()) return
  await inventoryStore.updateSheet(editingId.value, { name: editName.value })
  editingId.value = null
}

const deleteSheet = async (id: string) => {
  if (confirm('Delete this inventory sheet? This will delete all items in it.')) {
    await inventoryStore.deleteSheet(id)
  }
  menuOpenId.value = null
}
</script>

<template>
  <div class="space-y-6 animate-fade-in">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Package class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Inventory</h1>
          <p class="text-muted-foreground text-sm mt-0.5">Manage your inventory sheets and items</p>
        </div>
      </div>

      <Button size="sm" class="w-full sm:w-auto" @click="showNewSheet = true">
        <Plus class="h-4 w-4 sm:mr-2" />
        <span>New Sheet</span>
      </Button>
    </div>

    <!-- Loading State -->
    <div v-if="inventoryStore.loading" class="flex items-center justify-center py-20">
      <div class="h-6 w-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
    </div>

    <!-- Empty State -->
    <div v-else-if="inventoryStore.sheets.length === 0" class="text-center py-20">
      <div class="h-16 w-16 rounded-2xl bg-primary/5 mx-auto mb-5 flex items-center justify-center">
        <Layers class="h-8 w-8 text-primary/50" />
      </div>
      <h2 class="text-lg font-medium mb-2">No inventory sheets yet</h2>
      <p class="text-muted-foreground text-sm mb-6 max-w-sm mx-auto">Create your first sheet to start tracking items in your inventory</p>
      <Button @click="showNewSheet = true">
        <Plus class="h-4 w-4" />
        Create Sheet
      </Button>
    </div>

    <!-- Sheets Grid -->
    <div v-else class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <Card
        v-for="sheet in inventoryStore.sheets"
        :key="sheet.id"
        class="group"
        interactive
        @click="router.push(`/inventory/sheet/${sheet.id}`)"
      >
        <CardHeader class="flex flex-row items-center justify-between py-4">
          <div class="flex items-center gap-3 min-w-0 flex-1">
            <div class="h-10 w-10 rounded-xl bg-amber-500/10 flex items-center justify-center shrink-0 group-hover:bg-amber-500/15 transition-colors">
              <Package class="h-5 w-5 text-amber-600" />
            </div>
            <div v-if="editingId === sheet.id" class="flex-1" @click.stop>
              <Input 
                v-model="editName" 
                class="h-8"
                @keydown.enter="saveEdit"
                @keydown.escape="editingId = null"
              />
            </div>
            <div v-else class="min-w-0 flex-1">
              <CardTitle class="text-[15px] truncate">{{ sheet.name }}</CardTitle>
              <p class="text-xs text-muted-foreground mt-0.5">
                {{ new Date(sheet.inserted_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) }}
              </p>
            </div>
          </div>
          
          <div class="flex items-center gap-1" @click.stop>
            <div class="relative">
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 opacity-0 group-hover:opacity-100 transition-opacity"
                @click="menuOpenId = menuOpenId === sheet.id ? null : sheet.id"
              >
                <MoreVertical class="h-4 w-4" />
              </Button>

              <Transition
                enter-active-class="transition duration-100 ease-out"
                enter-from-class="opacity-0 scale-95"
                enter-to-class="opacity-100 scale-100"
                leave-active-class="transition duration-75 ease-in"
                leave-from-class="opacity-100 scale-100"
                leave-to-class="opacity-0 scale-95"
              >
                <div 
                  v-if="menuOpenId === sheet.id"
                  class="absolute right-0 top-full mt-1 w-32 origin-top-right bg-card border border-border/80 rounded-lg shadow-lg py-1 z-10"
                >
                  <button 
                    class="w-full flex items-center gap-2 px-3 py-1.5 text-[13px] hover:bg-secondary transition-colors"
                    @click="startEdit(sheet)"
                  >
                    <Edit class="h-3.5 w-3.5" />
                    Rename
                  </button>
                  <button 
                    class="w-full flex items-center gap-2 px-3 py-1.5 text-[13px] text-destructive hover:bg-destructive/10 transition-colors"
                    @click="deleteSheet(sheet.id)"
                  >
                    <Trash class="h-3.5 w-3.5" />
                    Delete
                  </button>
                </div>
              </Transition>
            </div>
            <ChevronRight class="h-4 w-4 text-muted-foreground/50 opacity-0 group-hover:opacity-100 transition-opacity" />
          </div>
        </CardHeader>
      </Card>
    </div>

    <!-- New Sheet Modal -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div 
          v-if="showNewSheet" 
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
          @click="showNewSheet = false"
        >
          <Card class="w-full sm:max-w-md animate-slide-up shadow-xl border-border/80 rounded-t-2xl sm:rounded-xl" @click.stop>
            <CardHeader class="pb-4">
              <CardTitle class="text-lg">Create Inventory Sheet</CardTitle>
            </CardHeader>
            <CardContent class="pt-0 pb-6">
              <form @submit.prevent="createSheet">
                <Input 
                  ref="sheetNameInput"
                  v-model="newSheetName" 
                  placeholder="Sheet name (e.g., Pantry, Office Supplies)"
                />
                <div class="flex gap-3 mt-5">
                  <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="showNewSheet = false">
                    Cancel
                  </Button>
                  <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto" :disabled="!newSheetName.trim()">
                    Create
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>
