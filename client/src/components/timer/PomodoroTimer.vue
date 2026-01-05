<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { 
  Timer, Play, Pause, RotateCcw, Settings, X, 
  Coffee, Brain, Zap, ChevronDown
} from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { useTimerStore } from '@/stores/timer'
import { useCalendarStore } from '@/stores/calendar'

const timerStore = useTimerStore()
const calendarStore = useCalendarStore()

const showSettings = ref(false)
const showTaskPicker = ref(false)

// Local settings for editing
const localSettings = ref({
  workDuration: timerStore.workDuration,
  breakDuration: timerStore.breakDuration,
  longBreakDuration: timerStore.longBreakDuration
})

const modeColors = {
  work: { bg: 'bg-primary/10', text: 'text-primary', border: 'border-primary/30', ring: 'bg-primary' },
  break: { bg: 'bg-emerald-500/10', text: 'text-emerald-600', border: 'border-emerald-500/30', ring: 'bg-emerald-500' },
  longBreak: { bg: 'bg-blue-500/10', text: 'text-blue-600', border: 'border-blue-500/30', ring: 'bg-blue-500' }
}

const modeLabels = {
  work: 'Focus',
  break: 'Break',
  longBreak: 'Long Break'
}

const modeIcons = {
  work: Brain,
  break: Coffee,
  longBreak: Zap
}

const currentColors = computed(() => modeColors[timerStore.currentMode])

const todayTasks = computed(() => {
  const today = new Date().toISOString().split('T')[0]
  return calendarStore.tasksByDate[today] || []
})

const formatTime = (seconds: number): string => {
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  if (mins >= 60) {
    const hours = Math.floor(mins / 60)
    const remainingMins = mins % 60
    return `${hours}h ${remainingMins}m`
  }
  return `${mins}m ${secs}s`
}

const handleSaveSettings = () => {
  timerStore.updateSettings(localSettings.value)
  showSettings.value = false
}

const handleSelectTask = (task: { id: string; title: string }) => {
  timerStore.setTask(task)
  showTaskPicker.value = false
}

// Sync local settings when store changes
watch(() => timerStore.workDuration, (val) => {
  localSettings.value.workDuration = val
})
watch(() => timerStore.breakDuration, (val) => {
  localSettings.value.breakDuration = val
})
watch(() => timerStore.longBreakDuration, (val) => {
  localSettings.value.longBreakDuration = val
})
</script>

