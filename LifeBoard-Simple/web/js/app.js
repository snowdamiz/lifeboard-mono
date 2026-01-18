/**
 * LifeBoard Main Application
 * 
 * Core application logic for:
 * - Single Page Application (SPA) navigation
 * - Theme management
 * - User state management
 * - Common UI utilities
 */

const App = {
    // Current user data
    user: null,

    // User preferences
    preferences: {
        theme: 'system',
        sidebarCollapsed: false,
    },

    // ================================================================
    // INITIALIZATION
    // ================================================================

    /**
     * Initialize the application
     */
    async init() {
        console.log('🚀 LifeBoard initializing...');

        // Apply saved theme
        this.loadTheme();

        // Check authentication
        if (!API.isLoggedIn()) {
            // Redirect to login if not on login page
            if (!window.location.pathname.includes('login.html')) {
                window.location.href = '/pages/login.html';
                return;
            }
        } else {
            // Load user data
            try {
                this.user = await API.me();
                this.preferences = await API.preferences.get();
                this.applyPreferences();
            } catch (error) {
                console.error('Failed to load user data:', error);
                API.logout();
                window.location.href = '/pages/login.html';
                return;
            }
        }

        // Setup navigation
        this.setupNavigation();

        // Setup global event handlers
        this.setupEventHandlers();

        console.log('✅ LifeBoard ready!');
    },

    /**
     * Setup sidebar navigation highlighting
     */
    setupNavigation() {
        const currentPath = window.location.pathname;
        document.querySelectorAll('.nav-link').forEach(link => {
            if (link.getAttribute('href') === currentPath) {
                link.classList.add('active');
            }
        });
    },

    /**
     * Setup global event handlers
     */
    setupEventHandlers() {
        // Logout button
        document.getElementById('logout-btn')?.addEventListener('click', () => {
            API.logout();
            window.location.href = '/pages/login.html';
        });

        // Sidebar toggle
        document.getElementById('sidebar-toggle')?.addEventListener('click', () => {
            this.toggleSidebar();
        });

        // Theme toggle
        document.getElementById('theme-toggle')?.addEventListener('click', () => {
            this.toggleTheme();
        });

        // Modal close on overlay click
        document.querySelectorAll('.modal-overlay').forEach(overlay => {
            overlay.addEventListener('click', (e) => {
                if (e.target === overlay) {
                    this.closeModal(overlay);
                }
            });
        });

        // Escape key to close modals
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                document.querySelectorAll('.modal-overlay.active').forEach(modal => {
                    this.closeModal(modal);
                });
                // Also close dropdowns
                document.querySelectorAll('.dropdown.active').forEach(dropdown => {
                    dropdown.classList.remove('active');
                });
            }
        });

        // Close dropdowns when clicking outside
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.dropdown')) {
                document.querySelectorAll('.dropdown.active').forEach(dropdown => {
                    dropdown.classList.remove('active');
                });
            }
        });
    },

    // ================================================================
    // THEME MANAGEMENT
    // ================================================================

    /**
     * Load and apply the saved theme
     */
    loadTheme() {
        const savedTheme = localStorage.getItem('theme') || 'system';
        this.applyTheme(savedTheme);
    },

    /**
     * Apply a theme
     */
    applyTheme(theme) {
        const html = document.documentElement;
        html.classList.remove('theme-light', 'theme-dark', 'theme-system');
        html.classList.add('theme-' + theme);
        localStorage.setItem('theme', theme);
        this.preferences.theme = theme;
    },

    /**
     * Toggle between light and dark theme
     */
    toggleTheme() {
        const current = this.preferences.theme;
        let next;

        if (current === 'light') next = 'dark';
        else if (current === 'dark') next = 'system';
        else next = 'light';

        this.applyTheme(next);

        // Save to server
        API.preferences.update({ theme: next }).catch(console.error);

        // Update toggle icon
        this.updateThemeIcon();
    },

    /**
     * Update theme toggle icon
     */
    updateThemeIcon() {
        const icon = document.getElementById('theme-icon');
        if (icon) {
            if (this.preferences.theme === 'dark') {
                icon.textContent = '🌙';
            } else if (this.preferences.theme === 'light') {
                icon.textContent = '☀️';
            } else {
                icon.textContent = '💻';
            }
        }
    },

    // ================================================================
    // SIDEBAR
    // ================================================================

    /**
     * Toggle sidebar collapsed state
     */
    toggleSidebar() {
        const sidebar = document.querySelector('.app-sidebar');
        if (sidebar) {
            sidebar.classList.toggle('collapsed');
            this.preferences.sidebarCollapsed = sidebar.classList.contains('collapsed');

            // Save preference
            API.preferences.update({
                sidebarCollapsed: this.preferences.sidebarCollapsed
            }).catch(console.error);
        }
    },

    /**
     * Apply saved preferences
     */
    applyPreferences() {
        this.applyTheme(this.preferences.theme || 'system');

        if (this.preferences.sidebarCollapsed) {
            document.querySelector('.app-sidebar')?.classList.add('collapsed');
        }

        this.updateThemeIcon();
    },

    // ================================================================
    // MODALS
    // ================================================================

    /**
     * Open a modal
     */
    openModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('active');
            document.body.style.overflow = 'hidden';
        }
    },

    /**
     * Close a modal
     */
    closeModal(modal) {
        if (typeof modal === 'string') {
            modal = document.getElementById(modal);
        }
        if (modal) {
            modal.classList.remove('active');
            document.body.style.overflow = '';
        }
    },

    /**
     * Close all modals
     */
    closeAllModals() {
        document.querySelectorAll('.modal-overlay.active').forEach(modal => {
            this.closeModal(modal);
        });
    },

    // ================================================================
    // NOTIFICATIONS
    // ================================================================

    /**
     * Show a toast notification
     */
    toast(message, type = 'info') {
        const container = document.getElementById('toast-container') || this.createToastContainer();

        const toast = document.createElement('div');
        toast.className = 'toast toast-' + type;
        toast.innerHTML = `
            <span class="toast-message">${this.escapeHtml(message)}</span>
            <button class="toast-close" onclick="this.parentElement.remove()">×</button>
        `;

        container.appendChild(toast);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            toast.classList.add('toast-fade-out');
            setTimeout(() => toast.remove(), 300);
        }, 5000);
    },

    createToastContainer() {
        const container = document.createElement('div');
        container.id = 'toast-container';
        container.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 2000;
            display: flex;
            flex-direction: column;
            gap: 8px;
        `;
        document.body.appendChild(container);
        return container;
    },

    // ================================================================
    // UTILITIES
    // ================================================================

    /**
     * Escape HTML to prevent XSS
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    },

    /**
     * Format a date string
     */
    formatDate(dateStr, format = 'short') {
        if (!dateStr) return '';
        const date = new Date(dateStr);
        if (format === 'short') {
            return date.toLocaleDateString();
        } else if (format === 'long') {
            return date.toLocaleDateString('en-US', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            });
        } else if (format === 'time') {
            return date.toLocaleTimeString('en-US', {
                hour: 'numeric',
                minute: '2-digit'
            });
        }
        return dateStr;
    },

    /**
     * Get initials from a name
     */
    getInitials(name) {
        return name
            .split(' ')
            .map(word => word[0])
            .join('')
            .toUpperCase()
            .slice(0, 2);
    },

    /**
     * Debounce function calls
     */
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    /**
     * Generate a simple unique ID
     */
    generateId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    },
};

// Add toast styles
const toastStyles = document.createElement('style');
toastStyles.textContent = `
    .toast {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 12px 16px;
        background: var(--color-text);
        color: var(--color-bg);
        border-radius: var(--radius-lg);
        box-shadow: var(--shadow-lg);
        animation: toast-in 0.3s ease;
    }
    .toast-info { background: var(--color-info); }
    .toast-success { background: var(--color-success); }
    .toast-warning { background: var(--color-warning); }
    .toast-error { background: var(--color-error); }
    .toast-close {
        background: none;
        border: none;
        color: inherit;
        font-size: 18px;
        cursor: pointer;
        opacity: 0.7;
    }
    .toast-close:hover { opacity: 1; }
    .toast-fade-out { animation: toast-out 0.3s ease forwards; }
    @keyframes toast-in {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    @keyframes toast-out {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
`;
document.head.appendChild(toastStyles);

// Export for use
window.App = App;

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => App.init());
