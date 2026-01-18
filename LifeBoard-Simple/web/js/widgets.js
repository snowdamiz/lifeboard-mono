/**
 * LifeBoard Widget Grid System
 * Provides draggable, resizable widgets with persistent layout
 */

const WidgetGrid = {
    // Configuration
    COLS: 4,
    ROW_HEIGHT: 120,
    GAP: 16,
    MIN_W: 1,
    MIN_H: 1,

    // State
    widgets: [],
    container: null,
    editMode: false,
    dragState: null,
    resizeState: null,
    storageKey: 'lifeboard-widget-layout',
    layoutBackup: null, // Backup for cancel functionality

    /**
     * Initialize widget grid
     * @param {string} containerId - Container element ID
     * @param {Array} defaultWidgets - Default widget configuration
     */
    init(containerId, defaultWidgets) {
        this.container = document.getElementById(containerId);
        if (!this.container) return;

        this.container.classList.add('widget-grid');
        this.loadLayout(defaultWidgets);
        this.render();
        this.attachEvents();
    },

    /**
     * Load layout from localStorage or use defaults
     */
    loadLayout(defaults) {
        const saved = localStorage.getItem(this.storageKey);
        if (saved) {
            try {
                const savedLayout = JSON.parse(saved);
                // Merge saved layout data into defaults (preserves render functions)
                this.widgets = defaults.map(def => {
                    const savedWidget = savedLayout.find(s => s.id === def.id);
                    if (savedWidget) {
                        // Merge position/size/visibility from saved, keep render from default
                        return {
                            ...def,
                            x: savedWidget.x !== undefined ? savedWidget.x : def.x,
                            y: savedWidget.y !== undefined ? savedWidget.y : def.y,
                            w: savedWidget.w !== undefined ? savedWidget.w : def.w,
                            h: savedWidget.h !== undefined ? savedWidget.h : def.h,
                            visible: savedWidget.visible !== undefined ? savedWidget.visible : def.visible
                        };
                    }
                    return def;
                });
            } catch (e) {
                this.widgets = defaults;
            }
        } else {
            this.widgets = defaults;
        }
    },

    /**
     * Save layout to localStorage
     */
    saveLayout() {
        localStorage.setItem(this.storageKey, JSON.stringify(
            this.widgets.map(w => ({
                id: w.id, x: w.x, y: w.y, w: w.w, h: w.h, visible: w.visible
            }))
        ));
    },

    /**
     * Toggle edit mode
     */
    toggleEditMode() {
        if (!this.editMode) {
            // Entering edit mode - save backup
            this.layoutBackup = JSON.stringify(
                this.widgets.map(w => ({ id: w.id, x: w.x, y: w.y, w: w.w, h: w.h, visible: w.visible }))
            );
        } else {
            // Exiting edit mode (Done) - save changes
            this.saveLayout();
            this.layoutBackup = null;
        }
        this.editMode = !this.editMode;
        this.container.classList.toggle('edit-mode', this.editMode);
        this.render();
        return this.editMode;
    },

    /**
     * Cancel edit mode and revert changes
     */
    cancelEdit(defaults) {
        this.editMode = false;
        this.container.classList.remove('edit-mode');
        // Restore from backup
        if (this.layoutBackup) {
            const backup = JSON.parse(this.layoutBackup);
            this.widgets = defaults.map(def => {
                const saved = backup.find(s => s.id === def.id);
                if (saved) {
                    return { ...def, x: saved.x, y: saved.y, w: saved.w, h: saved.h, visible: saved.visible };
                }
                return def;
            });
            this.layoutBackup = null;
        }
        this.render();
    },

    /**
     * Render widgets to container
     */
    render() {
        // Calculate grid dimensions
        const containerWidth = this.container.offsetWidth;
        const colWidth = (containerWidth - (this.COLS - 1) * this.GAP) / this.COLS;

        // Find max Y to set container height
        let maxY = 0;
        this.widgets.filter(w => w.visible !== false).forEach(w => {
            maxY = Math.max(maxY, w.y + w.h);
        });
        this.container.style.minHeight = (maxY * this.ROW_HEIGHT + (maxY - 1) * this.GAP) + 'px';
        this.container.style.position = 'relative';

        // Clear and re-render
        this.container.innerHTML = '';

        this.widgets.filter(w => w.visible !== false).forEach(widget => {
            const el = document.createElement('div');
            el.className = 'widget-item' + (this.editMode ? ' editable' : '');
            el.dataset.widgetId = widget.id;

            // Position using CSS
            el.style.left = (widget.x * (colWidth + this.GAP)) + 'px';
            el.style.top = (widget.y * (this.ROW_HEIGHT + this.GAP)) + 'px';
            el.style.width = (widget.w * colWidth + (widget.w - 1) * this.GAP) + 'px';
            el.style.height = (widget.h * this.ROW_HEIGHT + (widget.h - 1) * this.GAP) + 'px';

            // Widget content
            el.innerHTML = `
                ${this.editMode ? `
                    <div class="widget-drag-handle" title="Drag to move">⠿</div>
                    <button class="widget-remove-btn" title="Remove widget">×</button>
                    <div class="widget-resize-handle" title="Drag to resize">⤡</div>
                ` : ''}
                <div class="widget-content" id="widget-${widget.id}"></div>
            `;

            this.container.appendChild(el);
        });

        // Call content renderers
        this.widgets.filter(w => w.visible !== false).forEach(w => {
            if (w.render) w.render(`widget-${w.id}`);
        });
    },

    /**
     * Attach drag/resize event listeners
     */
    attachEvents() {
        // Drag handling
        this.container.addEventListener('mousedown', e => {
            const handle = e.target.closest('.widget-drag-handle');
            if (handle && this.editMode) {
                const widgetEl = handle.closest('.widget-item');
                const widgetId = widgetEl.dataset.widgetId;
                const widget = this.widgets.find(w => w.id === widgetId);

                this.dragState = {
                    widget,
                    el: widgetEl,
                    startX: e.clientX,
                    startY: e.clientY,
                    origX: widget.x,
                    origY: widget.y
                };

                widgetEl.classList.add('dragging');
                e.preventDefault();
            }
        });

        // Resize handling
        this.container.addEventListener('mousedown', e => {
            const handle = e.target.closest('.widget-resize-handle');
            if (handle && this.editMode) {
                const widgetEl = handle.closest('.widget-item');
                const widgetId = widgetEl.dataset.widgetId;
                const widget = this.widgets.find(w => w.id === widgetId);

                this.resizeState = {
                    widget,
                    el: widgetEl,
                    startX: e.clientX,
                    startY: e.clientY,
                    origW: widget.w,
                    origH: widget.h
                };

                widgetEl.classList.add('resizing');
                e.preventDefault();
            }
        });

        // Remove widget
        this.container.addEventListener('click', e => {
            const btn = e.target.closest('.widget-remove-btn');
            if (btn && this.editMode) {
                const widgetEl = btn.closest('.widget-item');
                const widgetId = widgetEl.dataset.widgetId;
                const widget = this.widgets.find(w => w.id === widgetId);
                if (widget) {
                    widget.visible = false;
                    this.saveLayout();
                    this.render();
                }
            }
        });

        // Mouse move for drag/resize
        document.addEventListener('mousemove', e => {
            const containerWidth = this.container.offsetWidth;
            const colWidth = (containerWidth - (this.COLS - 1) * this.GAP) / this.COLS;

            if (this.dragState) {
                const dx = e.clientX - this.dragState.startX;
                const dy = e.clientY - this.dragState.startY;

                // Convert pixel delta to grid units
                let newX = this.dragState.origX + Math.round(dx / (colWidth + this.GAP));
                let newY = this.dragState.origY + Math.round(dy / (this.ROW_HEIGHT + this.GAP));

                // Clamp to bounds
                newX = Math.max(0, Math.min(this.COLS - this.dragState.widget.w, newX));
                newY = Math.max(0, newY);

                this.dragState.widget.x = newX;
                this.dragState.widget.y = newY;

                // Update visual position
                this.dragState.el.style.left = (newX * (colWidth + this.GAP)) + 'px';
                this.dragState.el.style.top = (newY * (this.ROW_HEIGHT + this.GAP)) + 'px';
            }

            if (this.resizeState) {
                const dx = e.clientX - this.resizeState.startX;
                const dy = e.clientY - this.resizeState.startY;

                let newW = this.resizeState.origW + Math.round(dx / (colWidth + this.GAP));
                let newH = this.resizeState.origH + Math.round(dy / (this.ROW_HEIGHT + this.GAP));

                // Clamp to bounds
                newW = Math.max(this.MIN_W, Math.min(this.COLS - this.resizeState.widget.x, newW));
                newH = Math.max(this.MIN_H, newH);

                this.resizeState.widget.w = newW;
                this.resizeState.widget.h = newH;

                // Update visual size
                this.resizeState.el.style.width = (newW * colWidth + (newW - 1) * this.GAP) + 'px';
                this.resizeState.el.style.height = (newH * this.ROW_HEIGHT + (newH - 1) * this.GAP) + 'px';
            }
        });

        // Mouse up - end drag/resize
        document.addEventListener('mouseup', () => {
            if (this.dragState) {
                this.dragState.el.classList.remove('dragging');
                this.dragState = null;
                // Don't save here - wait for Done button
                this.render();
            }
            if (this.resizeState) {
                this.resizeState.el.classList.remove('resizing');
                this.resizeState = null;
                // Don't save here - wait for Done button
                this.render();
            }
        });

        // Window resize
        window.addEventListener('resize', () => this.render());
    },

    /**
     * Add a widget
     */
    addWidget(widget) {
        // Find next available position
        let y = 0;
        while (true) {
            let found = false;
            for (let x = 0; x <= this.COLS - widget.w; x++) {
                if (!this.checkCollision(x, y, widget.w, widget.h, widget.id)) {
                    widget.x = x;
                    widget.y = y;
                    widget.visible = true;
                    found = true;
                    break;
                }
            }
            if (found) break;
            y++;
            if (y > 20) break; // Safety limit
        }

        this.widgets.push(widget);
        this.saveLayout();
        this.render();
    },

    /**
     * Check collision with existing widgets
     */
    checkCollision(x, y, w, h, excludeId) {
        return this.widgets.some(widget => {
            if (widget.id === excludeId || widget.visible === false) return false;
            return !(x + w <= widget.x || x >= widget.x + widget.w ||
                y + h <= widget.y || y >= widget.y + widget.h);
        });
    },

    /**
     * Show hidden widget
     */
    showWidget(id) {
        const widget = this.widgets.find(w => w.id === id);
        if (widget) {
            widget.visible = true;
            this.saveLayout();
            this.render();
        }
    },

    /**
     * Get hidden widgets for picker
     */
    getHiddenWidgets() {
        return this.widgets.filter(w => w.visible === false);
    }
};
