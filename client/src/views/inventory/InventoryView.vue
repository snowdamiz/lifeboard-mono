<script setup lang="ts">
import { onMounted, ref, nextTick, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, Package, ChevronRight, Layers, PlusCircle, MinusCircle, X, Edit2, Trash2 } from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { useInventoryStore } from '@/stores/inventory'
import { useTagsStore } from '@/stores/tags'
import TagManager from '@/components/shared/TagManager.vue'
import PageHeader from '@/components/shared/PageHeader.vue'
import FilterDropdown from '@/components/shared/FilterDropdown.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import FormModal from '@/components/shared/FormModal.vue'
import BaseIconButton from '@/components/shared/BaseIconButton.vue'
import type { InventorySheet, Tag } from '@/types'

const router = useRouter()
const inventoryStore = useInventoryStore()
const tagsStore = useTagsStore()
const showSheetModal = ref(false)
const editingSheet = ref<InventorySheet | null>(null)
const sheetNameInput = ref<InstanceType<typeof Input> | null>(null)
const filterCheckedTagIds = ref<Set<string>>(new Set())

// Sync filter tags from store
watch(() => inventoryStore.sheetFilterTags, (newTags: string[]) => {
  filterCheckedTagIds.value = new Set(newTags)
}, { immediate: true })

const formData = ref({
  name: '',
  tag_ids: [] as string[]
})

// Tag selection state for modal
const tempSelectedTags = ref<Set<string>>(new Set())

// Helper to resolve tag objects from IDs
const resolveTags = (tagIds: string[]): Tag[] => {
  return tagIds.map(id => tagsStore.tags.find(t => t.id === id)).filter(Boolean) as Tag[]
}

const addCheckedTags = () => {
  const currentSet = new Set(formData.value.tag_ids)
  tempSelectedTags.value.forEach(id => currentSet.add(id))
  formData.value.tag_ids = Array.from(currentSet)
  tempSelectedTags.value = new Set()
}

const removeCheckedTags = () => {
  const currentSet = new Set(formData.value.tag_ids)
  tempSelectedTags.value.forEach(id => currentSet.delete(id))
  formData.value.tag_ids = Array.from(currentSet)
  tempSelectedTags.value = new Set()
}

const removeTag = (tagId: string) => {
  formData.value.tag_ids = formData.value.tag_ids.filter(id => id !== tagId)
}

onMounted(() => {
  inventoryStore.sheetFilterTags = []
  inventoryStore.fetchSheets()
})

const handleFilterApply = () => {
  inventoryStore.sheetFilterTags = Array.from(filterCheckedTagIds.value)
  inventoryStore.fetchSheets()
}

const handleFilterClear = () => {
  inventoryStore.sheetFilterTags = []
  filterCheckedTagIds.value = new Set()
  inventoryStore.fetchSheets()
}

const openCreateModal = () => {
  editingSheet.value = null
  formData.value = {
    name: '',
    tag_ids: []
  }
  tempSelectedTags.value = new Set()
  showSheetModal.value = true
  nextTick(() => {
    sheetNameInput.value?.$el?.focus?.()
  })
}

const openEditModal = (sheet: InventorySheet) => {
  editingSheet.value = sheet
  formData.value = {
    name: sheet.name,
    tag_ids: sheet.tags?.map(t => t.id) || []
  }
  tempSelectedTags.value = new Set()
  showSheetModal.value = true
  nextTick(() => {
    sheetNameInput.value?.$el?.focus?.()
  })
}

const saveSheet = async () => {
  if (!formData.value.name.trim()) return

  if (editingSheet.value) {
    await inventoryStore.updateSheet(editingSheet.value.id, {
      name: formData.value.name,
      tag_ids: formData.value.tag_ids
    })
  } else {
    await inventoryStore.createSheet(formData.value.name, formData.value.tag_ids)
  }
  
  showSheetModal.value = false
}

const deleteSheet = async (id: string) => {
  await inventoryStore.deleteSheet(id)
}
</script>

