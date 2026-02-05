import { ref, computed, onMounted, onUnmounted, type Ref, type ComputedRef } from 'vue'

export type ModalMaxWidth = 'sm' | 'md' | 'lg' | 'xl' | 'full'

export interface UseModalOptions {
    /** Initial open state */
    initialOpen?: boolean
    /** Close on backdrop click (default: true) */
    closeOnBackdrop?: boolean
    /** Close on Escape key (default: true) */
    closeOnEscape?: boolean
    /** Callback when modal closes */
    onClose?: () => void
}

export interface ModalConfig {
    /** Whether modal is open */
    isOpen: Ref<boolean>
    /** Open the modal */
    open: () => void
    /** Close the modal */
    close: () => void
    /** Toggle modal state */
    toggle: () => void
    /** Handle backdrop click (respects closeOnBackdrop option) */
    handleBackdropClick: () => void
    /** Max width classes by size */
    maxWidthClasses: Record<ModalMaxWidth, string>
}

/**
 * Composable for modal state management and behavior.
 * 
 * Consolidates patterns from FormModal and ConfirmDialog:
 * - Open/close state management
 * - Escape key handling
 * - Backdrop click handling
 * - Body scroll locking
 * 
 * @example
 * ```vue
 * <script setup lang="ts">
 * import { useModal } from '@/composables/useModal'
 * 
 * const { isOpen, open, close, handleBackdropClick } = useModal({
 *   closeOnEscape: true,
 *   closeOnBackdrop: true
 * })
 * </script>
 * 
 * <template>
 *   <button @click="open">Open Modal</button>
 *   
 *   <Teleport to="body">
 *     <Transition ...>
 *       <div v-if="isOpen" class="modal-backdrop" @click="handleBackdropClick">
 *         <div class="modal-content" @click.stop>
 *           <!-- content -->
 *         </div>
 *       </div>
 *     </Transition>
 *   </Teleport>
 * </template>
 * ```
 */
export function useModal(options: UseModalOptions = {}): ModalConfig {
    const {
        initialOpen = false,
        closeOnBackdrop = true,
        closeOnEscape = true,
        onClose
    } = options

    const isOpen = ref(initialOpen)

    const open = () => {
        isOpen.value = true
        // Lock body scroll when modal opens
        document.body.style.overflow = 'hidden'
    }

    const close = () => {
        isOpen.value = false
        // Restore body scroll when modal closes
        document.body.style.overflow = ''
        onClose?.()
    }

    const toggle = () => {
        if (isOpen.value) {
            close()
        } else {
            open()
        }
    }

    const handleBackdropClick = () => {
        if (closeOnBackdrop) {
            close()
        }
    }

    // Handle Escape key
    const handleEscape = (e: KeyboardEvent) => {
        if (e.key === 'Escape' && isOpen.value && closeOnEscape) {
            close()
        }
    }

    onMounted(() => {
        document.addEventListener('keydown', handleEscape)
    })

    onUnmounted(() => {
        document.removeEventListener('keydown', handleEscape)
        // Ensure body scroll is restored
        document.body.style.overflow = ''
    })

    const maxWidthClasses: Record<ModalMaxWidth, string> = {
        sm: 'sm:max-w-sm',
        md: 'sm:max-w-md',
        lg: 'sm:max-w-lg',
        xl: 'sm:max-w-xl',
        full: 'sm:max-w-full'
    }

    return {
        isOpen,
        open,
        close,
        toggle,
        handleBackdropClick,
        maxWidthClasses
    }
}

/**
 * Transition classes for modal animations
 */
export const MODAL_TRANSITION_CLASSES = {
    enterActive: 'transition duration-150 ease-out',
    enterFrom: 'opacity-0',
    enterTo: 'opacity-100',
    leaveActive: 'transition duration-100 ease-in',
    leaveFrom: 'opacity-100',
    leaveTo: 'opacity-0'
}

/**
 * Common backdrop classes
 */
export const MODAL_BACKDROP_CLASSES = 'fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-center justify-center p-4'

/**
 * Common modal content classes
 */
export const MODAL_CONTENT_CLASSES = 'bg-card border border-border rounded-xl shadow-xl overflow-hidden'
