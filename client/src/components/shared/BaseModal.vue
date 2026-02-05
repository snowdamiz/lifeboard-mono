<script setup lang="ts">
/**
 * BaseModal - Unified modal component
 * 
 * Replaces: FormModal, ConfirmDialog, and custom modal implementations
 * 
 * Uses the useModal composable for consistent behavior:
 * - Teleport to body
 * - Escape key handling
 * - Backdrop click handling
 * - Body scroll locking
 * - Smooth enter/leave transitions
 */
import { computed, type Component } from 'vue'
import { X } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { 
  useModal, 
  type ModalMaxWidth,
  MODAL_TRANSITION_CLASSES,
  MODAL_BACKDROP_CLASSES,
  MODAL_CONTENT_CLASSES
} from '@/composables/useModal'
import { cn } from '@/lib/utils'

interface Props {
  /** Modal open state (controlled) */
  open: boolean
  /** Modal title */
  title: string
  /** Optional description/subtitle */
  description?: string
  /** Max width size */
  maxWidth?: ModalMaxWidth
  /** Show close button in header */
  showCloseButton?: boolean
  /** Variant for styling (default, danger, warning) */
  variant?: 'default' | 'danger' | 'warning'
  /** Icon component for header (optional) */
  headerIcon?: Component
  /** Close on backdrop click */
  closeOnBackdrop?: boolean
  /** data-testid for testing */
  testId?: string
}

const props = withDefaults(defineProps<Props>(), {
  maxWidth: 'md',
  showCloseButton: true,
  variant: 'default',
  closeOnBackdrop: true
})

const emit = defineEmits<{
  close: []
  submit: []
}>()

const { maxWidthClasses } = useModal()

const handleBackdropClick = () => {
  if (props.closeOnBackdrop) {
    emit('close')
  }
}

// Mobile-first: full width on mobile, max-width on desktop
const contentClasses = computed(() => cn(
  // Full width sheet on mobile, centered card on desktop
  'w-full bg-card border border-border',
  'rounded-t-2xl sm:rounded-xl shadow-xl',
  'overflow-hidden flex flex-col',
  'max-h-[90vh] sm:max-h-[85vh]',
  'animate-slide-up',
  maxWidthClasses[props.maxWidth]
))

// Variant-based icon container styling
const iconContainerClasses = computed(() => cn(
  'h-12 w-12 rounded-full mx-auto mb-4 flex items-center justify-center',
  props.variant === 'danger' && 'bg-destructive/10',
  props.variant === 'warning' && 'bg-amber-500/10',
  props.variant === 'default' && 'bg-primary/10'
))

const iconClasses = computed(() => cn(
  'h-6 w-6',
  props.variant === 'danger' && 'text-destructive',
  props.variant === 'warning' && 'text-amber-500',
  props.variant === 'default' && 'text-primary'
))
</script>

<template>
  <Teleport to="body">
    <Transition
      :enter-active-class="MODAL_TRANSITION_CLASSES.enterActive"
      :enter-from-class="MODAL_TRANSITION_CLASSES.enterFrom"
      :enter-to-class="MODAL_TRANSITION_CLASSES.enterTo"
      :leave-active-class="MODAL_TRANSITION_CLASSES.leaveActive"
      :leave-from-class="MODAL_TRANSITION_CLASSES.leaveFrom"
      :leave-to-class="MODAL_TRANSITION_CLASSES.leaveTo"
    >
      <div 
        v-if="open"
        :class="[MODAL_BACKDROP_CLASSES, 'items-end sm:items-center p-0 sm:p-4']"
        :data-testid="testId ? `${testId}-backdrop` : 'modal-backdrop'"
        @click="handleBackdropClick"
      >
        <div 
          :class="contentClasses"
          :data-testid="testId"
          role="dialog"
          aria-modal="true"
          :aria-labelledby="testId ? `${testId}-title` : undefined"
          @click.stop
        >
          <!-- Header Icon (for confirm dialogs) -->
          <div v-if="headerIcon" class="pt-5 px-5">
            <div :class="iconContainerClasses">
              <component :is="headerIcon" :class="iconClasses" />
            </div>
          </div>

          <!-- Header -->
          <div 
            :class="[
              'flex items-center justify-between shrink-0',
              headerIcon ? 'px-5 pb-2 text-center' : 'p-4 border-b border-border'
            ]"
          >
            <div :class="headerIcon && 'w-full'">
              <h2 
                :id="testId ? `${testId}-title` : undefined"
                :class="['text-lg font-semibold', headerIcon && 'text-center']"
              >
                {{ title }}
              </h2>
              <p 
                v-if="description" 
                :class="[
                  'text-sm text-muted-foreground mt-1',
                  headerIcon && 'text-center'
                ]"
              >
                {{ description }}
              </p>
            </div>
            <Button 
              v-if="showCloseButton && !headerIcon"
              variant="ghost" 
              size="icon" 
              class="h-8 w-8 shrink-0" 
              @click="emit('close')"
            >
              <X class="h-4 w-4" />
            </Button>
          </div>
          
          <!-- Body (scrollable) -->
          <div class="flex-1 overflow-auto p-4">
            <slot />
          </div>
          
          <!-- Footer -->
          <div 
            v-if="$slots.footer" 
            class="flex gap-3 p-4 border-t border-border shrink-0"
          >
            <slot name="footer" />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
