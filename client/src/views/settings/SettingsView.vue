<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Settings, Trash2, Users, Mail, UserPlus, LogOut, X, Check, Edit2, Inbox } from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { useHouseholdStore } from '@/stores/household'
import { useAuthStore } from '@/stores/auth'

const householdStore = useHouseholdStore()
const authStore = useAuthStore()

const inviteEmail = ref('')
const inviteError = ref('')
const inviteSuccess = ref('')
const editingName = ref(false)
const newHouseholdName = ref('')
const leaveConfirm = ref(false)
const acceptingInviteId = ref<string | null>(null)
const decliningInviteId = ref<string | null>(null)

onMounted(async () => {
  await householdStore.fetchHousehold()
  await householdStore.fetchInvitations()
  await householdStore.fetchReceivedInvitations()
})

async function sendInvite() {
  if (!inviteEmail.value.trim()) return
  
  inviteError.value = ''
  inviteSuccess.value = ''
  
  try {
    await householdStore.sendInvitation(inviteEmail.value.trim())
    inviteSuccess.value = `Invitation sent to ${inviteEmail.value}`
    inviteEmail.value = ''
    setTimeout(() => { inviteSuccess.value = '' }, 5000)
  } catch (err: any) {
    inviteError.value = err.response?.data?.error || 'Failed to send invitation'
  }
}

async function cancelInvite(id: string) {
  try {
    await householdStore.cancelInvitation(id)
  } catch (err) {
    console.error('Failed to cancel invitation:', err)
  }
}

function startEditingName() {
  newHouseholdName.value = householdStore.household?.name || ''
  editingName.value = true
}

async function saveHouseholdName() {
  if (!newHouseholdName.value.trim()) return
  
  try {
    await householdStore.updateHousehold(newHouseholdName.value.trim())
    editingName.value = false
  } catch (err) {
    console.error('Failed to update household name:', err)
  }
}

async function leaveHousehold() {
  try {
    await householdStore.leaveHousehold()
    leaveConfirm.value = false
    // Refresh user data to get new household_id
    await authStore.checkAuth()
  } catch (err) {
    console.error('Failed to leave household:', err)
  }
}

async function acceptReceivedInvite(id: string) {
  acceptingInviteId.value = id
  try {
    await householdStore.acceptInvitation(id)
    // Refresh auth to get new household data
    await authStore.checkAuth()
  } catch (err) {
    console.error('Failed to accept invitation:', err)
  } finally {
    acceptingInviteId.value = null
  }
}

async function declineReceivedInvite(id: string) {
  decliningInviteId.value = id
  try {
    await householdStore.declineInvitation(id)
  } catch (err) {
    console.error('Failed to decline invitation:', err)
  } finally {
    decliningInviteId.value = null
  }
}

function formatDate(dateString: string) {
  return new Date(dateString).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  })
}

