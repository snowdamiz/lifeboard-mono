import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'
import type { Task } from '@/types'

export type TimerMode = 'work' | 'break' | 'longBreak'

export interface FocusSession {
  id: string
  taskId: string | null
  taskTitle: string | null
  mode: TimerMode
  duration: number // seconds
  completedAt: Date
}

export const useTimerStore = defineStore('timer', () => {
  // Settings (in minutes)
  const workDuration = ref(25)
  const breakDuration = ref(5)
  const longBreakDuration = ref(15)
  const sessionsUntilLongBreak = ref(4)

  // State
  const isRunning = ref(false)
  const isPaused = ref(false)
  const currentMode = ref<TimerMode>('work')
  const timeRemaining = ref(workDuration.value * 60) // in seconds
  const completedSessions = ref(0)
  const currentTask = ref<{ id: string; title: string } | null>(null)
  const sessions = ref<FocusSession[]>([])
  const isOpen = ref(false)

  // Computed
  const minutes = computed(() => Math.floor(timeRemaining.value / 60))
  const seconds = computed(() => timeRemaining.value % 60)
  const displayTime = computed(() => 
    `${String(minutes.value).padStart(2, '0')}:${String(seconds.value).padStart(2, '0')}`
  )
  const progress = computed(() => {
    const totalSeconds = getCurrentModeDuration() * 60
    return ((totalSeconds - timeRemaining.value) / totalSeconds) * 100
  })

  const totalFocusTime = computed(() => 
    sessions.value
      .filter(s => s.mode === 'work')
      .reduce((sum, s) => sum + s.duration, 0)
  )

  const todaysSessions = computed(() => {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    return sessions.value.filter(s => s.completedAt >= today)
  })

  const todaysFocusTime = computed(() =>
    todaysSessions.value
      .filter(s => s.mode === 'work')
      .reduce((sum, s) => sum + s.duration, 0)
  )

  // Timer interval
  let intervalId: number | null = null

  function getCurrentModeDuration(): number {
    switch (currentMode.value) {
      case 'work': return workDuration.value
      case 'break': return breakDuration.value
      case 'longBreak': return longBreakDuration.value
    }
  }

  function start() {
    if (isRunning.value && !isPaused.value) return

    if (isPaused.value) {
      isPaused.value = false
    }
    
    isRunning.value = true
    
    intervalId = window.setInterval(() => {
      if (timeRemaining.value > 0) {
        timeRemaining.value--
      } else {
        completeSession()
      }
    }, 1000)
  }

  function pause() {
    if (!isRunning.value) return
    isPaused.value = true
    if (intervalId) {
      clearInterval(intervalId)
      intervalId = null
    }
  }

  function stop() {
    isRunning.value = false
    isPaused.value = false
    if (intervalId) {
      clearInterval(intervalId)
      intervalId = null
    }
    resetTimer()
  }

  function resetTimer() {
    timeRemaining.value = getCurrentModeDuration() * 60
  }

  function completeSession() {
    if (intervalId) {
      clearInterval(intervalId)
      intervalId = null
    }

    // Record the session
    const session: FocusSession = {
      id: Date.now().toString(),
      taskId: currentTask.value?.id || null,
      taskTitle: currentTask.value?.title || null,
      mode: currentMode.value,
      duration: getCurrentModeDuration() * 60,
      completedAt: new Date()
    }
    sessions.value.push(session)

    // Play notification sound
    playNotificationSound()

    // Show browser notification
    showNotification()

    // Determine next mode
    if (currentMode.value === 'work') {
      completedSessions.value++
      
      if (completedSessions.value % sessionsUntilLongBreak.value === 0) {
        currentMode.value = 'longBreak'
      } else {
        currentMode.value = 'break'
      }
    } else {
      currentMode.value = 'work'
    }

    isRunning.value = false
    isPaused.value = false
    resetTimer()
  }

  function setMode(mode: TimerMode) {
    if (isRunning.value) {
      stop()
    }
    currentMode.value = mode
    resetTimer()
  }

  function setTask(task: { id: string; title: string } | null) {
    currentTask.value = task
  }

  function clearTask() {
    currentTask.value = null
  }

  function updateSettings(settings: {
    workDuration?: number
    breakDuration?: number
    longBreakDuration?: number
    sessionsUntilLongBreak?: number
  }) {
    if (settings.workDuration) workDuration.value = settings.workDuration
    if (settings.breakDuration) breakDuration.value = settings.breakDuration
    if (settings.longBreakDuration) longBreakDuration.value = settings.longBreakDuration
    if (settings.sessionsUntilLongBreak) sessionsUntilLongBreak.value = settings.sessionsUntilLongBreak
    
    if (!isRunning.value) {
      resetTimer()
    }
  }

  function openTimer() {
    isOpen.value = true
  }

  function closeTimer() {
    isOpen.value = false
  }

  function toggleTimer() {
    isOpen.value = !isOpen.value
  }

  // Helper functions
  function playNotificationSound() {
    try {
      const audio = new Audio('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2teleToGX6jT1IZjGQBFrt3UfF0HAT2v4dJ7XQECPK/j0XtdAgI8r+PRe10CAjyv49F7XQICPK/j0XtdAgI=')
      audio.volume = 0.5
      audio.play()
    } catch {
      // Ignore audio errors
    }
  }

  function showNotification() {
    if ('Notification' in window && Notification.permission === 'granted') {
      const title = currentMode.value === 'work' 
        ? 'Work session complete!' 
        : 'Break time over!'
      const body = currentMode.value === 'work'
        ? 'Time for a break.'
        : 'Ready to focus again?'
      
      new Notification(title, { body, icon: '/favicon.ico' })
    }
  }

  // Request notification permission on store init
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission()
  }

  // Load sessions from localStorage
  const storedSessions = localStorage.getItem('pomodoro-sessions')
  if (storedSessions) {
    try {
      const parsed = JSON.parse(storedSessions)
      sessions.value = parsed.map((s: FocusSession) => ({
        ...s,
        completedAt: new Date(s.completedAt)
      }))
    } catch {
      sessions.value = []
    }
  }

  // Save sessions to localStorage
  watch(sessions, (newSessions) => {
    localStorage.setItem('pomodoro-sessions', JSON.stringify(newSessions))
  }, { deep: true })

  return {
    // Settings
    workDuration,
    breakDuration,
    longBreakDuration,
    sessionsUntilLongBreak,
    // State
    isRunning,
    isPaused,
    currentMode,
    timeRemaining,
    completedSessions,
    currentTask,
    sessions,
    isOpen,
    // Computed
    minutes,
    seconds,
    displayTime,
    progress,
    totalFocusTime,
    todaysSessions,
    todaysFocusTime,
    // Actions
    start,
    pause,
    stop,
    resetTimer,
    setMode,
    setTask,
    clearTask,
    updateSettings,
    openTimer,
    closeTimer,
    toggleTimer
  }
})

