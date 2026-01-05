import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { api } from '@/services/api'
import type { Household, HouseholdInvitation, ReceivedInvitation } from '@/types'

export const useHouseholdStore = defineStore('household', () => {
  const household = ref<Household | null>(null)
  const invitations = ref<HouseholdInvitation[]>([]) // Invitations sent by this household
  const receivedInvitations = ref<ReceivedInvitation[]>([]) // Invitations received by the user
  const loading = ref(false)
  const error = ref<string | null>(null)

  const members = computed(() => household.value?.members || [])
  const memberCount = computed(() => members.value.length)
  const hasReceivedInvitations = computed(() => receivedInvitations.value.length > 0)

  async function fetchHousehold() {
    loading.value = true
    error.value = null
    try {
      const response = await api.get<{ data: Household }>('/household')
      household.value = response.data
    } catch (err: any) {
      error.value = err.message || 'Failed to fetch household'
      throw err
    } finally {
      loading.value = false
    }
  }

  async function updateHousehold(name: string) {
    loading.value = true
    error.value = null
    try {
      const response = await api.put<{ data: Household }>('/household', {
        household: { name }
      })
      household.value = response.data
      return response.data
    } catch (err: any) {
      error.value = err.message || 'Failed to update household'
      throw err
    } finally {
      loading.value = false
    }
  }

  async function fetchInvitations() {
    try {
      const response = await api.get<{ data: HouseholdInvitation[] }>('/household/invitations')
      invitations.value = response.data
    } catch (err: any) {
      console.error('Failed to fetch invitations:', err)
    }
  }

  async function sendInvitation(email: string) {
    loading.value = true
    error.value = null
    try {
      const response = await api.post<{ data: HouseholdInvitation }>('/household/invite', { email })
      invitations.value.push(response.data)
      return response.data
    } catch (err: any) {
      error.value = err.message || 'Failed to send invitation'
      throw err
    } finally {
      loading.value = false
    }
  }

  async function cancelInvitation(id: string) {
    loading.value = true
    error.value = null
    try {
      await api.delete(`/household/invitations/${id}`)
      invitations.value = invitations.value.filter(inv => inv.id !== id)
    } catch (err: any) {
      error.value = err.response?.data?.error || 'Failed to cancel invitation'
      throw err
    } finally {
      loading.value = false
    }
  }

  async function fetchReceivedInvitations() {
    try {
      const response = await api.get<{ data: ReceivedInvitation[] }>('/invitations')
      receivedInvitations.value = response.data
    } catch (err: any) {
      console.error('Failed to fetch received invitations:', err)
    }
  }

  async function leaveHousehold() {
    loading.value = true
    error.value = null
    try {
      const response = await api.post<{ data: Household; message: string }>('/household/leave')
      household.value = response.data
      invitations.value = []
      return response
    } catch (err: any) {
      error.value = err.message || 'Failed to leave household'
      throw err
    } finally {
      loading.value = false
    }
  }

  async function acceptInvitation(id: string) {
    loading.value = true
    error.value = null
    try {
      const response = await api.post<{ data: Household; message: string }>(`/invitations/${id}/accept`)
      household.value = response.data
      receivedInvitations.value = receivedInvitations.value.filter(inv => inv.id !== id)
      return response
    } catch (err: any) {
      error.value = err.message || 'Failed to accept invitation'
      throw err
    } finally {
      loading.value = false
    }
  }

  async function declineInvitation(id: string) {
    loading.value = true
    error.value = null
    try {
      await api.post(`/invitations/${id}/decline`)
      receivedInvitations.value = receivedInvitations.value.filter(inv => inv.id !== id)
    } catch (err: any) {
      error.value = err.message || 'Failed to decline invitation'
      throw err
    } finally {
      loading.value = false
    }
  }

  function $reset() {
    household.value = null
    invitations.value = []
    receivedInvitations.value = []
    loading.value = false
    error.value = null
  }

  return {
    // State
    household,
    invitations,
    receivedInvitations,
    loading,
    error,
    // Computed
    members,
    memberCount,
    hasReceivedInvitations,
    // Actions
    fetchHousehold,
    updateHousehold,
    fetchInvitations,
    sendInvitation,
    cancelInvitation,
    fetchReceivedInvitations,
    leaveHousehold,
    acceptInvitation,
    declineInvitation,
    $reset
  }
})

