<script setup lang="ts">
import { X } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

interface Props {
  open: boolean
  title: string
  submitLabel?: string
  cancelLabel?: string
  submitDisabled?: boolean
  loading?: boolean
  maxWidth?: 'sm' | 'md' | 'lg'
}

const props = withDefaults(defineProps<Props>(), {
  submitLabel: 'Save',
  cancelLabel: 'Cancel',
  submitDisabled: false,
  loading: false,
  maxWidth: 'md'
})

const emit = defineEmits<{
  close: []
  submit: []
}>()

const maxWidthClass = {
  sm: 'sm:max-w-sm',
  md: 'sm:max-w-md',
  lg: 'sm:max-w-lg'
}
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-150 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-100 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div 
        v-if="open"
        class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
        @click="emit('close')"
      >
        <div 
          :class="[
            'w-full bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[90vh] sm:max-h-[85vh] flex flex-col',
            maxWidthClass[maxWidth]
          ]"
          @click.stop
        >
          <!-- Header -->
          <div class="flex items-center justify-between p-4 border-b border-border shrink-0">
            <h2 class="text-lg font-semibold">{{ title }}</h2>
            <Button variant="ghost" size="icon" class="h-8 w-8" @click="emit('close')">
              <X class="h-4 w-4" />
            </Button>
          </div>
          
          <!-- Form Body (scrollable) -->
          <form class="flex-1 overflow-auto p-4 space-y-4" @submit.prevent="emit('submit')">
            <slot />
          </form>
          
          <!-- Footer -->
          <div class="flex gap-3 p-4 border-t border-border shrink-0">
            <slot name="footer">
              <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="emit('close')">
                {{ cancelLabel }}
              </Button>
              <Button 
                type="submit" 
                class="flex-1 sm:flex-none sm:ml-auto" 
                :disabled="submitDisabled || loading"
                @click="emit('submit')"
              >
                <span v-if="loading" class="h-4 w-4 border-2 border-current border-t-transparent rounded-full animate-spin mr-2" />
                {{ submitLabel }}
              </Button>
            </slot>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