<template>
  <div class="space-y-6 animate-fade-in pb-20 sm:pb-0">
    <!-- Header -->
    <PageHeader :icon="Package" title="Inventory" subtitle="Manage your inventory sheets and items">
      <template #actions>
        <FilterDropdown
          v-model="filterCheckedTagIds"
          title="Filter Sheets"
          @apply="handleFilterApply"
          @clear="handleFilterClear"
        />
        <Button size="sm" class="w-full sm:w-auto" @click="openCreateModal">
          <Plus class="h-4 w-4 sm:mr-2" />
          <span>New Sheet</span>
        </Button>
      </template>
    </PageHeader>

    <!-- Loading State -->
    <div v-if="inventoryStore.loading" class="flex items-center justify-center py-20">
      <div class="h-6 w-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
    </div>

    <!-- Empty State -->
    <EmptyState
      v-else-if="inventoryStore.sheets.length === 0"
      :icon="Layers"
      title="No inventory sheets found"
      :description="inventoryStore.sheetFilterTags.length > 0 ? 'Try adjusting your filters' : 'Create your first sheet to start tracking items'"
      :action-label="inventoryStore.sheetFilterTags.length > 0 ? 'Clear Filters' : 'Create Sheet'"
      :show-clear-action="inventoryStore.sheetFilterTags.length > 0"
      @action="openCreateModal"
      @clear="handleFilterClear"
    />

    <!-- Sheets List -->
    <div v-else class="grid gap-3">
      <Card
        v-for="sheet in inventoryStore.sheets"
        :key="sheet.id"
        class="group cursor-pointer hover:border-primary/50 transition-colors"
        @click="router.push(`/inventory/sheet/${sheet.id}`)"
      >
        <CardHeader class="flex flex-row items-center justify-between py-4">
          <div class="flex items-center gap-4 min-w-0 flex-1">
            <div class="h-10 w-10 rounded-xl bg-amber-500/10 flex items-center justify-center shrink-0 group-hover:bg-amber-500/15 transition-colors">
              <Package class="h-5 w-5 text-amber-600" />
            </div>
            
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2">
                <CardTitle class="text-[15px] truncate">{{ sheet.name }}</CardTitle>
                <div v-if="sheet.tags && sheet.tags.length > 0" class="flex gap-1">
                  <Badge 
                    v-for="tag in sheet.tags.slice(0, 3)" 
                    :key="tag.id" 
                    variant="secondary"
                    class="h-5 text-[10px] px-1.5 font-normal"
                    :style="{ backgroundColor: tag.color + '20', color: tag.color }"
                  >
                    {{ tag.name }}
                  </Badge>
                  <Badge v-if="sheet.tags.length > 3" variant="secondary" class="h-5 text-[10px] px-1.5">
                    +{{ sheet.tags.length - 3 }}
                  </Badge>
                </div>
              </div>
              <p class="text-xs text-muted-foreground mt-0.5">
                {{ new Date(sheet.inserted_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) }}
                <span v-if="sheet.items && sheet.items.length > 0" class="mx-1.5">•</span>
                <span v-if="sheet.items && sheet.items.length > 0">{{ sheet.items.length }} items</span>
              </p>
            </div>
          </div>
          
          <div class="flex items-center gap-1" @click.stop>
            <BaseIconButton :icon="Edit2" @click="openEditModal(sheet)" />
            <BaseIconButton :icon="Trash2" variant="destructive" @click="deleteSheet(sheet.id)" />
            <ChevronRight class="h-4 w-4 text-muted-foreground/50 opacity-0 group-hover:opacity-100 transition-opacity" />
          </div>
        </CardHeader>
      </Card>
    </div>

    <!-- Create/Edit Sheet Modal -->
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
          v-if="showSheetModal" 
          class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
          @click="showSheetModal = false"
        >
          <Card class="w-full sm:max-w-lg animate-slide-up shadow-xl border-border/80 rounded-t-2xl sm:rounded-xl" @click.stop>
            <CardHeader class="pb-4">
              <CardTitle class="text-lg">{{ editingSheet ? 'Edit Inventory Sheet' : 'Create Inventory Sheet' }}</CardTitle>
            </CardHeader>
            <CardContent class="pt-0 pb-6">
              <form @submit.prevent="saveSheet" class="space-y-4">
                <div class="space-y-2">
                  <label class="text-sm font-medium">Name</label>
                  <Input 
                    ref="sheetNameInput"
                    v-model="formData.name" 
                    placeholder="Sheet name (e.g., Pantry, Office Supplies)"
                  />
                </div>

                <div class="space-y-2">
                  <label class="text-sm font-medium">Tags</label>
                  
                  <!-- Selected Tags List -->
                  <div class="flex flex-wrap gap-1.5 mb-2" v-if="formData.tag_ids.length > 0">
                    <Badge
                      v-for="tag in resolveTags(formData.tag_ids)"
                      :key="tag.id"
                      :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                      variant="outline"
                      class="gap-1 pr-1"
                    >
                      <div 
                        class="h-1.5 w-1.5 rounded-full" 
                        :style="{ backgroundColor: tag.color }"
                      />
                      {{ tag.name }}
                      <button
                        type="button"
                        class="ml-0.5 rounded-full hover:bg-black/10 p-0.5"
                        @click="removeTag(tag.id)"
                      >
                        <X class="h-3 w-3" />
                      </button>
                    </Badge>
                  </div>

                  <div class="border border-border rounded-lg p-3 bg-secondary/10">
                    <TagManager
                      v-model:checkedTagIds="tempSelectedTags"
                      mode="select"
                      embedded
                      compact
                      class="max-h-[150px] overflow-auto"
                      :applied-tag-ids="new Set(formData.tag_ids)"
                    >
                      <template #actions="{ checkedCount }">
                        <div class="flex gap-2 mb-2">
                          <Button
                            type="button"
                            variant="outline"
                            size="sm"
                            class="h-7 px-2 text-xs flex-1 bg-background"
                            :disabled="checkedCount === 0"
                            @click="addCheckedTags"
                          >
                            <PlusCircle class="h-3 w-3 mr-1" />
                            Add
                          </Button>
                          <Button
                            type="button"
                            variant="outline"
                            size="sm"
                            class="h-7 px-2 text-xs flex-1 bg-background"
                            :disabled="checkedCount === 0"
                            @click="removeCheckedTags"
                          >
                            <MinusCircle class="h-3 w-3 mr-1" />
                            Remove
                          </Button>
                        </div>
                      </template>
                    </TagManager>
                  </div>
                </div>

                <div class="flex gap-3 pt-4">
                  <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="showSheetModal = false">
                    Cancel
                  </Button>
                  <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto" :disabled="!formData.name.trim()">
                    {{ editingSheet ? 'Save Changes' : 'Create Sheet' }}
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
