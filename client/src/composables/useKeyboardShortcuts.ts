import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useSearchStore } from '@/stores/search'

export interface Shortcut {
  keys: string[]
  description: string
  action: () => void
  category: 'navigation' | 'actions' | 'general'
}

const isHelpOpen = ref(false)

export function useKeyboardShortcuts() {
  const router = useRouter()
  const searchStore = useSearchStore()
  
  // Track pressed keys for multi-key shortcuts (e.g., "g then c")
  let lastKey = ''
  let lastKeyTime = 0
  
  const shortcuts: Shortcut[] = [
    // General
    {
      keys: ['Ctrl+K', 'Cmd+K'],
      description: 'Open command palette',
      action: () => searchStore.openSearch(),
      category: 'general'
    },
    {
      keys: ['?'],
      description: 'Show keyboard shortcuts',
      action: () => { isHelpOpen.value = true },
      category: 'general'
    },
    {
      keys: ['Escape'],
      description: 'Close dialog / Go back',
      action: () => {
        if (isHelpOpen.value) {
          isHelpOpen.value = false
        } else if (searchStore.isOpen) {
          searchStore.closeSearch()
        }
      },
      category: 'general'
    },
    
    // Navigation (g + key)
    {
      keys: ['g h'],
      description: 'Go to Dashboard',
      action: () => router.push('/'),
      category: 'navigation'
    },
    {
      keys: ['g c'],
      description: 'Go to Calendar',
      action: () => router.push('/calendar'),
      category: 'navigation'
    },
    {
      keys: ['g i'],
      description: 'Go to Inventory',
      action: () => router.push('/inventory'),
      category: 'navigation'
    },
    {
      keys: ['g b'],
      description: 'Go to Budget',
      action: () => router.push('/budget'),
      category: 'navigation'
    },
    {
      keys: ['g n'],
      description: 'Go to Notes',
      action: () => router.push('/notes'),
      category: 'navigation'
    },
    {
      keys: ['g s'],
      description: 'Go to Shopping List',
      action: () => router.push('/inventory/shopping-list'),
      category: 'navigation'
    },
    {
      keys: ['g o'],
      description: 'Go to Goals',
      action: () => router.push('/goals'),
      category: 'navigation'
    },
    
    // Actions
    {
      keys: ['Ctrl+N', 'Cmd+N'],
      description: 'New task (opens command palette)',
      action: () => {
        searchStore.openSearch()
        // The command palette will handle the rest
      },
      category: 'actions'
    },
  ]
  
  const handleKeydown = (e: KeyboardEvent) => {
    // Ignore if typing in an input
    const target = e.target as HTMLElement
    if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable) {
      // But still handle Escape
      if (e.key === 'Escape') {
        if (isHelpOpen.value) {
          isHelpOpen.value = false
          e.preventDefault()
        }
      }
      return
    }
    
    const now = Date.now()
    const key = e.key.toLowerCase()
    
    // Check for Ctrl/Cmd + key shortcuts
    if (e.ctrlKey || e.metaKey) {
      const modKey = e.metaKey ? 'Cmd' : 'Ctrl'
      const combo = `${modKey}+${key.toUpperCase()}`
      
      for (const shortcut of shortcuts) {
        if (shortcut.keys.includes(combo)) {
          e.preventDefault()
          shortcut.action()
          return
        }
      }
    }
    
    // Check for "g then X" navigation shortcuts
    if (lastKey === 'g' && now - lastKeyTime < 1000) {
      const combo = `g ${key}`
      for (const shortcut of shortcuts) {
        if (shortcut.keys.includes(combo)) {
          e.preventDefault()
          shortcut.action()
          lastKey = ''
          return
        }
      }
    }
    
    // Check for single key shortcuts
    if (!e.ctrlKey && !e.metaKey && !e.altKey) {
      if (key === '?') {
        e.preventDefault()
        isHelpOpen.value = true
        return
      }
      
      if (key === 'escape') {
        for (const shortcut of shortcuts) {
          if (shortcut.keys.includes('Escape')) {
            shortcut.action()
            return
          }
        }
      }
    }
    
    // Track last key for multi-key shortcuts
    lastKey = key
    lastKeyTime = now
  }
  
  const closeHelp = () => {
    isHelpOpen.value = false
  }
  
  const getShortcutsByCategory = (category: Shortcut['category']) => {
    return shortcuts.filter(s => s.category === category)
  }
  
  onMounted(() => {
    document.addEventListener('keydown', handleKeydown)
  })
  
  onUnmounted(() => {
    document.removeEventListener('keydown', handleKeydown)
  })
  
  return {
    shortcuts,
    isHelpOpen,
    closeHelp,
    getShortcutsByCategory
  }
}

