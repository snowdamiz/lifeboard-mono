<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, BookOpen, FileText, ChevronDown, ChevronRight, Filter, X, Edit2, Trash2 } from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { useNotesStore } from '@/stores/notes'
import TagManager from '@/components/shared/TagManager.vue'
import BaseIconButton from '@/components/shared/BaseIconButton.vue'
import type { Notebook } from '@/types'

const router = useRouter()
const notesStore = useNotesStore()

// UI State
const showNotebookModal = ref(false)
const expandedNotebook = ref<string | null>(null)
const isFilterOpen = ref(false)
const filterCheckedTagIds = ref<Set<string>>(new Set())

// Sync filter tags from store to local state when store changes
watch(() => notesStore.notebookFilterTags, (newTags) => {
  filterCheckedTagIds.value = new Set(newTags)
}, { immediate: true })

// Edit State
const editingNotebook = ref<Notebook | null>(null)
const notebookForm = ref({
  name: '',
  tag_ids: new Set<string>()
})

const activeFilterCount = computed(() => notesStore.notebookFilterTags.length)

onMounted(() => {
  // Reset filters
  notesStore.notebookFilterTags = []
  notesStore.fetchNotebooks()
})

const toggleFilterTag = (tagId: string) => {
  const index = notesStore.notebookFilterTags.indexOf(tagId)
  if (index === -1) {
    notesStore.notebookFilterTags.push(tagId)
  } else {
    notesStore.notebookFilterTags.splice(index, 1)
  }
}

const applyFilters = () => {
  notesStore.notebookFilterTags = Array.from(filterCheckedTagIds.value)
  notesStore.fetchNotebooks()
  isFilterOpen.value = false
}

const clearFilters = () => {
  notesStore.notebookFilterTags = []
  notesStore.fetchNotebooks()
  isFilterOpen.value = false
}

const openCreateModal = () => {
  editingNotebook.value = null
  notebookForm.value = { 
    name: '',
    tag_ids: new Set()
  }
  showNotebookModal.value = true
}

const openEditModal = (notebook: Notebook) => {
  editingNotebook.value = notebook
  notebookForm.value = {
    name: notebook.name,
    tag_ids: new Set(notebook.tags?.map(t => t.id) || [])
  }
  showNotebookModal.value = true
}

const saveNotebook = async () => {
  if (!notebookForm.value.name.trim()) return

  const tagIds = Array.from(notebookForm.value.tag_ids)

  if (editingNotebook.value) {
    await notesStore.updateNotebook(editingNotebook.value.id, {
      name: notebookForm.value.name,
      tag_ids: tagIds
    })
  } else {
    await notesStore.createNotebook(notebookForm.value.name, tagIds)
  }
  
  showNotebookModal.value = false
  editingNotebook.value = null
}

const deleteNotebook = async (id: string) => {
  if (confirm('Are you sure you want to delete this notebook? All pages within it will be deleted.')) {
    await notesStore.deleteNotebook(id)
  }
}

const toggleExpand = async (notebookId: string) => {
  if (expandedNotebook.value === notebookId) {
    expandedNotebook.value = null
  } else {
    expandedNotebook.value = notebookId
    await notesStore.fetchPages(notebookId)
  }
}

const createPage = async (notebookId: string) => {
  const page = await notesStore.createPage(notebookId, 'Untitled Page')
  router.push(`/notes/page/${page.id}`)
}

const deletePage = async (notebookId: string, pageId: string, event: Event) => {
  event.stopPropagation()
  if (confirm('Delete this page?')) {
    await notesStore.deletePage(pageId)
  }
}
</script>

