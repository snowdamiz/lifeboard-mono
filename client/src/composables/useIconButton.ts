import { computed, type ComputedRef } from 'vue'
import type { Component } from 'vue'
import { cn } from '@/lib/utils'

/**
 * Button variant configuration for different action types
 */
export type IconButtonVariant = 'default' | 'destructive' | 'success' | 'outline'

export interface UseIconButtonOptions {
    /** Enable adaptive visibility (fade on desktop until hover) */
    adaptive?: boolean
    /** Disable the button */
    disabled?: boolean
    /** Show loading spinner */
    loading?: boolean
    /** Button variant for color styling */
    variant?: IconButtonVariant
    /** Custom title/tooltip */
    title?: string
}

export interface IconButtonConfig {
    /** CSS classes for the button */
    buttonClasses: ComputedRef<string>
    /** Whether button is effectively disabled (disabled or loading) */
    isDisabled: ComputedRef<boolean>
    /** Click handler with event stopping */
    handleClick: (e: Event, callback?: (e: Event) => void) => void
}

/**
 * Composable for consistent icon button behavior.
 * 
 * Consolidates patterns from AddButton, EditButton, DeleteButton, SettingsButton:
 * - Dynamic sizing (scales with parent font)
 * - Adaptive visibility (hover reveal on desktop)
 * - Consistent hover states by variant
 * - Loading state handling
 * - Event propagation stopping
 * 
 * @example
 * ```vue
 * <script setup lang="ts">
 * import { useIconButton } from '@/composables/useIconButton'
 * import { Plus } from 'lucide-vue-next'
 * 
 * const { buttonClasses, handleClick, isDisabled } = useIconButton({ 
 *   adaptive: true,
 *   variant: 'default'
 * })
 * </script>
 * 
 * <template>
 *   <button :class="buttonClasses" :disabled="isDisabled" @click="handleClick($event, doSomething)">
 *     <Plus class="h-[0.9em] w-[0.9em]" />
 *   </button>
 * </template>
 * ```
 */
export function useIconButton(options: UseIconButtonOptions = {}): IconButtonConfig {
    const {
        adaptive = false,
        disabled = false,
        loading = false,
        variant = 'default',
        title = ''
    } = options

    const variantStyles: Record<IconButtonVariant, string> = {
        default: 'text-muted-foreground hover:text-primary hover:bg-primary/10',
        destructive: 'text-muted-foreground hover:text-destructive hover:bg-destructive/10 active:text-destructive',
        success: 'text-muted-foreground hover:text-green-600 hover:bg-green-600/10',
        outline: 'border border-input bg-background hover:bg-accent hover:text-accent-foreground'
    }

    const buttonClasses = computed(() => cn(
        // Dynamic sizing - scales with parent font
        'h-[1.75em] w-[1.75em] min-h-[20px] min-w-[20px]',
        // Layout and transitions
        'flex items-center justify-center rounded transition-all shrink-0',
        // Variant-specific styling
        variantStyles[variant],
        // Adaptive visibility
        adaptive && 'sm:opacity-0 sm:group-hover:opacity-100',
        // Disabled/loading state
        (disabled || loading) && 'opacity-50 pointer-events-none'
    ))

    const isDisabled = computed(() => disabled || loading)

    const handleClick = (e: Event, callback?: (e: Event) => void) => {
        e.stopPropagation()
        if (!loading && !disabled && callback) {
            callback(e)
        }
    }

    return {
        buttonClasses,
        isDisabled,
        handleClick
    }
}

/**
 * Icon size class for consistent sizing inside buttons
 */
export const ICON_SIZE_CLASS = 'h-[0.9em] w-[0.9em]'

/**
 * Common icon button props interface for components
 */
export interface IconButtonProps {
    adaptive?: boolean
    disabled?: boolean
    loading?: boolean
    title?: string
}
