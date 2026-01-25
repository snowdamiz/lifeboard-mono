<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { ArrowLeft, Plus, Trash, Edit, TrendingUp, TrendingDown, Eye } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Select } from '@/components/ui/select'
import { useBudgetStore } from '@/stores/budget'
import { useTagsStore } from '@/stores/tags'
import { formatCurrency } from '@/lib/utils'
import CollapsibleTagManager from '@/components/shared/CollapsibleTagManager.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import SourceDetailModal from '@/components/budget/SourceDetailModal.vue'
import { api } from '@/services/api'
import type { BudgetSource, Tag } from '@/types'

const router = useRouter()
const budgetStore = useBudgetStore()
const tagsStore = useTagsStore()
const showForm = ref(false)
const editingSource = ref<BudgetSource | null>(null)
const showSourceDetail = ref(false)
const selectedSource = ref<BudgetSource | null>(null)

const openSourceDetail = (source: BudgetSource) => {
  selectedSource.value = source
  showSourceDetail.value = true
}

const handleSourceDetailRefresh = async () => {
  await budgetStore.fetchSources()
}

const form = ref({
  name: '',
  type: 'expense' as 'income' | 'expense',
  amount: '',
  tagIds: new Set<string>()
})

const resolvedTags = computed(() => {
  return Array.from(form.value.tagIds)
    .map(id => tagsStore.tags.find((t: Tag) => t.id === id))
    .filter((t): t is Tag => t !== undefined)
})

onMounted(() => {
  budgetStore.fetchSources()
})

// Search function for source names using text templates
const searchSourceNames = async (query: string) => {
  const response = await api.suggestTemplates('budget_source_name', query)
  return response.data
}

const deleteSourceNameTemplate = async (value: string) => {
  try {
    await api.deleteTextTemplate('budget_source_name', value)
    return true
  } catch {
    return false
  }
}

// When a source name is selected from autocomplete, load the existing source's parameters
const onSourceNameSelect = (selectedName: string) => {
  // Find an existing source with this name to pre-fill the form
  const existingSource = budgetStore.sources.find(s => s.name === selectedName)
  if (existingSource) {
    form.value.type = existingSource.type
    form.value.amount = existingSource.amount
    form.value.tagIds = new Set(existingSource.tags.map(t => t.id))
  }
}

const resetForm = () => {
  form.value = { name: '', type: 'expense', amount: '', tagIds: new Set() }
  editingSource.value = null
}

const openNewSource = () => {
  resetForm()
  showForm.value = true
}

const openEdit = (source: BudgetSource) => {
  editingSource.value = source
  form.value = {
    name: source.name,
    type: source.type,
    amount: source.amount,
    tagIds: new Set(source.tags.map(t => t.id))
  }
  showForm.value = true
}

const saveSource = async () => {
  if (!form.value.name.trim()) return

  const data = {
    name: form.value.name,
    type: form.value.type,
    amount: form.value.amount || '0',
    tag_ids: Array.from(form.value.tagIds)
  }

  if (editingSource.value) {
    await budgetStore.updateSource(editingSource.value.id, data)
  } else {
    await budgetStore.createSource(data)
    // Save the source name as a template for future autocomplete
    try {
      await api.saveTemplate('budget_source_name', form.value.name.trim())
    } catch (e) {
      // Ignore errors - template already exists or other non-critical issues
    }
  }

  showForm.value = false
  resetForm()
}

const deleteSource = async (id: string) => {
  await budgetStore.deleteSource(id)
}

const totalIncome = computed(() => 
  budgetStore.incomeSources.reduce((sum, s) => sum + parseFloat(s.amount), 0)
)

const totalExpense = computed(() => 
  budgetStore.expenseSources.reduce((sum, s) => sum + parseFloat(s.amount), 0)
)
</script>

