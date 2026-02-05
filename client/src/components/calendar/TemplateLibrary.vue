<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { format } from 'date-fns'
import { 
  LayoutTemplate, Plus, X, Play, Clock, 
  ListChecks, ChevronDown, Edit2, Trash2
} from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Select } from '@/components/ui/select'
import { api } from '@/services/api'
import { useCalendarStore } from '@/stores/calendar'
import BaseIconButton from '@/components/shared/BaseIconButton.vue'
import type { TaskTemplate } from '@/types'

const emit = defineEmits<{
  'template-applied': [templateId: string]
  'close': []
}>()

const props = defineProps<{
  defaultDate?: string
}>()

const calendarStore = useCalendarStore()

const templates = ref<TaskTemplate[]>([])
const loading = ref(false)
const showCreateModal = ref(false)
const showEditModal = ref(false)
const editingTemplate = ref<TaskTemplate | null>(null)
const applyingTemplate = ref<string | null>(null)

const newTemplate = ref({
  name: '',
  description: '',
  category: '',
  title: '',
  task_description: '',
  duration_minutes: null as number | null,
  priority: 1,
  task_type: 'todo' as 'todo' | 'timed' | 'floating',
  default_steps: [] as string[]
})

const newStep = ref('')

const categories = ['Work', 'Personal', 'Health', 'Learning', 'Routine', 'Other']

const templatesByCategory = computed(() => {
  const grouped: Record<string, TaskTemplate[]> = {}
  for (const template of templates.value) {
    const category = template.category || 'Uncategorized'
    if (!grouped[category]) grouped[category] = []
    grouped[category].push(template)
  }
  return grouped
})

onMounted(async () => {
  await fetchTemplates()
})

async function fetchTemplates() {
  loading.value = true
  try {
    const response = await api.listTemplates()
    templates.value = response.data
  } finally {
    loading.value = false
  }
}

async function handleCreateTemplate() {
  if (!newTemplate.value.name.trim() || !newTemplate.value.title.trim()) return
  
  await api.createTemplate({
    name: newTemplate.value.name,
    description: newTemplate.value.description || null,
    category: newTemplate.value.category || null,
    title: newTemplate.value.title,
    task_description: newTemplate.value.task_description || null,
    duration_minutes: newTemplate.value.duration_minutes,
    priority: newTemplate.value.priority,
    task_type: newTemplate.value.task_type,
    default_steps: newTemplate.value.default_steps
  })
  
  resetNewTemplate()
  showCreateModal.value = false
  await fetchTemplates()
}

async function handleUpdateTemplate() {
  if (!editingTemplate.value) return
  
  await api.updateTemplate(editingTemplate.value.id, {
    name: editingTemplate.value.name,
    description: editingTemplate.value.description,
    category: editingTemplate.value.category,
    title: editingTemplate.value.title,
    task_description: editingTemplate.value.task_description,
    duration_minutes: editingTemplate.value.duration_minutes,
    priority: editingTemplate.value.priority,
    task_type: editingTemplate.value.task_type,
    default_steps: editingTemplate.value.default_steps
  })
  
  showEditModal.value = false
  editingTemplate.value = null
  await fetchTemplates()
}

async function handleDeleteTemplate(id: string) {
  await api.deleteTemplate(id)
  await fetchTemplates()
}

async function handleApplyTemplate(template: TaskTemplate) {
  const date = props.defaultDate || format(new Date(), 'yyyy-MM-dd')
  applyingTemplate.value = template.id
  
  try {
    const response = await api.applyTemplate(template.id, date)
    // Add to calendar store
    calendarStore.tasks.push(response.data)
    emit('template-applied', template.id)
    emit('close')
  } finally {
    applyingTemplate.value = null
  }
}

function resetNewTemplate() {
  newTemplate.value = {
    name: '',
    description: '',
    category: '',
    title: '',
    task_description: '',
    duration_minutes: null,
    priority: 1,
    task_type: 'todo',
    default_steps: []
  }
  newStep.value = ''
}

function addStep(model: { default_steps: string[] }) {
  if (!newStep.value.trim()) return
  model.default_steps.push(newStep.value.trim())
  newStep.value = ''
}

