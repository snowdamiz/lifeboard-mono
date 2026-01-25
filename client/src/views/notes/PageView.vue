<script setup lang="ts">
import { onMounted, ref, watch, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { 
  ArrowLeft, 
  Trash, 
  Eye, 
  Code,
  Bold,
  Italic,
  Strikethrough,
  List,
  ListOrdered,
  Link2,
  Image,
  Quote,
  Heading1,
  Heading2,
  Heading3,
  Minus,
  Tag as TagIcon
} from 'lucide-vue-next'
import { marked } from 'marked'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { useNotesStore } from '@/stores/notes'
import { debounce } from '@/lib/utils'
import TagManager from '@/components/shared/TagManager.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import { useTextTemplate } from '@/composables/useTextTemplate'

const route = useRoute()
const router = useRouter()
const notesStore = useNotesStore()

// Templates
const pageTitleTemplate = useTextTemplate('page_title')
const saving = ref(false)
const lastSaved = ref<Date | null>(null)
const viewMode = ref<'edit' | 'preview'>('edit')
const textareaRef = ref<HTMLTextAreaElement | null>(null)

const title = ref('')
const content = ref('')
const tagIds = ref<Set<string>>(new Set())
const isTagsOpen = ref(false)

const pageId = () => route.params.id as string

// Configure marked for safe rendering
marked.setOptions({
  breaks: true,
  gfm: true
})

const renderedContent = computed(() => {
  if (!content.value) return '<p class="text-muted-foreground">Nothing to preview yet...</p>'
  return marked(content.value)
})

onMounted(async () => {
  const id = pageId()
  if (!id) return
  
  await notesStore.fetchPage(id)
  if (notesStore.currentPage) {
    title.value = notesStore.currentPage.title
    content.value = notesStore.currentPage.content || ''
    tagIds.value = new Set(notesStore.currentPage.tags.map(t => t.id))
  }
  // Mark as initialized after loading to enable auto-save
  initialized.value = true
})

const debouncedSave = debounce(async () => {
  const id = pageId()
  if (!id || !title.value.trim()) return
  
  // Save template
  pageTitleTemplate.save(title.value)

  saving.value = true
  try {
    await notesStore.updatePage(id, {
      title: title.value,
      content: content.value,
      tag_ids: Array.from(tagIds.value)
    })
    lastSaved.value = new Date()
  } finally {
    saving.value = false
  }
}, 1000)

// Only start watching after mount (when page data is loaded)
const initialized = ref(false)

watch([title, content, tagIds], () => {
  if (initialized.value) {
    debouncedSave()
  }
}, { deep: true })

// Auto-resize textarea to fit content
const autoResizeTextarea = () => {
  const textarea = textareaRef.value
  if (!textarea) return
  // Reset height to allow shrinking
  textarea.style.height = 'auto'
  // Set height to scrollHeight to fit content
  textarea.style.height = `${Math.max(textarea.scrollHeight, 300)}px`
}

watch(content, () => {
  setTimeout(autoResizeTextarea, 0)
})

const deletePage = async () => {
  if (confirm('Are you sure you want to delete this page?')) {
    await notesStore.deletePage(pageId())
    router.push('/notes')
  }
}

const formatLastSaved = () => {
  if (!lastSaved.value) return ''
  return `Saved at ${lastSaved.value.toLocaleTimeString()}`
}

// Markdown toolbar actions
const insertMarkdown = (before: string, after: string = '', placeholder: string = '') => {
  const textarea = textareaRef.value
  if (!textarea) return
  
  const start = textarea.selectionStart
  const end = textarea.selectionEnd
  const selectedText = content.value.substring(start, end)
  const textToInsert = selectedText || placeholder
  
  const newContent = 
    content.value.substring(0, start) + 
    before + textToInsert + after + 
    content.value.substring(end)
  
  content.value = newContent
  
  // Restore cursor position
  setTimeout(() => {
    textarea.focus()
    if (selectedText) {
      textarea.setSelectionRange(start + before.length, start + before.length + selectedText.length)
    } else {
      textarea.setSelectionRange(start + before.length, start + before.length + placeholder.length)
    }
  }, 0)
}

const toolbarActions = [
  { icon: Heading1, label: 'Heading 1', action: () => insertMarkdown('# ', '', 'Heading') },
  { icon: Heading2, label: 'Heading 2', action: () => insertMarkdown('## ', '', 'Heading') },
  { icon: Heading3, label: 'Heading 3', action: () => insertMarkdown('### ', '', 'Heading') },
  { divider: true },
  { icon: Bold, label: 'Bold', action: () => insertMarkdown('**', '**', 'bold text') },
  { icon: Italic, label: 'Italic', action: () => insertMarkdown('*', '*', 'italic text') },
  { icon: Strikethrough, label: 'Strikethrough', action: () => insertMarkdown('~~', '~~', 'strikethrough') },
  { divider: true },
  { icon: List, label: 'Bullet List', action: () => insertMarkdown('- ', '', 'list item') },
  { icon: ListOrdered, label: 'Numbered List', action: () => insertMarkdown('1. ', '', 'list item') },
  { icon: Quote, label: 'Quote', action: () => insertMarkdown('> ', '', 'quote') },
  { divider: true },
  { icon: Link2, label: 'Link', action: () => insertMarkdown('[', '](url)', 'link text') },
  { icon: Image, label: 'Image', action: () => insertMarkdown('![', '](url)', 'alt text') },
  { icon: Minus, label: 'Horizontal Rule', action: () => insertMarkdown('\n---\n', '', '') },
]
</script>

<template>
  <div class="h-full flex flex-col animate-fade-in">
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center gap-4">
        <Button variant="ghost" size="icon" @click="router.push('/notes')">
          <ArrowLeft class="h-5 w-5" />
        </Button>
        </Button>
        <div class="flex-1 w-full max-w-3xl">
          <SearchableInput
            v-model="title"
            class="text-xl font-semibold tracking-tight bg-transparent outline-none border-none focus:ring-0 w-full p-0 h-auto"
            placeholder="Page title"
            :search-function="pageTitleTemplate.search"
            :show-create-option="true"
            @create="title = $event"
          />
          <div class="flex items-center gap-3 mt-1">
             <p class="text-xs text-muted-foreground">
              <span v-if="saving">Saving...</span>
              <span v-else-if="lastSaved">{{ formatLastSaved() }}</span>
            </p>

            <!-- Tags Dropdown -->
            <div class="relative">
              <Button 
                variant="ghost" 
                size="sm" 
                class="h-6 px-2 text-xs text-muted-foreground hover:text-foreground"
                @click="isTagsOpen = !isTagsOpen"
              >
                <TagIcon class="h-3 w-3 mr-1" />
                {{ tagIds.size > 0 ? `${tagIds.size} tags` : 'Add tags' }}
              </Button>
              
              <div 
                v-if="isTagsOpen"
                class="absolute left-0 top-full mt-2 w-80 bg-popover text-popover-foreground border rounded-lg shadow-lg z-50 overflow-hidden"
              >
                <div class="p-3 border-b">
                  <h4 class="font-medium leading-none">Manage Tags</h4>
                </div>
                <div class="p-2">
                  <TagManager
                    v-model:checkedTagIds="tagIds"
                    mode="select"
                    embedded
                    :rows="4"
                  />
                </div>
              </div>
              <div v-if="isTagsOpen" class="fixed inset-0 z-40 bg-transparent" @click="isTagsOpen = false" />
            </div>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <!-- View mode toggle -->
        <div class="flex items-center border border-border rounded-lg p-0.5 bg-secondary/50">
          <button
            :class="[
              'flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-md transition-all',
              viewMode === 'edit' 
                ? 'bg-background text-foreground shadow-sm' 
                : 'text-muted-foreground hover:text-foreground'
            ]"
            @click="viewMode = 'edit'"
          >
            <Code class="h-4 w-4" />
            Edit
          </button>
          <button
            :class="[
              'flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-md transition-all',
              viewMode === 'preview' 
                ? 'bg-background text-foreground shadow-sm' 
                : 'text-muted-foreground hover:text-foreground'
            ]"
            @click="viewMode = 'preview'"
          >
            <Eye class="h-4 w-4" />
            Preview
          </button>
        </div>
        
        <Button variant="ghost" size="icon" class="text-destructive hover:text-destructive" @click="deletePage">
          <Trash class="h-4 w-4" />
        </Button>
      </div>
    </div>

    <!-- Markdown Toolbar (only in edit mode) -->
    <div 
      v-if="viewMode === 'edit'" 
      class="flex items-center gap-0.5 px-2 py-1.5 mb-3 border border-border rounded-xl bg-secondary/30 overflow-x-auto"
    >
      <template v-for="(item, index) in toolbarActions" :key="index">
        <div v-if="item.divider" class="w-px h-5 bg-border mx-1.5" />
        <button
          v-else
          class="p-2 rounded-lg hover:bg-secondary transition-colors text-muted-foreground hover:text-foreground"
          :title="item.label"
          @click="item.action"
        >
          <component :is="item.icon" class="h-4 w-4" />
        </button>
      </template>
    </div>

    <!-- Editor / Preview Container -->
    <div class="flex-1 border border-border rounded-xl overflow-hidden bg-card">
      <!-- Edit Mode -->
      <textarea
        v-if="viewMode === 'edit'"
        ref="textareaRef"
        v-model="content"
        class="w-full p-6 bg-transparent outline-none resize-none font-mono text-sm leading-relaxed min-h-[300px]"
        placeholder="Start writing in markdown...

