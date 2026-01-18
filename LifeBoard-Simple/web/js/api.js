/**
 * LifeBoard API Client
 * 
 * A simple, readable API wrapper for communicating with the backend.
 * All methods return Promises with JSON data.
 * 
 * Usage:
 *   const user = await API.login('username', 'password');
 *   const tasks = await API.tasks.list({ startDate: '2026-01-01', endDate: '2026-01-31' });
 *   await API.tasks.create({ title: 'My Task', dueDate: '2026-01-20' });
 */

const API = {
    // Base URL for API requests
    baseUrl: '/api',

    // Auth token (stored in memory and localStorage)
    token: localStorage.getItem('token'),

    // ================================================================
    // HTTP HELPERS
    // ================================================================

    /**
     * Make an HTTP request to the API
     */
    async request(method, path, data = null) {
        const headers = {
            'Content-Type': 'application/json',
        };

        if (this.token) {
            headers['Authorization'] = 'Bearer ' + this.token;
        }

        const options = {
            method,
            headers,
        };

        if (data && (method === 'POST' || method === 'PUT')) {
            options.body = JSON.stringify(data);
        }

        const response = await fetch(this.baseUrl + path, options);

        // Handle 401 Unauthorized
        if (response.status === 401) {
            this.logout();
            window.location.href = '/pages/login.html';
            throw new Error('Unauthorized');
        }

        const json = await response.json().catch(() => ({}));

        if (!response.ok) {
            throw new Error(json.error || 'Request failed');
        }

        return json;
    },

    get(path) { return this.request('GET', path); },
    post(path, data) { return this.request('POST', path, data); },
    put(path, data) { return this.request('PUT', path, data); },
    delete(path) { return this.request('DELETE', path); },

    // ================================================================
    // AUTHENTICATION
    // ================================================================

    /**
     * Login with username and password
     */
    async login(username, password) {
        const result = await this.post('/login', { username, password });
        this.token = result.token;
        localStorage.setItem('token', result.token);
        return result.user;
    },

    /**
     * Register a new account
     */
    async register(username, password, displayName) {
        const result = await this.post('/register', { username, password, displayName });
        this.token = result.token;
        localStorage.setItem('token', result.token);
        return result.user;
    },

    /**
     * Logout and clear token
     */
    logout() {
        this.token = null;
        localStorage.removeItem('token');
    },

    /**
     * Get current user info
     */
    async me() {
        return this.get('/me');
    },

    /**
     * Check if user is logged in
     */
    isLoggedIn() {
        return !!this.token;
    },

    // ================================================================
    // TASKS
    // ================================================================

    tasks: {
        list(params = {}) {
            const query = new URLSearchParams(params).toString();
            return API.get('/tasks' + (query ? '?' + query : ''));
        },
        get(id) { return API.get('/tasks/' + id); },
        create(data) { return API.post('/tasks', data); },
        update(id, data) { return API.put('/tasks/' + id, data); },
        delete(id) { return API.delete('/tasks/' + id); },

        // Steps
        addStep(taskId, title) {
            return API.post('/tasks/' + taskId + '/steps', { title });
        },
        updateStep(taskId, stepId, data) {
            return API.put('/tasks/' + taskId + '/steps/' + stepId, data);
        },
        deleteStep(taskId, stepId) {
            return API.delete('/tasks/' + taskId + '/steps/' + stepId);
        },
    },

    // ================================================================
    // INVENTORY
    // ================================================================

    inventory: {
        // Sheets
        listSheets() { return API.get('/inventory/sheets'); },
        getSheet(id) { return API.get('/inventory/sheets/' + id); },
        createSheet(data) { return API.post('/inventory/sheets', data); },
        updateSheet(id, data) { return API.put('/inventory/sheets/' + id, data); },
        deleteSheet(id) { return API.delete('/inventory/sheets/' + id); },

        // Items (sheetId, itemId or sheetId, data)
        createItem(sheetId, data) { return API.post('/inventory/sheets/' + sheetId + '/items', data); },
        updateItem(sheetId, itemId, data) { return API.put('/inventory/sheets/' + sheetId + '/items/' + itemId, data); },
        deleteItem(sheetId, itemId) { return API.delete('/inventory/sheets/' + sheetId + '/items/' + itemId); },
    },

    // ================================================================
    // SHOPPING LISTS
    // ================================================================

    shopping: {
        list() { return API.get('/shopping-lists'); },
        get(id) { return API.get('/shopping-lists/' + id); },
        create(data) { return API.post('/shopping-lists', data); },
        update(id, data) { return API.put('/shopping-lists/' + id, data); },
        delete(id) { return API.delete('/shopping-lists/' + id); },
        generate() { return API.post('/shopping-lists/generate'); },

        // Items
        addItem(listId, data) {
            return API.post('/shopping-lists/' + listId + '/items', data);
        },
        updateItem(listId, itemId, data) {
            return API.put('/shopping-lists/' + listId + '/items/' + itemId, data);
        },
        removeItem(listId, itemId) {
            return API.delete('/shopping-lists/' + listId + '/items/' + itemId);
        },
    },

    // ================================================================
    // BUDGET
    // ================================================================

    budget: {
        // Sources
        listSources() { return API.get('/budget/sources'); },
        createSource(data) { return API.post('/budget/sources', data); },
        updateSource(id, data) { return API.put('/budget/sources/' + id, data); },
        deleteSource(id) { return API.delete('/budget/sources/' + id); },

        // Entries
        listEntries(params = {}) {
            const query = new URLSearchParams(params).toString();
            return API.get('/budget/entries' + (query ? '?' + query : ''));
        },
        createEntry(data) { return API.post('/budget/entries', data); },
        updateEntry(id, data) { return API.put('/budget/entries/' + id, data); },
        deleteEntry(id) { return API.delete('/budget/entries/' + id); },

        // Summary
        getSummary(params = {}) {
            const query = new URLSearchParams(params).toString();
            return API.get('/budget/summary' + (query ? '?' + query : ''));
        },
    },

    // ================================================================
    // NOTES
    // ================================================================

    notes: {
        listNotebooks() { return API.get('/notebooks'); },
        getNotebook(id) { return API.get('/notebooks/' + id); },
        createNotebook(data) { return API.post('/notebooks', data); },
        updateNotebook(id, data) { return API.put('/notebooks/' + id, data); },
        deleteNotebook(id) { return API.delete('/notebooks/' + id); },

        getPage(id) { return API.get('/pages/' + id); },
        createPage(notebookId, data) {
            return API.post('/notebooks/' + notebookId + '/pages', data);
        },
        updatePage(id, data) { return API.put('/pages/' + id, data); },
        deletePage(id) { return API.delete('/pages/' + id); },
    },

    // ================================================================
    // GOALS
    // ================================================================

    goals: {
        listCategories() { return API.get('/goal-categories'); },
        createCategory(data) { return API.post('/goal-categories', data); },
        updateCategory(id, data) { return API.put('/goal-categories/' + id, data); },
        deleteCategory(id) { return API.delete('/goal-categories/' + id); },

        list() { return API.get('/goals'); },
        get(id) { return API.get('/goals/' + id); },
        create(data) { return API.post('/goals', data); },
        update(id, data) { return API.put('/goals/' + id, data); },
        delete(id) { return API.delete('/goals/' + id); },

        // Milestones
        createMilestone(goalId, data) {
            return API.post('/goals/' + goalId + '/milestones', data);
        },
        updateMilestone(goalId, milestoneId, data) {
            return API.put('/goals/' + goalId + '/milestones/' + milestoneId, data);
        },
        deleteMilestone(goalId, milestoneId) {
            return API.delete('/goals/' + goalId + '/milestones/' + milestoneId);
        },
    },

    // ================================================================
    // HABITS
    // ================================================================

    habits: {
        list(params = {}) {
            const query = new URLSearchParams(params).toString();
            return API.get('/habits' + (query ? '?' + query : ''));
        },
        get(id) { return API.get('/habits/' + id); },
        create(data) { return API.post('/habits', data); },
        update(id, data) { return API.put('/habits/' + id, data); },
        delete(id) { return API.delete('/habits/' + id); },

        complete(id, data = {}) { return API.post('/habits/' + id + '/complete', data); },
        uncomplete(id, params = {}) {
            const query = new URLSearchParams(params).toString();
            return API.delete('/habits/' + id + '/complete' + (query ? '?' + query : ''));
        },
        getCompletions(id, params = {}) {
            const query = new URLSearchParams(params).toString();
            return API.get('/habits/' + id + '/completions' + (query ? '?' + query : ''));
        },
    },

    // ================================================================
    // TAGS
    // ================================================================

    tags: {
        list() { return API.get('/tags'); },
        get(id) { return API.get('/tags/' + id); },
        create(data) { return API.post('/tags', data); },
        update(id, data) { return API.put('/tags/' + id, data); },
        delete(id) { return API.delete('/tags/' + id); },
        search(q) { return API.get('/tags/search?q=' + encodeURIComponent(q)); },
    },

    // ================================================================
    // NOTIFICATIONS
    // ================================================================

    notifications: {
        list() { return API.get('/notifications'); },
        getUnreadCount() { return API.get('/notifications/unread-count'); },
        markRead(id) { return API.put('/notifications/' + id + '/read'); },
        markAllRead() { return API.post('/notifications/mark-all-read'); },
        delete(id) { return API.delete('/notifications/' + id); },
    },

    // ================================================================
    // PREFERENCES
    // ================================================================

    preferences: {
        get() { return API.get('/preferences'); },
        update(data) { return API.put('/preferences', data); },
    },
};

// Export for use in other modules
window.API = API;