<template>
  <!-- Timer Button -->
  <Button 
    variant="ghost" 
    size="icon" 
    class="h-9 w-9 text-muted-foreground relative"
    @click="timerStore.toggleTimer"
  >
    <Timer class="h-[18px] w-[18px]" />
    <span 
      v-if="timerStore.isRunning"
      class="absolute -top-0.5 -right-0.5 h-2.5 w-2.5 rounded-full animate-pulse"
      :class="currentColors.ring"
    />
  </Button>

  <!-- Timer Panel -->
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div 
        v-if="timerStore.isOpen"
        class="fixed inset-0 bg-background/40 backdrop-blur-sm z-50"
        @click="timerStore.closeTimer"
      />
    </Transition>

    <Transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0 scale-95 translate-y-4"
      enter-to-class="opacity-100 scale-100 translate-y-0"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100 scale-100 translate-y-0"
      leave-to-class="opacity-0 scale-95 translate-y-4"
    >
      <div 
        v-if="timerStore.isOpen"
        class="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full max-w-sm bg-card border border-border rounded-2xl shadow-xl z-50 overflow-hidden"
        @click.stop
      >
        <!-- Header -->
        <div class="flex items-center justify-between px-4 py-3 border-b border-border">
          <div class="flex items-center gap-2">
            <Timer class="h-5 w-5" :class="currentColors.text" />
            <h2 class="font-semibold">Pomodoro Timer</h2>
          </div>
          <div class="flex items-center gap-1">
            <Button variant="ghost" size="icon" class="h-8 w-8" @click="showSettings = !showSettings">
              <Settings class="h-4 w-4" />
            </Button>
            <Button variant="ghost" size="icon" class="h-8 w-8" @click="timerStore.closeTimer">
              <X class="h-4 w-4" />
            </Button>
          </div>
        </div>

        <!-- Settings Panel -->
        <Transition
          enter-active-class="transition duration-150 ease-out"
          enter-from-class="opacity-0 -translate-y-2"
          enter-to-class="opacity-100 translate-y-0"
          leave-active-class="transition duration-100 ease-in"
          leave-from-class="opacity-100 translate-y-0"
          leave-to-class="opacity-0 -translate-y-2"
        >
          <div v-if="showSettings" class="border-b border-border bg-secondary/30 p-4">
            <h3 class="text-sm font-medium mb-3">Timer Settings (minutes)</h3>
            <div class="grid grid-cols-3 gap-3">
              <div>
                <label class="text-xs text-muted-foreground mb-1 block">Work</label>
                <input 
                  v-model.number="localSettings.workDuration"
                  type="number"
                  min="1"
                  max="60"
                  class="w-full px-2 py-1.5 rounded border border-input bg-background text-sm"
                />
              </div>
              <div>
                <label class="text-xs text-muted-foreground mb-1 block">Break</label>
                <input 
                  v-model.number="localSettings.breakDuration"
                  type="number"
                  min="1"
                  max="30"
                  class="w-full px-2 py-1.5 rounded border border-input bg-background text-sm"
                />
              </div>
              <div>
                <label class="text-xs text-muted-foreground mb-1 block">Long Break</label>
                <input 
                  v-model.number="localSettings.longBreakDuration"
                  type="number"
                  min="1"
                  max="60"
                  class="w-full px-2 py-1.5 rounded border border-input bg-background text-sm"
                />
              </div>
            </div>
            <Button size="sm" class="mt-3 w-full" @click="handleSaveSettings">
              Save Settings
            </Button>
          </div>
        </Transition>

        <!-- Mode Tabs -->
        <div class="flex gap-1 p-2 border-b border-border">
          <button
            v-for="mode in (['work', 'break', 'longBreak'] as const)"
            :key="mode"
            :class="[
              'flex-1 py-2 px-3 rounded-lg text-sm font-medium transition-all',
              timerStore.currentMode === mode
                ? `${modeColors[mode].bg} ${modeColors[mode].text}`
                : 'text-muted-foreground hover:bg-secondary'
            ]"
            @click="timerStore.setMode(mode)"
          >
            {{ modeLabels[mode] }}
          </button>
        </div>

        <!-- Timer Display -->
        <div class="p-6 text-center">
          <!-- Progress Ring -->
          <div class="relative w-48 h-48 mx-auto mb-4">
            <svg class="w-full h-full transform -rotate-90">
              <circle
                cx="96"
                cy="96"
                r="88"
                stroke="currentColor"
                stroke-width="8"
                fill="none"
                class="text-secondary"
              />
              <circle
                cx="96"
                cy="96"
                r="88"
                stroke="currentColor"
                stroke-width="8"
                fill="none"
                stroke-linecap="round"
                :stroke-dasharray="553"
                :stroke-dashoffset="553 - (553 * timerStore.progress) / 100"
                :class="currentColors.text"
                class="transition-all duration-1000"
              />
            </svg>
            <div class="absolute inset-0 flex flex-col items-center justify-center">
              <component :is="modeIcons[timerStore.currentMode]" :class="['h-6 w-6 mb-1', currentColors.text]" />
              <span class="text-4xl font-bold tabular-nums">{{ timerStore.displayTime }}</span>
              <span class="text-sm text-muted-foreground mt-1">{{ modeLabels[timerStore.currentMode] }}</span>
            </div>
          </div>

          <!-- Task Selector -->
          <div class="mb-4">
            <button
              class="w-full flex items-center justify-between px-3 py-2 rounded-lg border border-input hover:bg-secondary/50 transition-colors text-sm"
              @click="showTaskPicker = !showTaskPicker"
            >
              <span v-if="timerStore.currentTask" class="truncate">
                {{ timerStore.currentTask.title }}
              </span>
              <span v-else class="text-muted-foreground">
                Select a task (optional)
              </span>
              <ChevronDown class="h-4 w-4 shrink-0 text-muted-foreground" />
            </button>

            <!-- Task Dropdown -->
            <Transition
              enter-active-class="transition duration-100 ease-out"
              enter-from-class="opacity-0 translate-y-1"
              enter-to-class="opacity-100 translate-y-0"
              leave-active-class="transition duration-75 ease-in"
              leave-from-class="opacity-100 translate-y-0"
              leave-to-class="opacity-0 translate-y-1"
            >
              <div 
                v-if="showTaskPicker" 
                class="mt-1 p-1 rounded-lg border border-border bg-card shadow-lg max-h-40 overflow-auto"
              >
                <button
                  class="w-full text-left px-3 py-2 rounded text-sm hover:bg-secondary transition-colors text-muted-foreground"
                  @click="timerStore.clearTask(); showTaskPicker = false"
                >
                  No task
                </button>
                <button
                  v-for="task in todayTasks"
                  :key="task.id"
                  class="w-full text-left px-3 py-2 rounded text-sm hover:bg-secondary transition-colors truncate"
                  @click="handleSelectTask({ id: task.id, title: task.title })"
                >
                  {{ task.title }}
                </button>
                <div v-if="todayTasks.length === 0" class="px-3 py-2 text-sm text-muted-foreground">
                  No tasks for today
                </div>
              </div>
            </Transition>
          </div>

          <!-- Controls -->
          <div class="flex items-center justify-center gap-3">
            <Button 
              variant="outline" 
              size="icon"
              class="h-12 w-12 rounded-full"
              @click="timerStore.stop"
            >
              <RotateCcw class="h-5 w-5" />
            </Button>
            
            <button 
              v-if="!timerStore.isRunning || timerStore.isPaused"
              :class="[
                'h-16 w-16 rounded-full flex items-center justify-center transition-all',
                'bg-primary text-primary-foreground hover:bg-primary/90 shadow-lg hover:shadow-xl active:scale-95'
              ]"
              @click="timerStore.start"
            >
              <Play class="h-7 w-7 ml-0.5" />
            </button>
            <button 
              v-else
              :class="[
                'h-16 w-16 rounded-full flex items-center justify-center transition-all',
                'bg-primary text-primary-foreground hover:bg-primary/90 shadow-lg hover:shadow-xl active:scale-95'
              ]"
              @click="timerStore.pause"
            >
              <Pause class="h-7 w-7" />
            </button>
          </div>
        </div>

        <!-- Stats Footer -->
        <div class="px-4 py-3 border-t border-border bg-secondary/30 flex items-center justify-between text-sm">
          <div>
            <span class="text-muted-foreground">Today: </span>
            <span class="font-medium">{{ formatTime(timerStore.todaysFocusTime) }}</span>
          </div>
          <div>
            <span class="text-muted-foreground">Sessions: </span>
            <span class="font-medium">{{ timerStore.todaysSessions.filter(s => s.mode === 'work').length }}</span>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

