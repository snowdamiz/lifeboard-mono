<script setup lang="ts">
import { cn } from '@/lib/utils'

interface Props {
  class?: string
  interactive?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  interactive: false
})
</script>

<template>
  <div :class="cn(
    'rounded-xl border border-border/80 bg-card text-card-foreground shadow-sm',
    props.interactive && 'transition-all duration-150 hover:border-primary/25 hover:shadow-md cursor-pointer',
    props.class
  )">
    <slot />
  </div>
</template>
