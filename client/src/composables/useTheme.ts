import { ref, watch, onMounted } from 'vue'

type Theme = 'light' | 'dark' | 'system'

const theme = ref<Theme>('system')
const resolvedTheme = ref<'light' | 'dark'>('light')

// Check system preference
const getSystemTheme = (): 'light' | 'dark' => {
  if (typeof window !== 'undefined' && window.matchMedia) {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  }
  return 'light'
}

// Apply theme to document
const applyTheme = (newTheme: 'light' | 'dark') => {
  resolvedTheme.value = newTheme
  if (newTheme === 'dark') {
    document.documentElement.classList.add('dark')
  } else {
    document.documentElement.classList.remove('dark')
  }
}

// Update resolved theme based on current setting
const updateResolvedTheme = () => {
  const resolved = theme.value === 'system' ? getSystemTheme() : theme.value
  applyTheme(resolved)
}

// Initialize theme from localStorage
const initTheme = () => {
  const stored = localStorage.getItem('theme') as Theme | null
  if (stored && ['light', 'dark', 'system'].includes(stored)) {
    theme.value = stored
  }
  updateResolvedTheme()
  
  // Listen for system theme changes
  if (typeof window !== 'undefined' && window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
      if (theme.value === 'system') {
        updateResolvedTheme()
      }
    })
  }
}

// Watch for theme changes
watch(theme, (newTheme) => {
  localStorage.setItem('theme', newTheme)
  updateResolvedTheme()
})

export function useTheme() {
  onMounted(() => {
    initTheme()
  })

  const setTheme = (newTheme: Theme) => {
    theme.value = newTheme
  }

  const toggleTheme = () => {
    // Cycle through: light -> dark -> system -> light
    if (theme.value === 'light') {
      theme.value = 'dark'
    } else if (theme.value === 'dark') {
      theme.value = 'system'
    } else {
      theme.value = 'light'
    }
  }

  // Simple toggle between light and dark (ignoring system)
  const toggleLightDark = () => {
    theme.value = resolvedTheme.value === 'light' ? 'dark' : 'light'
  }

  return {
    theme,
    resolvedTheme,
    setTheme,
    toggleTheme,
    toggleLightDark,
  }
}

// Initialize on module load (for SSR-safe immediate init)
if (typeof window !== 'undefined') {
  const stored = localStorage.getItem('theme') as Theme | null
  if (stored && ['light', 'dark', 'system'].includes(stored)) {
    theme.value = stored
  }
  updateResolvedTheme()
}

