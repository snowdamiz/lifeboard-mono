<script setup lang="ts">
import { computed } from 'vue'
import { cn } from '@/lib/utils'

interface Props {
  variant?: 'default' | 'destructive' | 'outline' | 'secondary' | 'ghost' | 'link'
  size?: 'default' | 'sm' | 'lg' | 'icon'
  disabled?: boolean
  type?: 'button' | 'submit' | 'reset'
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'default',
  size: 'default',
  disabled: false,
  type: 'button'
})

const classes = computed(() => {
  const base = 'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg text-sm font-medium transition-all duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/70 focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:pointer-events-none disabled:opacity-50'
  
  const variants = {
    default: 'bg-primary text-primary-foreground shadow-sm shadow-primary/20 hover:bg-primary/90 hover:shadow-md hover:shadow-primary/25 active:shadow-sm',
    destructive: 'bg-destructive text-destructive-foreground shadow-sm shadow-destructive/20 hover:bg-destructive/90 hover:shadow-md hover:shadow-destructive/25 active:shadow-sm',
    outline: 'border border-input bg-background hover:bg-secondary hover:border-secondary-foreground/20 hover:text-secondary-foreground active:bg-secondary/80',
    secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/70 active:bg-secondary/90',
    ghost: 'hover:bg-secondary hover:text-foreground active:bg-secondary/80',
    link: 'text-primary underline-offset-4 hover:underline'
  }
  
  const sizes = {
    default: 'h-10 px-5 py-2',
    sm: 'h-8 rounded-md px-3.5 text-[13px]',
    lg: 'h-11 rounded-lg px-8 text-[15px]',
    icon: 'h-10 w-10'
  }

  return cn(base, variants[props.variant], sizes[props.size])
})
</script>

<template>
  <button :type="type" :class="classes" :disabled="disabled">
    <slot />
  </button>
</template>
