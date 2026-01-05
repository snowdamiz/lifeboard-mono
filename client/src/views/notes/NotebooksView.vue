<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, BookOpen, MoreVertical, Trash, Edit, FileText, ChevronDown, ChevronRight } from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useNotesStore } from '@/stores/notes'

const router = useRouter()
const notesStore = useNotesStore()
const showNewNotebook = ref(false)
const newNotebookName = ref('')
const menuOpenId = ref<string | null>(null)
const editingId = ref<string | null>(null)
const editName = ref('')
const expandedNotebook = ref<string | null>(null)

onMounted(() => {
  notesStore.fetchNotebooks()
})

const createNotebook = async () => {
  if (!newNotebookName.value.trim()) return
  await notesStore.createNotebook(newNotebookName.value)
  newNotebookName.value = ''
  showNewNotebook.value = false
}

const startEdit = (notebook: { id: string; name: string }) => {
  editingId.value = notebook.id
  editName.value = notebook.name
  menuOpenId.value = null
}

const saveEdit = async () => {
  if (!editingId.value || !editName.value.trim()) return
  await notesStore.updateNotebook(editingId.value, { name: editName.value })
  editingId.value = null
}

const deleteNotebook = async (id: string) => {
  if (confirm('Delete this notebook? All pages inside will be deleted.')) {
    await notesStore.deleteNotebook(id)
  }
  menuOpenId.value = null
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
</script>

<template>
  <div class="space-y-6 animate-fade-in">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <BookOpen class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Notes</h1>
          <p class="text-muted-foreground text-sm mt-0.5">Your notebooks and notes</p>
        </div>
      </div>

      <Button size="sm" class="w-full sm:w-auto" @click="showNewNotebook = true">
        <Plus class="h-4 w-4 sm:mr-2" />
        <span>New Notebook</span>
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
      <h2 class="text-lg font-medium mb-2">No notebooks yet</h2>
      <p class="text-muted-foreground text-sm mb-5">Create your first notebook to start taking notes</p>
      <Button @click="showNewNotebook = true">
        <Plus class="h-4 w-4 mr-2" />
        Create Notebook
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
            <div v-if="editingId === notebook.id" class="flex-1" @click.stop>
              <Input 
                v-model="editName" 
                class="h-8"
                @keydown.enter="saveEdit"
                @keydown.escape="editingId = null"
              />
            </div>
            <CardTitle v-else class="text-sm sm:text-base truncate flex-1">{{ notebook.name }}</CardTitle>
          </div>
          
          <div class="flex items-center gap-1 sm:gap-2" @click.stop>
            <Button variant="ghost" size="sm" class="h-8 hidden sm:flex" @click="createPage(notebook.id)">
              <Plus class="h-4 w-4 mr-1" />
              New Page
            </Button>
            <Button variant="ghost" size="icon" class="h-8 w-8 sm:hidden" @click="createPage(notebook.id)">
              <Plus class="h-4 w-4" />
            </Button>
            
            <div class="relative">
              <Button 
                variant="ghost" 
                size="icon"
                class="h-8 w-8"
                @click="menuOpenId = menuOpenId === notebook.id ? null : notebook.id"
              >
                <MoreVertical class="h-4 w-4" />
              </Button>

              <div 
                v-if="menuOpenId === notebook.id"
                class="absolute right-0 top-full mt-1 w-36 bg-card border border-border rounded-xl shadow-lg py-1.5 z-10"
              >
                <button 
                  class="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-secondary transition-colors"
                  @click="startEdit(notebook)"
                >
                  <Edit class="h-4 w-4" />
                  Rename
                </button>
                <button 
                  class="w-full flex items-center gap-2 px-3 py-2 text-sm text-destructive hover:bg-destructive/10 transition-colors"
                  @click="deleteNotebook(notebook.id)"
                >
                  <Trash class="h-4 w-4" />
                  Delete
                </button>
              </div>
            </div>

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
              class="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-secondary/70 transition-colors cursor-pointer"
              @click="router.push(`/notes/page/${page.id}`)"
            >
              <FileText class="h-4 w-4 text-muted-foreground" />
              <span class="text-sm font-medium">{{ page.title }}</span>
            </div>
            <div v-if="notesStore.pages.length === 0" class="text-sm text-muted-foreground text-center py-6">
              No pages yet. Create one to get started.
            </div>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- New Notebook Modal -->
    <Teleport to="body">
      <div 
        v-if="showNewNotebook" 
        class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
        @click="showNewNotebook = false"
      >
        <Card class="w-full sm:max-w-md animate-slide-up shadow-xl rounded-t-2xl sm:rounded-xl" @click.stop>
          <CardHeader>
            <CardTitle>Create Notebook</CardTitle>
          </CardHeader>
          <CardContent class="pb-6">
            <form @submit.prevent="createNotebook">
              <Input 
                v-model="newNotebookName" 
                placeholder="Notebook name"
                autofocus
              />
              <div class="flex gap-3 mt-5">
                <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="showNewNotebook = false">
                  Cancel
                </Button>
                <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto" :disabled="!newNotebookName.trim()">
                  Create
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    </Teleport>
  </div>
</template>