<template>
  <div class="space-y-6 animate-fade-in">
    <div class="flex items-center gap-3 sm:gap-4">
      <Button variant="ghost" size="icon" class="shrink-0" @click="router.push('/budget')">
        <ArrowLeft class="h-5 w-5" />
      </Button>
      <div class="flex-1 min-w-0">
        <h1 class="text-lg sm:text-2xl font-semibold tracking-tight">Budget Sources</h1>
        <p class="text-muted-foreground text-xs sm:text-sm mt-0.5">Manage income and expense sources</p>
      </div>
      <Button size="sm" class="shrink-0" @click="openNewSource">
        <Plus class="h-4 w-4 sm:mr-2" />
        <span class="hidden sm:inline">Add Source</span>
      </Button>
    </div>

    <div class="grid gap-4 sm:gap-6 grid-cols-1 md:grid-cols-2">
      <!-- Income Sources -->
      <Card>
        <CardHeader>
          <div class="flex items-center justify-between">
            <CardTitle class="flex items-center gap-2 text-base font-medium">
              <div class="h-8 w-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                <TrendingUp class="h-4 w-4 text-emerald-600" />
              </div>
              Income Sources
            </CardTitle>
            <span class="text-lg font-semibold text-emerald-600">{{ formatCurrency(totalIncome) }}</span>
          </div>
        </CardHeader>
        <CardContent class="space-y-2">
          <div
            v-for="source in budgetStore.incomeSources"
            :key="source.id"
            class="flex items-center justify-between p-3 rounded-xl bg-emerald-500/5 border border-emerald-500/15"
          >
            <div class="flex-1 min-w-0">
              <p class="font-medium">{{ source.name }}</p>
              <div class="flex items-center gap-2 mt-1 flex-wrap">
                <span class="text-sm text-muted-foreground">{{ formatCurrency(source.amount) }}</span>
                <Badge
                  v-for="tag in source.tags"
                  :key="tag.id"
                  :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                  variant="outline"
                  class="text-[10px] px-1.5 h-5"
                >
                  {{ tag.name }}
                </Badge>
              </div>
            </div>
            <div class="flex items-center gap-1 shrink-0">
              <Button variant="ghost" size="icon" class="h-8 w-8" @click="openEdit(source)">
                <Edit class="h-4 w-4" />
              </Button>
              <Button variant="ghost" size="icon" class="h-8 w-8 text-destructive hover:text-destructive" @click="deleteSource(source.id)">
                <Trash class="h-4 w-4" />
              </Button>
            </div>
          </div>
          <div v-if="budgetStore.incomeSources.length === 0" class="text-center py-6 text-muted-foreground text-sm">
            No income sources yet
          </div>
        </CardContent>
      </Card>

      <!-- Expense Sources -->
      <Card>
        <CardHeader>
          <div class="flex items-center justify-between">
            <CardTitle class="flex items-center gap-2 text-base font-medium">
              <div class="h-8 w-8 rounded-lg bg-red-500/10 flex items-center justify-center">
                <TrendingDown class="h-4 w-4 text-red-600" />
              </div>
              Expense Sources
            </CardTitle>
            <span class="text-lg font-semibold text-red-600">{{ formatCurrency(totalExpense) }}</span>
          </div>
        </CardHeader>
        <CardContent class="space-y-2">
          <div
            v-for="source in budgetStore.expenseSources"
            :key="source.id"
            class="flex items-center justify-between p-3 rounded-xl bg-red-500/5 border border-red-500/15 cursor-pointer hover:border-red-500/30 transition-colors"
            @click="openSourceDetail(source)"
          >
            <div class="flex-1 min-w-0">
              <p class="font-medium">{{ source.name }}</p>
              <div class="flex items-center gap-2 mt-1 flex-wrap">
                <span class="text-sm text-muted-foreground">{{ formatCurrency(source.amount) }}</span>
                <Badge
                  v-for="tag in source.tags"
                  :key="tag.id"
                  :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                  variant="outline"
                  class="text-[10px] px-1.5 h-5"
                >
                  {{ tag.name }}
                </Badge>
              </div>
            </div>
            <div class="flex items-center gap-1">
              <Button variant="ghost" size="icon" class="h-8 w-8" @click.stop="openSourceDetail(source)" title="View purchases">
                <Eye class="h-4 w-4" />
              </Button>
              <Button variant="ghost" size="icon" class="h-8 w-8" @click.stop="openEdit(source)">
                <Edit class="h-4 w-4" />
              </Button>
              <Button variant="ghost" size="icon" class="h-8 w-8 text-destructive hover:text-destructive" @click.stop="deleteSource(source.id)">
                <Trash class="h-4 w-4" />
              </Button>
            </div>
          </div>
          <div v-if="budgetStore.expenseSources.length === 0" class="text-center py-6 text-muted-foreground text-sm">
            No expense sources yet
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Add/Edit Source Modal -->
    <Teleport to="body">
      <div 
        v-if="showForm" 
        class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
        @click="showForm = false"
      >
        <Card class="w-full sm:max-w-md shadow-xl animate-slide-up rounded-t-2xl sm:rounded-xl" @click.stop>
          <CardContent class="p-4 sm:p-6">
            <h2 class="text-lg font-semibold mb-5">
              {{ editingSource ? 'Edit Source' : 'Add Source' }}
            </h2>
            <form class="space-y-4" @submit.prevent="saveSource">
              <div>
                <label class="text-sm font-medium">Name</label>
                <SearchableInput
                  v-model="form.name"
                  placeholder="e.g., Salary, Rent"
                  :search-function="searchSourceNames"
                  :on-delete="deleteSourceNameTemplate"
                  @select="onSourceNameSelect"
                  class="mt-1.5"
                />
              </div>
              <div>
                <label class="text-sm font-medium">Type</label>
                <Select
                  v-model="form.type"
                  :options="[
                    { value: 'income', label: 'Income' },
                    { value: 'expense', label: 'Expense' }
                  ]"
                  placeholder="Select type"
                  class="mt-1.5"
                />
              </div>
              <div>
                <label class="text-sm font-medium">Amount</label>
                <Input v-model="form.amount" type="number" step="0.01" min="0" placeholder="0.00" class="mt-1.5" />
              </div>
              <div>
                <CollapsibleTagManager
                  :applied-tag-ids="form.tagIds"
                  :tags="resolvedTags"
                  :reset-trigger="!showForm"
                  @add-tags="(tags) => tags.forEach(id => form.tagIds.add(id))"
                  @remove-tag="(id) => form.tagIds.delete(id)"
                />
              </div>
              <div class="flex gap-3 pt-2">
                <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="showForm = false">Cancel</Button>
                <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto" :disabled="!form.name.trim()">
                  {{ editingSource ? 'Save' : 'Add' }}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    </Teleport>

    <!-- Source Detail Modal -->
    <SourceDetailModal
      v-if="showSourceDetail && selectedSource"
      :source="selectedSource"
      @close="showSourceDetail = false; selectedSource = null"
      @refresh="handleSourceDetailRefresh"
    />
  </div>
</template>