function removeStep(model: { default_steps: string[] }, index: number) {
  model.default_steps.splice(index, 1)
}

function openEditModal(template: TaskTemplate) {
  editingTemplate.value = { ...template, default_steps: [...template.default_steps] }
  showEditModal.value = true
}
</script>

<template>
  <div class="h-full flex flex-col">
    <!-- Header -->
    <div class="flex items-center justify-between px-4 py-3 border-b border-border">
      <div class="flex items-center gap-2">
        <LayoutTemplate class="h-5 w-5 text-primary" />
        <h2 class="font-semibold">Task Templates</h2>
      </div>
      <div class="flex items-center gap-1">
        <Button size="sm" variant="outline" @click="showCreateModal = true">
          <Plus class="h-4 w-4 mr-1" />
          New
        </Button>
        <Button variant="ghost" size="icon" class="h-8 w-8" @click="emit('close')">
          <X class="h-4 w-4" />
        </Button>
      </div>
    </div>

    <!-- Templates List -->
    <div class="flex-1 overflow-auto p-4">
      <div v-if="loading" class="flex items-center justify-center py-12">
        <div class="h-5 w-5 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
      </div>

      <div v-else-if="templates.length === 0" class="text-center py-12">
        <LayoutTemplate class="h-12 w-12 text-muted-foreground/30 mx-auto mb-3" />
        <p class="font-medium">No templates yet</p>
        <p class="text-sm text-muted-foreground mt-1">Create templates for tasks you repeat often</p>
        <Button variant="outline" class="mt-4" @click="showCreateModal = true">
          <Plus class="h-4 w-4 mr-1.5" />
          Create Template
        </Button>
      </div>

      <div v-else class="space-y-4">
        <div v-for="(categoryTemplates, category) in templatesByCategory" :key="category">
          <h3 class="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-2">{{ category }}</h3>
          <div class="space-y-2">
            <div 
              v-for="template in categoryTemplates" 
              :key="template.id"
              class="p-3 rounded-lg border border-border hover:border-primary/30 hover:bg-secondary/30 transition-all group"
            >
              <div class="flex items-start justify-between gap-2">
                <div class="flex-1 min-w-0">
                  <h4 class="font-medium text-sm">{{ template.name }}</h4>
                  <p class="text-xs text-muted-foreground truncate mt-0.5">{{ template.title }}</p>
                  <div class="flex items-center gap-2 mt-2">
                    <Badge v-if="template.duration_minutes" variant="secondary" class="text-[10px]">
                      <Clock class="h-2.5 w-2.5 mr-0.5" />
                      {{ template.duration_minutes }}m
                    </Badge>
                    <Badge v-if="template.default_steps.length > 0" variant="secondary" class="text-[10px]">
                      <ListChecks class="h-2.5 w-2.5 mr-0.5" />
                      {{ template.default_steps.length }} steps
                    </Badge>
                  </div>
                </div>
                <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <BaseIconButton :icon="Edit2" :adaptive="false" @click.stop="openEditModal(template)" />
                  <BaseIconButton :icon="Trash2" variant="destructive" :adaptive="false" @click.stop="handleDeleteTemplate(template.id)" />
                  <Button 
                    size="sm"
                    class="h-7"
                    :disabled="applyingTemplate === template.id"
                    @click.stop="handleApplyTemplate(template)"
                  >
                    <Play class="h-3 w-3 mr-1" />
                    Use
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Create Modal -->
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
          v-if="showCreateModal"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4"
          @click="showCreateModal = false"
        >
          <div 
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden max-h-[90vh] flex flex-col"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Create Template</h2>
            </div>
            <div class="p-5 space-y-4 overflow-auto flex-1">
              <div class="grid grid-cols-2 gap-4">
                <div class="col-span-2">
                  <label class="text-sm font-medium mb-1.5 block">Template Name</label>
                  <Input v-model="newTemplate.name" placeholder="e.g., Morning Routine" />
                </div>
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Category</label>
                  <Select 
                    v-model="newTemplate.category"
                    :options="[
                      { value: '', label: 'Select category' },
                      ...categories.map(cat => ({ value: cat, label: cat }))
                    ]"
                    placeholder="Select category"
                  />
                </div>
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Task Type</label>
                  <Select 
                    v-model="newTemplate.task_type"
                    :options="[
                      { value: 'todo', label: 'To-do' },
                      { value: 'timed', label: 'Timed' },
                      { value: 'floating', label: 'Floating' }
                    ]"
                    placeholder="Select type"
                  />
                </div>
              </div>
              
              <div>
                <label class="text-sm font-medium mb-1.5 block">Task Title</label>
                <Input v-model="newTemplate.title" placeholder="Task title when created" />
              </div>
              
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Duration (min)</label>
                  <Input :model-value="newTemplate.duration_minutes ?? ''" @update:model-value="newTemplate.duration_minutes = $event ? Number($event) : null" type="number" placeholder="Optional" />
                </div>
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Priority (1-5)</label>
                  <Input v-model.number="newTemplate.priority" type="number" min="1" max="5" />
                </div>
              </div>

              <div>
                <label class="text-sm font-medium mb-1.5 block">Default Steps</label>
                <div class="space-y-2">
                  <div v-for="(step, index) in newTemplate.default_steps" :key="index" class="flex items-center gap-2">
                    <span class="flex-1 text-sm px-2 py-1 bg-secondary rounded">{{ step }}</span>
                    <Button variant="ghost" size="icon" class="h-7 w-7" @click="removeStep(newTemplate, index)">
                      <X class="h-3 w-3" />
                    </Button>
                  </div>
                  <div class="flex gap-2">
                    <Input 
                      v-model="newStep" 
                      placeholder="Add a step..." 
                      class="flex-1"
                      @keyup.enter="addStep(newTemplate)"
                    />
                    <Button size="sm" variant="outline" @click="addStep(newTemplate)">Add</Button>
                  </div>
                </div>
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showCreateModal = false; resetNewTemplate()">Cancel</Button>
              <Button @click="handleCreateTemplate" :disabled="!newTemplate.name.trim() || !newTemplate.title.trim()">
                Create Template
              </Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Edit Modal (similar structure) -->
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
          v-if="showEditModal && editingTemplate"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4"
          @click="showEditModal = false"
        >
          <div 
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden max-h-[90vh] flex flex-col"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Edit Template</h2>
            </div>
            <div class="p-5 space-y-4 overflow-auto flex-1">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Template Name</label>
                <Input v-model="editingTemplate.name" />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Category</label>
                <Select 
                  :model-value="editingTemplate.category ?? ''"
                  @update:model-value="editingTemplate.category = String($event) || null"
                  :options="[
                    { value: '', label: 'Select category' },
                    ...categories.map(cat => ({ value: cat, label: cat }))
                  ]"
                  placeholder="Select category"
                />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Task Title</label>
                <Input v-model="editingTemplate.title" />
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Duration (min)</label>
                  <Input :model-value="editingTemplate.duration_minutes ?? ''" @update:model-value="editingTemplate.duration_minutes = $event ? Number($event) : null" type="number" />
                </div>
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Priority</label>
                  <Input v-model.number="editingTemplate.priority" type="number" min="1" max="5" />
                </div>
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Default Steps</label>
                <div class="space-y-2">
                  <div v-for="(step, index) in editingTemplate.default_steps" :key="index" class="flex items-center gap-2">
                    <span class="flex-1 text-sm px-2 py-1 bg-secondary rounded">{{ step }}</span>
                    <Button variant="ghost" size="icon" class="h-7 w-7" @click="removeStep(editingTemplate, index)">
                      <X class="h-3 w-3" />
                    </Button>
                  </div>
                  <div class="flex gap-2">
                    <Input 
                      v-model="newStep" 
                      placeholder="Add a step..." 
                      class="flex-1"
                      @keyup.enter="addStep(editingTemplate)"
                    />
                    <Button size="sm" variant="outline" @click="addStep(editingTemplate)">Add</Button>
                  </div>
                </div>
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showEditModal = false">Cancel</Button>
              <Button @click="handleUpdateTemplate">Save Changes</Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

