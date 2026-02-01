<script setup lang="ts">
import { AlertTriangle } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

interface Props {
  open: boolean
  title: string
  description?: string
  confirmLabel?: string
  cancelLabel?: string
  variant?: 'danger' | 'warning'
  loading?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  confirmLabel: 'Delete',
  cancelLabel: 'Cancel',
  variant: 'danger',
  loading: false
})

const emit = defineEmits<{
  confirm: []
  cancel: []
}>()
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
        class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
        @click="emit('cancel')"
      >
        <div 
          class="w-full max-w-sm bg-card border border-border rounded-xl shadow-xl p-5"
          @click.stop
        >
          <!-- Icon -->
          <div 
            :class="[
              'h-12 w-12 rounded-full mx-auto mb-4 flex items-center justify-center',
              variant === 'danger' ? 'bg-destructive/10' : 'bg-amber-500/10'
            ]"
          >
            <AlertTriangle 
              :class="[
                'h-6 w-6',
                variant === 'danger' ? 'text-destructive' : 'text-amber-500'
              ]" 
            />
          </div>
          
          <!-- Title -->
          <h3 class="text-lg font-semibold text-center mb-2">{{ title }}</h3>
          
          <!-- Description -->
          <p v-if="description" class="text-sm text-muted-foreground text-center mb-5">
            {{ description }}
          </p>
          
          <!-- Actions -->
          <div class="flex gap-3">
            <Button variant="outline" class="flex-1" @click="emit('cancel')">
              {{ cancelLabel }}
            </Button>
            <Button 
              :variant="variant === 'danger' ? 'destructive' : 'default'"
              class="flex-1"
              :disabled="loading"
              @click="emit('confirm')"
            >
              <span v-if="loading" class="h-4 w-4 border-2 border-current border-t-transparent rounded-full animate-spin mr-2" />
              {{ confirmLabel }}
            </Button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
