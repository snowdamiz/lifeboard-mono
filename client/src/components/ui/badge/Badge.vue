<script setup lang="ts">
import { computed } from 'vue'
import { cn } from '@/lib/utils'

interface Props {
  variant?: 'default' | 'secondary' | 'destructive' | 'outline' | 'success' | 'warning'
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'default'
})

const classes = computed(() => {
  const base = 'inline-flex items-center rounded-md border px-2 py-0.5 text-[11px] font-semibold tracking-wide uppercase transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2'
  
  const variants = {
    default: 'border-transparent bg-primary/12 text-primary',
    secondary: 'border-transparent bg-secondary text-secondary-foreground',
    destructive: 'border-transparent bg-destructive/12 text-destructive',
    success: 'border-transparent bg-emerald-500/12 text-emerald-600 dark:text-emerald-400',
    warning: 'border-transparent bg-amber-500/12 text-amber-600 dark:text-amber-400',
    outline: 'text-muted-foreground border-border bg-transparent'
  }

  return cn(base, variants[props.variant], props.class)
})
</script>

<template>
  <span :class="classes">
    <slot />
  </span>
</template>
