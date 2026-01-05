import type {
  User,
  Task,
  TaskStep,
  Tag,
  InventorySheet,
  InventoryItem,
  ShoppingList,
  ShoppingListItem,
  BudgetSource,
  BudgetEntry,
  BudgetSummary,
  Notebook,
  Page,
  SearchResults,
  Notification,
  NotificationPreferences,
  Goal,
  GoalCategory,
  GoalHistoryItem,
  Milestone,
  Habit,
  HabitCompletion,
  TaskTemplate,
  UserPreferences,
  ApiResponse
} from '@/types'

const API_BASE = import.meta.env.VITE_API_URL ? `${import.meta.env.VITE_API_URL}/api` : '/api'
const AUTH_BASE = import.meta.env.VITE_API_URL || ''

class ApiClient {
  private accessToken: string | null = null
  private refreshToken: string | null = null
  private isRefreshing = false
  private refreshPromise: Promise<boolean> | null = null

  // Callback to notify auth store of token updates
  onTokenRefresh: ((newAccessToken: string) => void) | null = null

  setTokens(accessToken: string | null, refreshToken: string | null) {
    this.accessToken = accessToken
    this.refreshToken = refreshToken
  }

  updateAccessToken(accessToken: string) {
    this.accessToken = accessToken
  }

  getAccessToken(): string | null {
    return this.accessToken
  }

  // Legacy support
  setToken(token: string | null) {
    this.accessToken = token
  }