function getInitials(name: string | null, email: string) {
  if (name) {
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  }
  return email[0].toUpperCase()
}
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in">
    <!-- Header -->
    <div class="flex items-center gap-3">
      <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
        <Settings class="h-5 w-5 text-primary" />
      </div>
      <div>
        <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Settings</h1>
        <p class="text-sm text-muted-foreground">Manage your household and preferences</p>
      </div>
    </div>

    <div class="grid gap-4">
      <!-- Received Invitations (invitations from others) -->
      <Card v-if="householdStore.receivedInvitations.length > 0" class="border-emerald-500/30 bg-emerald-500/5">
        <CardHeader class="pb-3">
          <div class="flex items-center gap-3">
            <div class="h-9 w-9 rounded-lg bg-emerald-500/10 flex items-center justify-center">
              <Inbox class="h-5 w-5 text-emerald-500" />
            </div>
            <div>
              <CardTitle class="text-base text-emerald-600 dark:text-emerald-400">
                You Have {{ householdStore.receivedInvitations.length }} Invitation{{ householdStore.receivedInvitations.length !== 1 ? 's' : '' }}
              </CardTitle>
              <CardDescription class="text-xs">
                Join another household to share data
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div class="space-y-3">
            <div
              v-for="invitation in householdStore.receivedInvitations"
              :key="invitation.id"
              class="flex items-center justify-between p-4 rounded-lg bg-background border"
            >
              <div class="min-w-0 flex-1">
                <p class="font-medium text-sm">
                  {{ invitation.inviter?.name || invitation.inviter?.email || 'Someone' }} invited you to join
                </p>
                <p class="text-base font-semibold text-primary">
                  {{ invitation.household?.name || 'a household' }}
                </p>
                <p class="text-xs text-muted-foreground mt-1">
                  Expires {{ formatDate(invitation.expires_at) }}
                </p>
              </div>
              <div class="flex gap-2 ml-4">
                <Button
                  variant="outline"
                  size="sm"
                  @click="declineReceivedInvite(invitation.id)"
                  :disabled="decliningInviteId === invitation.id"
                >
                  <X class="h-4 w-4 mr-1" />
                  Decline
                </Button>
                <Button
                  size="sm"
                  @click="acceptReceivedInvite(invitation.id)"
                  :disabled="acceptingInviteId === invitation.id"
                >
                  <Check class="h-4 w-4 mr-1" />
                  Accept
                </Button>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <!-- Household Members -->
      <Card>
        <CardHeader class="pb-3">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="h-9 w-9 rounded-lg bg-primary/10 flex items-center justify-center">
                <Users class="h-5 w-5 text-primary" />
              </div>
              <div>
                <div class="flex items-center gap-2">
                  <CardTitle v-if="!editingName" class="text-base">
                    {{ householdStore.household?.name || 'Your Household' }}
                  </CardTitle>
                  <div v-else class="flex items-center gap-2">
                    <Input
                      v-model="newHouseholdName"
                      class="h-8 w-48"
                      @keyup.enter="saveHouseholdName"
                      @keyup.escape="editingName = false"
                    />
                    <Button size="icon" variant="ghost" class="h-7 w-7" @click="saveHouseholdName">
                      <Check class="h-4 w-4 text-green-500" />
                    </Button>
                    <Button size="icon" variant="ghost" class="h-7 w-7" @click="editingName = false">
                      <X class="h-4 w-4" />
                    </Button>
                  </div>
                  <Button
                    v-if="!editingName"
                    size="icon"
                    variant="ghost"
                    class="h-7 w-7"
                    @click="startEditingName"
                  >
                    <Edit2 class="h-3.5 w-3.5 text-muted-foreground" />
                  </Button>
                </div>
                <CardDescription class="text-xs">
                  {{ householdStore.memberCount }} member{{ householdStore.memberCount !== 1 ? 's' : '' }}
                </CardDescription>
              </div>
            </div>
          </div>
        </CardHeader>
        <CardContent class="space-y-4">
          <!-- Members List -->
          <div class="space-y-2">
            <div
              v-for="member in householdStore.members"
              :key="member.id"
              class="flex items-center gap-3 p-3 rounded-lg bg-muted/50"
            >
              <div
                v-if="member.avatar_url"
                class="h-10 w-10 rounded-full bg-cover bg-center"
                :style="{ backgroundImage: `url(${member.avatar_url})` }"
              />
              <div
                v-else
                class="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-medium text-sm"
              >
                {{ getInitials(member.name, member.email) }}
              </div>
              <div class="flex-1 min-w-0">
                <p class="font-medium text-sm truncate">{{ member.name || member.email }}</p>
                <p class="text-xs text-muted-foreground truncate">{{ member.email }}</p>
              </div>
              <div v-if="member.id === authStore.user?.id" class="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary">
                You
              </div>
            </div>
          </div>

          <!-- Leave Household Button (only if not alone) -->
          <div v-if="householdStore.memberCount > 1" class="pt-2 border-t">
            <div v-if="!leaveConfirm" class="flex items-center justify-between">
              <p class="text-sm text-muted-foreground">Leave this household and create your own</p>
              <Button variant="outline" size="sm" @click="leaveConfirm = true">
                <LogOut class="h-4 w-4 mr-2" />
                Leave Household
              </Button>
            </div>
            <div v-else class="flex items-center justify-between p-3 rounded-lg bg-orange-500/10 border border-orange-500/20">
              <p class="text-sm text-orange-600 dark:text-orange-400">
                Are you sure? Your data will move to a new household.
              </p>
              <div class="flex gap-2">
                <Button variant="ghost" size="sm" @click="leaveConfirm = false">Cancel</Button>
                <Button variant="destructive" size="sm" @click="leaveHousehold" :disabled="householdStore.loading">
                  Confirm Leave
                </Button>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <!-- Invite Member -->
      <Card>
        <CardHeader class="pb-3">
          <div class="flex items-center gap-3">
            <div class="h-9 w-9 rounded-lg bg-emerald-500/10 flex items-center justify-center">
              <UserPlus class="h-5 w-5 text-emerald-500" />
            </div>
            <div>
              <CardTitle class="text-base">Invite Member</CardTitle>
              <CardDescription class="text-xs">
                Send an invitation to join your household
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div class="space-y-3">
            <div class="flex gap-2">
              <Input
                v-model="inviteEmail"
                type="email"
                placeholder="Enter email address"
                class="flex-1"
                @keyup.enter="sendInvite"
              />
              <Button @click="sendInvite" :disabled="!inviteEmail.trim() || householdStore.loading">
                <Mail class="h-4 w-4 mr-2" />
                Send Invite
              </Button>
            </div>
            <p v-if="inviteError" class="text-sm text-red-500">{{ inviteError }}</p>
            <p v-if="inviteSuccess" class="text-sm text-green-500">{{ inviteSuccess }}</p>
          </div>
        </CardContent>
      </Card>

      <!-- Pending Invitations -->
      <Card v-if="householdStore.invitations.length > 0">
        <CardHeader class="pb-3">
          <div class="flex items-center gap-3">
            <div class="h-9 w-9 rounded-lg bg-amber-500/10 flex items-center justify-center">
              <Mail class="h-5 w-5 text-amber-500" />
            </div>
            <div>
              <CardTitle class="text-base">Pending Invitations</CardTitle>
              <CardDescription class="text-xs">
                {{ householdStore.invitations.length }} invitation{{ householdStore.invitations.length !== 1 ? 's' : '' }} waiting
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div class="space-y-2">
            <div
              v-for="invitation in householdStore.invitations"
              :key="invitation.id"
              class="flex items-center justify-between p-3 rounded-lg bg-muted/50"
            >
              <div class="min-w-0">
                <p class="font-medium text-sm truncate">{{ invitation.email }}</p>
                <p class="text-xs text-muted-foreground">
                  Expires {{ formatDate(invitation.expires_at) }}
                </p>
              </div>
              <Button
                variant="ghost"
                size="icon"
                class="h-8 w-8 text-muted-foreground hover:text-destructive"
                @click="cancelInvite(invitation.id)"
              >
                <X class="h-4 w-4" />
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      <!-- Danger Zone -->
      <Card class="border-destructive/20">
        <CardHeader class="pb-3">
          <div class="flex items-center gap-3">
            <div class="h-9 w-9 rounded-lg bg-destructive/10 flex items-center justify-center">
              <Trash2 class="h-5 w-5 text-destructive" />
            </div>
            <div>
              <CardTitle class="text-base text-destructive">Danger Zone</CardTitle>
              <CardDescription class="text-xs">
                Irreversible actions that affect your account
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 p-4 rounded-xl bg-destructive/5 border border-destructive/10">
            <div>
              <p class="font-medium text-sm">Delete all data</p>
              <p class="text-xs text-muted-foreground mt-0.5">
                Permanently remove all tasks, inventory, budget entries, and notes
              </p>
            </div>
            <Button variant="destructive" disabled size="sm" class="shrink-0">
              <Trash2 class="h-4 w-4 mr-2" />
              Delete All
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  </div>
</template>
