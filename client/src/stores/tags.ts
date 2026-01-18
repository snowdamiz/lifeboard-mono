import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Tag } from '@/types'
import { api } from '@/services/api'

interface TagWithUsage {
    id: string
    name: string
    color: string
    usage: {
        tasks: number
        goals: number
        pages: number
        habits: number
        inventory_items: number
        budget_sources: number
    }
    total_usage: number
}

interface TagSearchResults {
    tasks: Array<{ id: string; title: string; description: string | null; date: string | null; status: string; task_type: string }>
    goals: Array<{ id: string; title: string; description: string | null; status: string; progress: number }>
    pages: Array<{ id: string; title: string; content: string | null }>
    habits: Array<{ id: string; name: string; description: string | null; frequency: string; streak_count: number }>
    inventory_items: Array<{ id: string; name: string; quantity: number }>
    budget_sources: Array<{ id: string; name: string; type: string; amount: string }>
}

export const useTagsStore = defineStore('tags', () => {
    const tags = ref<Tag[]>([])
    const tagsWithUsage = ref<TagWithUsage[]>([])
    const loading = ref(false)
    const searchResults = ref<TagSearchResults | null>(null)
    const selectedTagIds = ref<string[]>([])

    // Computed
    const sortedTags = computed(() => {
        return [...tags.value].sort((a, b) => a.name.localeCompare(b.name))
    })

    const sortedTagsByUsage = computed(() => {
        return [...tagsWithUsage.value].sort((a, b) => b.total_usage - a.total_usage)
    })

    const getTagById = computed(() => (id: string) => {
        return tags.value.find(t => t.id === id)
    })

    // Actions
    async function fetchTags() {
        loading.value = true
        try {
            const response = await api.listTags()
            tags.value = response.data
        } finally {
            loading.value = false
        }
    }

    async function fetchTagsWithUsage() {
        loading.value = true
        try {
            const response = await api.get<{ data: TagWithUsage[] }>('/tags?with_usage=true')
            tagsWithUsage.value = response.data
        } finally {
            loading.value = false
        }
    }

    async function createTag(tag: Partial<Tag>) {
        const response = await api.createTag(tag)
        tags.value.push(response.data)
        return response.data
    }

    async function updateTag(id: string, updates: Partial<Tag>) {
        const response = await api.updateTag(id, updates)
        const index = tags.value.findIndex(t => t.id === id)
        if (index !== -1) {
            tags.value[index] = response.data
        }
        return response.data
    }

    async function deleteTag(id: string) {
        await api.deleteTag(id)
        tags.value = tags.value.filter(t => t.id !== id)
        tagsWithUsage.value = tagsWithUsage.value.filter(t => t.id !== id)
    }

    async function searchByTags(tagIds: string[], mode: 'any' | 'all' = 'any') {
        if (tagIds.length === 0) {
            searchResults.value = null
            return
        }

        loading.value = true
        try {
            const response = await api.get<{ data: TagSearchResults }>(
                `/tags/search?tag_ids=${tagIds.join(',')}&mode=${mode}`
            )
            searchResults.value = response.data
            return response.data
        } finally {
            loading.value = false
        }
    }

    async function getTagItems(tagId: string) {
        const response = await api.get<{
            data: {
                tag: Tag
                items: TagSearchResults
            }
        }>(`/tags/${tagId}/items`)
        return response.data
    }

    async function createTasksFromTags(
        tagIds: string[],
        options: {
            date?: string
            includeTypes?: ('goals' | 'habits')[]
        } = {}
    ) {
        const params: Record<string, string> = {
            tag_ids: tagIds.join(',')
        }

        if (options.date) {
            params.date = options.date
        }

        if (options.includeTypes) {
            params.include_types = options.includeTypes.join(',')
        }

        const response = await api.post<{ data: Array<{ id: string; title: string }> }>(
            '/tags/create-tasks',
            params
        )
        return response.data
    }

    function selectTag(tagId: string) {
        if (!selectedTagIds.value.includes(tagId)) {
            selectedTagIds.value.push(tagId)
        }
    }

    function deselectTag(tagId: string) {
        selectedTagIds.value = selectedTagIds.value.filter(id => id !== tagId)
    }

    function clearSelection() {
        selectedTagIds.value = []
        searchResults.value = null
    }

    function clearSearchResults() {
        searchResults.value = null
    }

    return {
        tags,
        tagsWithUsage,
        loading,
        searchResults,
        selectedTagIds,
        sortedTags,
        sortedTagsByUsage,
        getTagById,
        fetchTags,
        fetchTagsWithUsage,
        createTag,
        updateTag,
        deleteTag,
        searchByTags,
        getTagItems,
        createTasksFromTags,
        selectTag,
        deselectTag,
        clearSelection,
        clearSearchResults
    }
})