  private async tryRefreshToken(): Promise<boolean> {
    if (!this.refreshToken) {
      return false
    }

    // Prevent multiple simultaneous refresh attempts
    if (this.isRefreshing && this.refreshPromise) {
      return this.refreshPromise
    }

    this.isRefreshing = true
    this.refreshPromise = (async () => {
      try {
        const response = await fetch(`${AUTH_BASE}/auth/refresh`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: this.refreshToken })
        })

        if (!response.ok) {
          // Refresh token is invalid or expired
          this.accessToken = null
          this.refreshToken = null
          return false
        }

        const data = await response.json()
        const newAccessToken = data.data?.access_token

        if (newAccessToken) {
          this.accessToken = newAccessToken
          // Notify auth store to update localStorage
          if (this.onTokenRefresh) {
            this.onTokenRefresh(newAccessToken)
          }
          return true
        }

        return false
      } catch {
        return false
      } finally {
        this.isRefreshing = false
        this.refreshPromise = null
      }
    })()

    return this.refreshPromise
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {},
    isRetry = false
  ): Promise<T> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...((options.headers as Record<string, string>) || {})
    }

    if (this.accessToken) {
      headers['Authorization'] = `Bearer ${this.accessToken}`
    }

    const response = await fetch(`${API_BASE}${endpoint}`, {
      ...options,
      headers
    })

    // If unauthorized and we haven't retried yet, try to refresh the token
    if (response.status === 401 && !isRetry && this.refreshToken) {
      const refreshed = await this.tryRefreshToken()
      if (refreshed) {
        // Retry the original request with new token
        return this.request<T>(endpoint, options, true)
      }
    }

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }))
      throw new Error(error.error || 'Request failed')
    }

    if (response.status === 204) {
      return {} as T
    }

    return response.json()
  }

  // Auth
  async me(): Promise<ApiResponse<User>> {
    return this.request('/me')
  }

  // User Preferences
  async getPreferences(): Promise<ApiResponse<UserPreferences>> {
    return this.request('/preferences')
  }

  async updatePreferences(preferences: Partial<UserPreferences>): Promise<ApiResponse<UserPreferences>> {
    return this.request('/preferences', {
      method: 'PUT',
      body: JSON.stringify({ preferences })
    })
  }

  // Tasks
  async listTasks(params?: {
    start_date?: string
    end_date?: string
    status?: string
  }): Promise<ApiResponse<Task[]>> {
    const searchParams = new URLSearchParams()
    if (params?.start_date) searchParams.set('start_date', params.start_date)
    if (params?.end_date) searchParams.set('end_date', params.end_date)
    if (params?.status) searchParams.set('status', params.status)
    
    const query = searchParams.toString()
    return this.request(`/tasks${query ? `?${query}` : ''}`)
  }

  async getTask(id: string): Promise<ApiResponse<Task>> {
    return this.request(`/tasks/${id}`)
  }

  async createTask(task: Partial<Task>): Promise<ApiResponse<Task>> {
    return this.request('/tasks', {
      method: 'POST',
      body: JSON.stringify({ task })
    })
  }

  async updateTask(id: string, task: Partial<Task>): Promise<ApiResponse<Task>> {
    return this.request(`/tasks/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ task })
    })
  }

  async deleteTask(id: string): Promise<void> {
    return this.request(`/tasks/${id}`, { method: 'DELETE' })
  }

  async reorderTasks(taskId: string, taskIds: string[]): Promise<void> {
    return this.request(`/tasks/${taskId}/reorder`, {
      method: 'PUT',
      body: JSON.stringify({ task_ids: taskIds })
    })
  }

  // Task Steps
  async createTaskStep(taskId: string, step: Partial<TaskStep>): Promise<ApiResponse<TaskStep>> {
    return this.request(`/tasks/${taskId}/steps`, {
      method: 'POST',
      body: JSON.stringify({ step })
    })
  }

  async updateTaskStep(taskId: string, stepId: string, step: Partial<TaskStep>): Promise<ApiResponse<TaskStep>> {
    return this.request(`/tasks/${taskId}/steps/${stepId}`, {
      method: 'PUT',
      body: JSON.stringify({ step })
    })
  }

  async deleteTaskStep(taskId: string, stepId: string): Promise<void> {
    return this.request(`/tasks/${taskId}/steps/${stepId}`, { method: 'DELETE' })
  }

  // Inventory Sheets
  async listSheets(): Promise<ApiResponse<InventorySheet[]>> {
    return this.request('/inventory/sheets')
  }

  async getSheet(id: string): Promise<ApiResponse<InventorySheet>> {
    return this.request(`/inventory/sheets/${id}`)
  }

  async createSheet(sheet: Partial<InventorySheet>): Promise<ApiResponse<InventorySheet>> {
    return this.request('/inventory/sheets', {
      method: 'POST',
      body: JSON.stringify({ sheet })
    })
  }

  async updateSheet(id: string, sheet: Partial<InventorySheet>): Promise<ApiResponse<InventorySheet>> {
    return this.request(`/inventory/sheets/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ sheet })
    })
  }

  async deleteSheet(id: string): Promise<void> {
    return this.request(`/inventory/sheets/${id}`, { method: 'DELETE' })
  }

  // Inventory Items
  async createItem(item: Partial<InventoryItem>): Promise<ApiResponse<InventoryItem>> {
    return this.request('/inventory/items', {
      method: 'POST',
      body: JSON.stringify({ item })
    })
  }

  async updateItem(id: string, item: Partial<InventoryItem>): Promise<ApiResponse<InventoryItem>> {
    return this.request(`/inventory/items/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ item })
    })
  }

  async deleteItem(id: string): Promise<void> {
    return this.request(`/inventory/items/${id}`, { method: 'DELETE' })
  }

  // Shopping Lists
  async listShoppingLists(): Promise<ApiResponse<ShoppingList[]>> {
    return this.request('/shopping-lists')
  }

  async getShoppingList(id: string): Promise<ApiResponse<ShoppingList>> {
    return this.request(`/shopping-lists/${id}`)
  }

  async createShoppingList(list: Partial<ShoppingList>): Promise<ApiResponse<ShoppingList>> {
    return this.request('/shopping-lists', {
      method: 'POST',
      body: JSON.stringify({ list })
    })
  }

  async updateShoppingList(id: string, list: Partial<ShoppingList>): Promise<ApiResponse<ShoppingList>> {
    return this.request(`/shopping-lists/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ list })
    })
  }

  async deleteShoppingList(id: string): Promise<void> {
    return this.request(`/shopping-lists/${id}`, { method: 'DELETE' })
  }

  async generateShoppingList(): Promise<ApiResponse<ShoppingList>> {
    return this.request('/shopping-lists/generate', { method: 'POST' })
  }

  // Shopping List Items
  async createShoppingItem(listId: string, item: Partial<ShoppingListItem>): Promise<ApiResponse<ShoppingListItem>> {
    return this.request(`/shopping-lists/${listId}/items`, {
      method: 'POST',
      body: JSON.stringify({ item })
    })
  }

  async updateShoppingItem(listId: string, itemId: string, item: Partial<ShoppingListItem>): Promise<ApiResponse<ShoppingListItem>> {
    return this.request(`/shopping-lists/${listId}/items/${itemId}`, {
      method: 'PUT',
      body: JSON.stringify({ item: item })
    })
  }

  async deleteShoppingItem(listId: string, itemId: string): Promise<void> {
    return this.request(`/shopping-lists/${listId}/items/${itemId}`, { method: 'DELETE' })
  }

  async getAllShoppingItems(): Promise<ApiResponse<ShoppingListItem[]>> {
    return this.request('/shopping-items')
  }

  // Budget Sources
  async listSources(): Promise<ApiResponse<BudgetSource[]>> {
    return this.request('/budget/sources')
  }

  async getSource(id: string): Promise<ApiResponse<BudgetSource>> {
    return this.request(`/budget/sources/${id}`)
  }

  async createSource(source: Partial<BudgetSource>): Promise<ApiResponse<BudgetSource>> {
    return this.request('/budget/sources', {
      method: 'POST',
      body: JSON.stringify({ source })
    })
  }

  async updateSource(id: string, source: Partial<BudgetSource>): Promise<ApiResponse<BudgetSource>> {
    return this.request(`/budget/sources/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ source })
    })
  }

  async deleteSource(id: string): Promise<void> {
    return this.request(`/budget/sources/${id}`, { method: 'DELETE' })
  }

  // Budget Entries
  async listEntries(params?: {
    start_date?: string
    end_date?: string
    type?: string
  }): Promise<ApiResponse<BudgetEntry[]>> {
    const searchParams = new URLSearchParams()
    if (params?.start_date) searchParams.set('start_date', params.start_date)
    if (params?.end_date) searchParams.set('end_date', params.end_date)
    if (params?.type) searchParams.set('type', params.type)
    
    const query = searchParams.toString()
    return this.request(`/budget/entries${query ? `?${query}` : ''}`)
  }

  async createEntry(entry: Partial<BudgetEntry>): Promise<ApiResponse<BudgetEntry>> {
    return this.request('/budget/entries', {
      method: 'POST',
      body: JSON.stringify({ entry })
    })
  }

  async updateEntry(id: string, entry: Partial<BudgetEntry>): Promise<ApiResponse<BudgetEntry>> {
    return this.request(`/budget/entries/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ entry })
    })
  }

  async deleteEntry(id: string): Promise<void> {
    return this.request(`/budget/entries/${id}`, { method: 'DELETE' })
  }

  async getBudgetSummary(year?: number, month?: number): Promise<ApiResponse<BudgetSummary>> {
    const searchParams = new URLSearchParams()
    if (year) searchParams.set('year', year.toString())
    if (month) searchParams.set('month', month.toString())
    
    const query = searchParams.toString()
    return this.request(`/budget/summary${query ? `?${query}` : ''}`)
  }

  // Notebooks
  async listNotebooks(): Promise<ApiResponse<Notebook[]>> {
    return this.request('/notebooks')
  }

  async getNotebook(id: string): Promise<ApiResponse<Notebook>> {
    return this.request(`/notebooks/${id}`)
  }

  async createNotebook(notebook: Partial<Notebook>): Promise<ApiResponse<Notebook>> {
    return this.request('/notebooks', {
      method: 'POST',
      body: JSON.stringify({ notebook })
    })
  }

  async updateNotebook(id: string, notebook: Partial<Notebook>): Promise<ApiResponse<Notebook>> {
    return this.request(`/notebooks/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ notebook })
    })
  }

  async deleteNotebook(id: string): Promise<void> {
    return this.request(`/notebooks/${id}`, { method: 'DELETE' })
  }

  // Pages
  async listPages(notebookId: string): Promise<ApiResponse<Page[]>> {
    return this.request(`/notebooks/${notebookId}/pages`)
  }

  async getPage(id: string): Promise<ApiResponse<Page>> {
    return this.request(`/pages/${id}`)
  }

  async createPage(notebookId: string, page: Partial<Page>): Promise<ApiResponse<Page>> {
    return this.request(`/notebooks/${notebookId}/pages`, {
      method: 'POST',
      body: JSON.stringify({ page })
    })
  }

  async updatePage(id: string, page: Partial<Page>): Promise<ApiResponse<Page>> {
    return this.request(`/pages/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ page })
    })
  }

  async deletePage(id: string): Promise<void> {
    return this.request(`/pages/${id}`, { method: 'DELETE' })
  }

  // Tags
  async listTags(): Promise<ApiResponse<Tag[]>> {
    return this.request('/tags')
  }

  async createTag(tag: Partial<Tag>): Promise<ApiResponse<Tag>> {
    return this.request('/tags', {
      method: 'POST',
      body: JSON.stringify({ tag })
    })
  }

  async updateTag(id: string, tag: Partial<Tag>): Promise<ApiResponse<Tag>> {
    return this.request(`/tags/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ tag })
    })
  }

  async deleteTag(id: string): Promise<void> {
    return this.request(`/tags/${id}`, { method: 'DELETE' })
  }

  // Search
  async search(query: string): Promise<ApiResponse<SearchResults>> {
    return this.request(`/search?q=${encodeURIComponent(query)}`)
  }

  // Notifications
  async listNotifications(params?: {
    unread_only?: boolean
    limit?: number
  }): Promise<{ data: Notification[]; unread_count: number }> {
    const searchParams = new URLSearchParams()
    if (params?.unread_only) searchParams.set('unread_only', 'true')
    if (params?.limit) searchParams.set('limit', params.limit.toString())
    
    const query = searchParams.toString()
    return this.request(`/notifications${query ? `?${query}` : ''}`)
  }

  async getNotification(id: string): Promise<ApiResponse<Notification>> {
    return this.request(`/notifications/${id}`)
  }

  async markNotificationRead(id: string): Promise<ApiResponse<Notification>> {
    return this.request(`/notifications/${id}/read`, { method: 'PUT' })
  }

  async markAllNotificationsRead(): Promise<{ message: string }> {
    return this.request('/notifications/mark-all-read', { method: 'POST' })
  }

  async deleteNotification(id: string): Promise<void> {
    return this.request(`/notifications/${id}`, { method: 'DELETE' })
  }

  async getUnreadNotificationCount(): Promise<{ count: number }> {
    return this.request('/notifications/unread-count')
  }

  async getNotificationPreferences(): Promise<ApiResponse<NotificationPreferences>> {
    return this.request('/notifications/preferences')
  }

  async updateNotificationPreferences(preferences: Partial<NotificationPreferences>): Promise<ApiResponse<NotificationPreferences>> {
    return this.request('/notifications/preferences', {
      method: 'PUT',
      body: JSON.stringify({ preferences })
    })
  }

  // Goal Categories
  async listGoalCategories(): Promise<ApiResponse<GoalCategory[]>> {
    return this.request('/goal-categories')
  }

  async getGoalCategory(id: string): Promise<ApiResponse<GoalCategory>> {
    return this.request(`/goal-categories/${id}`)
  }

  async createGoalCategory(category: Partial<GoalCategory>): Promise<ApiResponse<GoalCategory>> {
    return this.request('/goal-categories', {
      method: 'POST',
      body: JSON.stringify({ category })
    })
  }

  async updateGoalCategory(id: string, category: Partial<GoalCategory>): Promise<ApiResponse<GoalCategory>> {
    return this.request(`/goal-categories/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ category })
    })
  }

  async deleteGoalCategory(id: string): Promise<void> {
    return this.request(`/goal-categories/${id}`, { method: 'DELETE' })
  }

  // Goals
  async listGoals(params?: {
    status?: string
    category_id?: string
    tag_ids?: string[]
  }): Promise<ApiResponse<Goal[]>> {
    const searchParams = new URLSearchParams()
    if (params?.status) searchParams.set('status', params.status)
    if (params?.category_id) searchParams.set('category_id', params.category_id)
    if (params?.tag_ids && params.tag_ids.length > 0) searchParams.set('tag_ids', params.tag_ids.join(','))
    
    const query = searchParams.toString()
    return this.request(`/goals${query ? `?${query}` : ''}`)
  }

  async getGoal(id: string): Promise<ApiResponse<Goal>> {
    return this.request(`/goals/${id}`)
  }

  async createGoal(goal: Partial<Goal>): Promise<ApiResponse<Goal>> {
    return this.request('/goals', {
      method: 'POST',
      body: JSON.stringify({ goal })
    })
  }

  async updateGoal(id: string, goal: Partial<Goal>): Promise<ApiResponse<Goal>> {
    return this.request(`/goals/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ goal })
    })
  }

  async deleteGoal(id: string): Promise<void> {
    return this.request(`/goals/${id}`, { method: 'DELETE' })
  }

  async updateGoalTags(goalId: string, tagIds: string[]): Promise<ApiResponse<Goal>> {
    return this.request(`/goals/${goalId}/tags`, {
      method: 'PUT',
      body: JSON.stringify({ tag_ids: tagIds })
    })
  }

  async addMilestone(goalId: string, milestone: Partial<Milestone>): Promise<ApiResponse<Milestone>> {
    return this.request(`/goals/${goalId}/milestones`, {
      method: 'POST',
      body: JSON.stringify({ milestone })
    })
  }

  async updateMilestone(goalId: string, milestoneId: string, milestone: Partial<Milestone>): Promise<ApiResponse<Milestone>> {
    return this.request(`/goals/${goalId}/milestones/${milestoneId}`, {
      method: 'PUT',
      body: JSON.stringify({ milestone })
    })
  }

  async toggleMilestone(goalId: string, milestoneId: string): Promise<ApiResponse<Milestone>> {
    return this.request(`/goals/${goalId}/milestones/${milestoneId}/toggle`, {
      method: 'PUT'
    })
  }

  async deleteMilestone(goalId: string, milestoneId: string): Promise<void> {
    return this.request(`/goals/${goalId}/milestones/${milestoneId}`, { method: 'DELETE' })
  }

  async getGoalHistory(goalId: string): Promise<ApiResponse<GoalHistoryItem[]>> {
    return this.request(`/goals/${goalId}/history`)
  }

  // Habits
  async listHabits(): Promise<ApiResponse<Habit[]>> {
    return this.request('/habits')
  }

  async getHabit(id: string): Promise<ApiResponse<Habit>> {
    return this.request(`/habits/${id}`)
  }

  async createHabit(habit: Partial<Habit>): Promise<ApiResponse<Habit>> {
    return this.request('/habits', {
      method: 'POST',
      body: JSON.stringify({ habit })
    })
  }

  async updateHabit(id: string, habit: Partial<Habit>): Promise<ApiResponse<Habit>> {
    return this.request(`/habits/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ habit })
    })
  }

  async deleteHabit(id: string): Promise<void> {
    return this.request(`/habits/${id}`, { method: 'DELETE' })
  }

  async completeHabit(id: string): Promise<ApiResponse<HabitCompletion>> {
    return this.request(`/habits/${id}/complete`, { method: 'POST' })
  }

  async uncompleteHabit(id: string): Promise<ApiResponse<Habit>> {
    return this.request(`/habits/${id}/complete`, { method: 'DELETE' })
  }

  async getHabitCompletions(id: string, params?: {
    start_date?: string
    end_date?: string
  }): Promise<ApiResponse<HabitCompletion[]>> {
    const searchParams = new URLSearchParams()
    if (params?.start_date) searchParams.set('start_date', params.start_date)
    if (params?.end_date) searchParams.set('end_date', params.end_date)
    
    const query = searchParams.toString()
    return this.request(`/habits/${id}/completions${query ? `?${query}` : ''}`)
  }

  // Task Templates
  async listTemplates(): Promise<ApiResponse<TaskTemplate[]>> {
    return this.request('/templates')
  }

  async getTemplate(id: string): Promise<ApiResponse<TaskTemplate>> {
    return this.request(`/templates/${id}`)
  }

  async createTemplate(template: Partial<TaskTemplate>): Promise<ApiResponse<TaskTemplate>> {
    return this.request('/templates', {
      method: 'POST',
      body: JSON.stringify({ template })
    })
  }

  async updateTemplate(id: string, template: Partial<TaskTemplate>): Promise<ApiResponse<TaskTemplate>> {
    return this.request(`/templates/${id}`, {
      method: 'PUT',
      body: JSON.stringify({ template })
    })
  }

  async deleteTemplate(id: string): Promise<void> {
    return this.request(`/templates/${id}`, { method: 'DELETE' })
  }

  async applyTemplate(templateId: string, date: string, overrides?: { title?: string; start_time?: string }): Promise<ApiResponse<Task>> {
    return this.request(`/templates/${templateId}/apply`, {
      method: 'POST',
      body: JSON.stringify({ date, ...overrides })
    })
  }

  // Generic HTTP methods for stores that need custom endpoints
  async get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint)
  }

  async post<T>(endpoint: string, data?: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined
    })
  }

  async put<T>(endpoint: string, data?: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined
    })
  }

  async delete<T = void>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' })
  }
}

export const api = new ApiClient()

