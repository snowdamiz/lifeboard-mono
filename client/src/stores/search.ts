import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { SearchResults } from '@/types'
import { api } from '@/services/api'

export const useSearchStore = defineStore('search', () => {
  const query = ref('')
  const results = ref<SearchResults | null>(null)
  const loading = ref(false)
  const isOpen = ref(false)

  async function search(searchQuery: string) {
    if (!searchQuery.trim()) {
      results.value = null
      return
    }

    query.value = searchQuery
    loading.value = true

    try {
      const response = await api.search(searchQuery)
      results.value = response.data
    } finally {
      loading.value = false
    }
  }

  function clearSearch() {
    query.value = ''
    results.value = null
  }

  function openSearch() {
    isOpen.value = true
  }

  function closeSearch() {
    isOpen.value = false
    clearSearch()
  }

  return {
    query,
    results,
    loading,
    isOpen,
    search,
    clearSearch,
    openSearch,
    closeSearch
  }
})

