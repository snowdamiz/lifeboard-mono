<script setup lang="ts">
import { X, Keyboard } from 'lucide-vue-next'
import { useKeyboardShortcuts } from '@/composables/useKeyboardShortcuts'

const { isHelpOpen, closeHelp, getShortcutsByCategory } = useKeyboardShortcuts()

const formatKey = (key: string) => {
  // Format key for display
  return key
    .replace('Cmd', '⌘')
    .replace('Ctrl', 'Ctrl')
    .replace('Escape', 'Esc')
    .replace('+', ' + ')
    .replace(' ', ' then ')
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
        v-if="isHelpOpen"
        class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
        @click="closeHelp"
      >
        <div 
          class="w-full max-w-lg bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden animate-slide-up"
          @click.stop
        >
          <!-- Header -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-border/60">
            <div class="flex items-center gap-3">
              <div class="h-9 w-9 rounded-lg bg-primary/10 flex items-center justify-center">
                <Keyboard class="h-5 w-5 text-primary" />
              </div>
              <div>
                <h2 class="text-base font-semibold">Keyboard Shortcuts</h2>
                <p class="text-xs text-muted-foreground">Navigate faster with your keyboard</p>
              </div>
            </div>
            <button 
              class="h-8 w-8 rounded-lg hover:bg-secondary flex items-center justify-center text-muted-foreground hover:text-foreground transition-colors"
              @click="closeHelp"
            >
              <X class="h-4 w-4" />
            </button>
          </div>

          <!-- Content -->
          <div class="p-5 max-h-[60vh] overflow-auto scrollbar-thin space-y-5">
            <!-- General -->
            <div>
              <h3 class="text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider mb-2">General</h3>
              <div class="space-y-1">
                <div 
                  v-for="shortcut in getShortcutsByCategory('general')"
                  :key="shortcut.keys[0]"
                  class="flex items-center justify-between py-1.5"
                >
                  <span class="text-sm">{{ shortcut.description }}</span>
                  <div class="flex items-center gap-1.5">
                    <kbd 
                      v-for="key in shortcut.keys" 
                      :key="key"
                      class="px-2 py-0.5 rounded bg-secondary border border-border/50 text-[11px] font-mono text-muted-foreground"
                    >
                      {{ formatKey(key) }}
                    </kbd>
                  </div>
                </div>
              </div>
            </div>

            <!-- Navigation -->
            <div>
              <h3 class="text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider mb-2">Navigation</h3>
              <p class="text-xs text-muted-foreground mb-2">Press <kbd class="px-1.5 py-0.5 rounded bg-secondary text-[10px] font-mono">g</kbd> then a letter to navigate</p>
              <div class="space-y-1">
                <div 
                  v-for="shortcut in getShortcutsByCategory('navigation')"
                  :key="shortcut.keys[0]"
                  class="flex items-center justify-between py-1.5"
                >
                  <span class="text-sm">{{ shortcut.description }}</span>
                  <kbd class="px-2 py-0.5 rounded bg-secondary border border-border/50 text-[11px] font-mono text-muted-foreground">
                    {{ formatKey(shortcut.keys[0]) }}
                  </kbd>
                </div>
              </div>
            </div>

            <!-- Actions -->
            <div>
              <h3 class="text-[11px] font-semibold text-muted-foreground/70 uppercase tracking-wider mb-2">Actions</h3>
              <div class="space-y-1">
                <div 
                  v-for="shortcut in getShortcutsByCategory('actions')"
                  :key="shortcut.keys[0]"
                  class="flex items-center justify-between py-1.5"
                >
                  <span class="text-sm">{{ shortcut.description }}</span>
                  <div class="flex items-center gap-1.5">
                    <kbd 
                      v-for="key in shortcut.keys" 
                      :key="key"
                      class="px-2 py-0.5 rounded bg-secondary border border-border/50 text-[11px] font-mono text-muted-foreground"
                    >
                      {{ formatKey(key) }}
                    </kbd>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Footer -->
          <div class="px-5 py-3 border-t border-border/40 bg-secondary/30">
            <p class="text-[11px] text-muted-foreground/60 text-center">
              Press <kbd class="px-1.5 py-0.5 rounded bg-background/80 border border-border/50 text-[10px] font-mono">?</kbd> anytime to show this dialog
            </p>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

