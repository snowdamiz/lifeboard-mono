import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Notebook, Page } from '@/types'
import { api } from '@/services/api'

export const useNotesStore = defineStore('notes', () => {
  const notebooks = ref<Notebook[]>([])
  const currentNotebook = ref<Notebook | null>(null)
  const pages = ref<Page[]>([])
  const currentPage = ref<Page | null>(null)
  const loading = ref(false)

  async function fetchNotebooks() {
    loading.value = true
    try {
      const response = await api.listNotebooks()
      notebooks.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function fetchNotebook(id: string) {
    const response = await api.getNotebook(id)
    currentNotebook.value = response.data
    return response.data
  }

  async function createNotebook(name: string) {
    const response = await api.createNotebook({ name })
    notebooks.value.push(response.data)
    return response.data
  }

  async function updateNotebook(id: string, updates: Partial<Notebook>) {
    const response = await api.updateNotebook(id, updates)
    const index = notebooks.value.findIndex(n => n.id === id)
    if (index !== -1) {
      notebooks.value[index] = response.data
    }
    if (currentNotebook.value?.id === id) {
      currentNotebook.value = response.data
    }
    return response.data
  }

  async function deleteNotebook(id: string) {
    await api.deleteNotebook(id)
    notebooks.value = notebooks.value.filter(n => n.id !== id)
    if (currentNotebook.value?.id === id) {
      currentNotebook.value = null
    }
  }

  async function fetchPages(notebookId: string) {
    loading.value = true
    try {
      const response = await api.listPages(notebookId)
      pages.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function fetchPage(id: string) {
    loading.value = true
    try {
      const response = await api.getPage(id)
      currentPage.value = response.data
      return response.data
    } finally {
      loading.value = false
    }
  }

  async function createPage(notebookId: string, title: string, content?: string) {
    const response = await api.createPage(notebookId, { title, content })
    pages.value.unshift(response.data)
    return response.data
  }

  async function updatePage(id: string, updates: Partial<Page>) {
    const response = await api.updatePage(id, updates)
    const index = pages.value.findIndex(p => p.id === id)
    if (index !== -1) {
      pages.value[index] = response.data
    }
    if (currentPage.value?.id === id) {
      currentPage.value = response.data
    }
    return response.data
  }

  async function deletePage(id: string) {
    await api.deletePage(id)
    pages.value = pages.value.filter(p => p.id !== id)
    if (currentPage.value?.id === id) {
      currentPage.value = null
    }
  }

  return {
    notebooks,
    currentNotebook,
    pages,
    currentPage,
    loading,
    fetchNotebooks,
    fetchNotebook,
    createNotebook,
    updateNotebook,
    deleteNotebook,
    fetchPages,
    fetchPage,
    createPage,
    updatePage,
    deletePage
  }
})