<template>
  <div class="space-y-6 animate-fade-in pb-20 sm:pb-0">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-start sm:items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <BookOpen class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Notes</h1>
          <p class="text-muted-foreground text-sm mt-0.5">Your notebooks and notes</p>
        </div>
      </div>

      <div class="flex items-center gap-2 sm:gap-3 w-full sm:w-auto">
        <div class="relative flex-1 sm:flex-none">
          <Button 
            variant="outline" 
            size="sm" 
            class="h-9 w-full sm:w-auto relative" 
            :class="{ 'border-primary text-primary': activeFilterCount > 0 }"
            @click="isFilterOpen = !isFilterOpen"
          >
            <Filter class="h-4 w-4 sm:mr-2" />
            <span class="hidden sm:inline">Filter</span>
            <span class="sm:hidden">Filter</span>
            <Badge 
              v-if="activeFilterCount > 0" 
              variant="secondary" 
              class="ml-2 h-5 min-w-[20px] px-1 bg-primary text-primary-foreground hover:bg-primary/90"
            >
              {{ activeFilterCount }}
            </Badge>
          </Button>

          <!-- Filter Dropdown -->
          <div 
            v-if="isFilterOpen" 
            class="absolute right-0 top-full mt-2 w-80 bg-popover text-popover-foreground border rounded-lg shadow-lg z-50 overflow-hidden"
          >
            <div class="p-3 border-b flex items-center justify-between">
              <div>
                <h4 class="font-medium leading-none">Filter Notebooks</h4>
                <p class="text-xs text-muted-foreground mt-1.5">Select tags to filter by</p>
              </div>
              <button class="text-xs text-primary hover:underline" @click="clearFilters" v-if="activeFilterCount > 0">
                Clear all
              </button>
            </div>
            <div class="p-2">
              <TagManager
                v-model:checkedTagIds="filterCheckedTagIds"
                mode="select"
                embedded
                :rows="3"
              />
            </div>
            <div class="p-3 border-t bg-muted/20 flex justify-between gap-2">
              <Button variant="ghost" size="sm" @click="clearFilters" :disabled="activeFilterCount === 0">
                Clear
              </Button>
              <Button size="sm" @click="applyFilters">
                Apply
              </Button>
            </div>
          </div>
          <!-- Backdrop -->
          <div v-if="isFilterOpen" class="fixed inset-0 z-40 bg-transparent" @click="isFilterOpen = false" />
        </div>

        <Button size="sm" class="flex-1 sm:flex-none text-xs sm:text-sm" @click="openCreateModal">
          <Plus class="h-4 w-4 sm:mr-2" />
          <span class="hidden sm:inline">New Notebook</span>
          <span class="sm:hidden">New</span>
        </Button>
      </div>
    </div>

    <!-- Active Filters Display -->
    <div v-if="activeFilterCount > 0" class="flex flex-wrap gap-2 items-center">
      <span class="text-xs text-muted-foreground">Active filters:</span>
      <Badge 
        v-for="tagId in notesStore.notebookFilterTags" 
        :key="tagId"
        variant="secondary"
        class="gap-1 pl-2 pr-1 py-0.5"
      >
        <span class="truncate max-w-[100px]">Tag selected</span>
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-3 w-3 sm:h-4 sm:w-4 ml-1 rounded-full -mr-0.5 hover:bg-transparent hover:text-destructive"
          @click.stop="toggleFilterTag(tagId); applyFilters()"
        >
          <X class="h-2 w-2 sm:h-3 sm:w-3" />
        </Button>
      </Badge>
      <Button variant="link" size="sm" class="h-auto p-0 text-xs text-muted-foreground" @click="clearFilters">
        Clear all
      </Button>
    </div>

    <div v-if="notesStore.loading" class="text-center py-16 text-muted-foreground">
      <div class="h-8 w-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-3" />
      Loading...
    </div>

    <div v-else-if="notesStore.notebooks.length === 0" class="text-center py-16">
      <div class="h-16 w-16 rounded-2xl bg-secondary mx-auto mb-5 flex items-center justify-center">
        <BookOpen class="h-8 w-8 text-muted-foreground/50" />
      </div>
      <h2 class="text-lg font-medium mb-2">No notebooks found</h2>
      <p class="text-muted-foreground text-sm mb-5">
        {{ activeFilterCount > 0 ? "Try adjusting your filters" : "Create your first notebook to start taking notes" }}
      </p>
      <Button @click="activeFilterCount > 0 ? clearFilters() : openCreateModal()">
        <component :is="activeFilterCount > 0 ? X : Plus" class="h-4 w-4 mr-2" />
        {{ activeFilterCount > 0 ? "Clear Filters" : "Create Notebook" }}
      </Button>
    </div>

    <div v-else class="space-y-3">
      <Card
        v-for="notebook in notesStore.notebooks"
        :key="notebook.id"
        class="overflow-hidden"
      >
        <CardHeader class="flex flex-row items-center justify-between cursor-pointer hover:bg-secondary/50 transition-colors p-3 sm:p-4" @click="toggleExpand(notebook.id)">
          <div class="flex items-center gap-2.5 sm:gap-3 min-w-0 flex-1">
            <div class="h-9 w-9 sm:h-10 sm:w-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
              <BookOpen class="h-4 w-4 sm:h-5 sm:w-5 text-primary" />
            </div>
            <div class="flex-1 min-w-0">
              <CardTitle class="text-sm sm:text-base truncate">{{ notebook.name }}</CardTitle>
              
              <!-- Tags -->
              <div v-if="notebook.tags && notebook.tags.length > 0" class="flex flex-wrap gap-1 mt-1">
                <Badge 
                  v-for="tag in notebook.tags" 
                  :key="tag.id"
                  variant="secondary"
                  class="text-[10px] px-1 h-4 font-normal"
                  :style="{ backgroundColor: tag.color + '20', color: tag.color }"
                >
                  {{ tag.name }}
                </Badge>
              </div>
            </div>
          </div>
          
          <div class="flex items-center gap-1 sm:gap-2" @click.stop>
            <Button variant="ghost" size="sm" class="h-8 hidden sm:flex" @click="createPage(notebook.id)">
              <Plus class="h-4 w-4 mr-1" />
              New Page
            </Button>
            <Button variant="ghost" size="icon" class="h-8 w-8 sm:hidden" @click="createPage(notebook.id)">
              <Plus class="h-4 w-4" />
            </Button>
            <BaseIconButton :icon="Edit2" :adaptive="false" @click="openEditModal(notebook)" />
            <BaseIconButton :icon="Trash2" variant="destructive" :adaptive="false" @click="deleteNotebook(notebook.id)" />

            <component 
              :is="expandedNotebook === notebook.id ? ChevronDown : ChevronRight" 
              class="h-4 w-4 text-muted-foreground"
              @click.stop="toggleExpand(notebook.id)"
            />
          </div>
        </CardHeader>

        <CardContent v-if="expandedNotebook === notebook.id" class="pt-0 pb-4">
          <div class="border-t border-border pt-3 space-y-1">
            <div
              v-for="page in notesStore.pages"
              :key="page.id"
              class="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-secondary/70 transition-colors cursor-pointer group"
              @click="router.push(`/notes/page/${page.id}`)"
            >
              <FileText class="h-4 w-4 text-muted-foreground" />
              <div class="flex-1 min-w-0">
                <span class="text-sm font-medium">{{ page.title }}</span>
                <!-- Page Tags could go here too but maybe overkill for this list? -->
                 <div v-if="page.tags && page.tags.length > 0" class="flex flex-wrap gap-1 mt-0.5">
                  <Badge 
                    v-for="tag in page.tags.slice(0, 3)" 
                    :key="tag.id"
                    variant="secondary"
                    class="text-[9px] px-1 h-3.5 font-normal"
                    :style="{ backgroundColor: tag.color + '20', color: tag.color }"
                  >
                    {{ tag.name }}
                  </Badge>
                </div>
              </div>
              <BaseIconButton :icon="Trash2" variant="destructive" @click="deletePage(notebook.id, page.id, $event)" />
            </div>
            <div v-if="notesStore.pages.length === 0" class="text-sm text-muted-foreground text-center py-6">
              No pages yet. Create one to get started.
            </div>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Create/Edit Notebook Modal -->
    <Teleport to="body">
      <div 
        v-if="showNotebookModal" 
        class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
        @click="showNotebookModal = false"
      >
        <Card class="w-full sm:max-w-md animate-slide-up shadow-xl rounded-t-2xl sm:rounded-xl" @click.stop>
          <CardHeader>
            <CardTitle>{{ editingNotebook ? 'Edit Notebook' : 'Create Notebook' }}</CardTitle>
          </CardHeader>
          <CardContent class="pb-6">
            <form @submit.prevent="saveNotebook" class="space-y-4">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Name</label>
                <Input 
                  v-model="notebookForm.name" 
                  placeholder="Notebook name"
                  autofocus
                />
              </div>
              
              <div>
                <label class="text-sm font-medium mb-1.5 block">Tags</label>
                <TagManager
                    v-model:checkedTagIds="notebookForm.tag_ids"
                    mode="select"
                    embedded
                />
              </div>

              <div class="flex justify-between gap-3 mt-5">
                <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="showNotebookModal = false">
                  Cancel
                </Button>
                <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto" :disabled="!notebookForm.name.trim()">
                  {{ editingNotebook ? 'Save Changes' : 'Create' }}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    </Teleport>
  </div>
</template>