# Heading 1
## Heading 2

**Bold text** and *italic text*

- Bullet list item
- Another item

1. Numbered list
2. Second item

> Blockquote

[Link text](https://example.com)

---

Use the toolbar above for quick formatting!"
      />
      
      <!-- Preview Mode -->
      <div 
        v-else 
        class="w-full h-full p-6 overflow-auto prose prose-sm dark:prose-invert max-w-none
               prose-headings:font-semibold prose-headings:text-foreground prose-headings:tracking-tight
               prose-p:text-foreground prose-p:leading-relaxed
               prose-a:text-primary prose-a:no-underline hover:prose-a:underline
               prose-strong:text-foreground prose-strong:font-semibold
               prose-code:bg-secondary prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded-md prose-code:text-sm prose-code:before:content-none prose-code:after:content-none
               prose-pre:bg-secondary prose-pre:border prose-pre:border-border prose-pre:rounded-xl
               prose-blockquote:border-l-primary prose-blockquote:text-muted-foreground prose-blockquote:not-italic
               prose-ul:text-foreground prose-ol:text-foreground
               prose-li:text-foreground
               prose-hr:border-border"
        v-html="renderedContent"
      />
    </div>

    <!-- Page Links Section -->
    <div v-if="notesStore.currentPage?.links?.length" class="mt-4">
      <h3 class="text-sm font-medium text-muted-foreground mb-2">Linked Items</h3>
      <div class="flex flex-wrap gap-2">
        <div
          v-for="link in notesStore.currentPage.links"
          :key="link.id"
          class="flex items-center gap-1.5 px-2.5 py-1.5 bg-secondary rounded-lg text-sm"
        >
          <Link2 class="h-3 w-3 text-muted-foreground" />
          <span>{{ link.link_type }}: {{ link.linked_id.slice(0, 8) }}...</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style>
/* Additional prose styles for markdown rendering */
.prose img {
  border-radius: 0.75rem;
  max-width: 100%;
}

.prose table {
  width: 100%;
  border-collapse: collapse;
}

.prose th,
.prose td {
  border: 1px solid hsl(var(--border));
  padding: 0.5rem 0.75rem;
  text-align: left;
}

.prose th {
  background-color: hsl(var(--secondary));
  font-weight: 600;
}
</style>
