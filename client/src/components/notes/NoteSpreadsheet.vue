<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { Plus, Minus, Trash, GripVertical, HelpCircle } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

interface CellData {
  value: string
}

interface Props {
  modelValue?: string
  rows?: number
  cols?: number
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  rows: 1,
  cols: 8
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
  'remove': []
}>()

const showHelp = ref(false)
const focusedCell = ref<{ row: number; col: number } | null>(null)
const cellRefs = ref<HTMLInputElement[][]>([])

// ===== FORMULA ENGINE =====

// Convert column letter to index (A=0, B=1, etc.)
const colToIndex = (col: string): number => {
  let result = 0
  for (let i = 0; i < col.length; i++) {
    result = result * 26 + (col.charCodeAt(i) - 64)
  }
  return result - 1
}

// Convert index to column letter
const indexToCol = (index: number): string => {
  let result = ''
  let n = index + 1
  while (n > 0) {
    n--
    result = String.fromCharCode(65 + (n % 26)) + result
    n = Math.floor(n / 26)
  }
  return result
}

// Parse cell reference like "A1" to { col: 0, row: 0 }
const parseCellRef = (ref: string): { col: number; row: number } | null => {
  const match = ref.match(/^([A-Z]+)(\d+)$/i)
  if (!match) return null
  return {
    col: colToIndex(match[1].toUpperCase()),
    row: parseInt(match[2], 10) - 1
  }
}

// Parse range like "A1:B3" to array of cell references
const parseRange = (range: string, data: CellData[][]): number[] => {
  const [start, end] = range.split(':')
  const startRef = parseCellRef(start)
  const endRef = parseCellRef(end)
  
  if (!startRef || !endRef) return []
  
  const values: number[] = []
  for (let r = startRef.row; r <= endRef.row; r++) {
    for (let c = startRef.col; c <= endRef.col; c++) {
      if (data[r]?.[c]) {
        const val = getCellNumericValue(data[r][c].value, data)
        if (!isNaN(val)) values.push(val)
      }
    }
  }
  return values
}

// Get numeric value from a cell (resolving formulas)
const getCellNumericValue = (value: string, data: CellData[][], visited: Set<string> = new Set()): number => {
  if (!value) return 0
  
  // Check for circular reference
  if (visited.has(value)) return NaN
  
  // If it's a formula, evaluate it
  if (value.startsWith('=')) {
    const result = evaluateFormula(value, data, new Set(visited))
    return typeof result === 'number' ? result : parseFloat(result) || 0
  }
  
  // Try to parse as number
  const num = parseFloat(value)
  return isNaN(num) ? 0 : num
}

// Get string value from a cell
const getCellStringValue = (value: string, data: CellData[][]): string => {
  if (!value) return ''
  if (value.startsWith('=')) {
    const result = evaluateFormula(value, data)
    return String(result)
  }
  return value
}

// Parse arguments from formula, handling nested parentheses
const parseArguments = (argsStr: string): string[] => {
  const args: string[] = []
  let current = ''
  let depth = 0
  
  for (const char of argsStr) {
    if (char === '(') {
      depth++
      current += char
    } else if (char === ')') {
      depth--
      current += char
    } else if (char === ',' && depth === 0) {
      args.push(current.trim())
      current = ''
    } else {
      current += char
    }
  }
  if (current.trim()) args.push(current.trim())
  return args
}

// Get values from arguments (handling ranges, cell refs, and literals)
const getArgValues = (args: string[], data: CellData[][]): number[] => {
  const values: number[] = []
  for (const arg of args) {
    if (arg.includes(':')) {
      // It's a range
      values.push(...parseRange(arg, data))
    } else {
      const ref = parseCellRef(arg)
      if (ref && data[ref.row]?.[ref.col]) {
        const val = getCellNumericValue(data[ref.row][ref.col].value, data)
        if (!isNaN(val)) values.push(val)
      } else {
        // Try as literal number
        const num = parseFloat(arg)
        if (!isNaN(num)) values.push(num)
      }
    }
  }
  return values
}

// Get string values from arguments
const getStringArgValues = (args: string[], data: CellData[][]): string[] => {
  const values: string[] = []
  for (const arg of args) {
    if (arg.includes(':')) {
      // Range of strings
      const [start, end] = arg.split(':')
      const startRef = parseCellRef(start)
      const endRef = parseCellRef(end)
      if (startRef && endRef) {
        for (let r = startRef.row; r <= endRef.row; r++) {
          for (let c = startRef.col; c <= endRef.col; c++) {
            if (data[r]?.[c]) {
              values.push(getCellStringValue(data[r][c].value, data))
            }
          }
        }
      }
    } else {
      const ref = parseCellRef(arg)
      if (ref && data[ref.row]?.[ref.col]) {
        values.push(getCellStringValue(data[ref.row][ref.col].value, data))
      } else {
        // String literal (remove quotes if present)
        values.push(arg.replace(/^["']|["']$/g, ''))
      }
    }
  }
  return values
}

// ===== FORMULA FUNCTIONS =====

const formulaFunctions: Record<string, (args: string[], data: CellData[][]) => number | string> = {
  // Math Functions
  SUM: (args, data) => getArgValues(args, data).reduce((a, b) => a + b, 0),
  
  AVERAGE: (args, data) => {
    const vals = getArgValues(args, data)
    return vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length : 0
  },
  
  COUNT: (args, data) => getArgValues(args, data).length,
  
  COUNTA: (args, data) => getStringArgValues(args, data).filter(v => v !== '').length,
  
  MAX: (args, data) => Math.max(...getArgValues(args, data)),
  
  MIN: (args, data) => Math.min(...getArgValues(args, data)),
  
  ABS: (args, data) => Math.abs(getArgValues(args, data)[0] || 0),
  
  ROUND: (args, data) => {
    const vals = getArgValues(args, data)
    const num = vals[0] || 0
    const decimals = vals[1] || 0
    return Math.round(num * Math.pow(10, decimals)) / Math.pow(10, decimals)
  },
  
  FLOOR: (args, data) => Math.floor(getArgValues(args, data)[0] || 0),
  
  CEILING: (args, data) => Math.ceil(getArgValues(args, data)[0] || 0),
  
  SQRT: (args, data) => Math.sqrt(getArgValues(args, data)[0] || 0),
  
  POWER: (args, data) => {
    const vals = getArgValues(args, data)
    return Math.pow(vals[0] || 0, vals[1] || 1)
  },
  
  MOD: (args, data) => {
    const vals = getArgValues(args, data)
    return vals[0] % vals[1]
  },
  
  PRODUCT: (args, data) => getArgValues(args, data).reduce((a, b) => a * b, 1),
  
  MEDIAN: (args, data) => {
    const vals = getArgValues(args, data).sort((a, b) => a - b)
    if (vals.length === 0) return 0
    const mid = Math.floor(vals.length / 2)
    return vals.length % 2 ? vals[mid] : (vals[mid - 1] + vals[mid]) / 2
  },
  
  STDEV: (args, data) => {
    const vals = getArgValues(args, data)
    if (vals.length < 2) return 0
    const mean = vals.reduce((a, b) => a + b, 0) / vals.length
    const squareDiffs = vals.map(v => Math.pow(v - mean, 2))
    return Math.sqrt(squareDiffs.reduce((a, b) => a + b, 0) / (vals.length - 1))
  },
  
  VAR: (args, data) => {
    const vals = getArgValues(args, data)
    if (vals.length < 2) return 0
    const mean = vals.reduce((a, b) => a + b, 0) / vals.length
    const squareDiffs = vals.map(v => Math.pow(v - mean, 2))
    return squareDiffs.reduce((a, b) => a + b, 0) / (vals.length - 1)
  },
  
  // Logical Functions
  IF: (args, data) => {
    const condition = getArgValues([args[0]], data)[0]
    return condition ? getArgValues([args[1]], data)[0] || args[1]?.replace(/^["']|["']$/g, '') || 0 
                     : getArgValues([args[2]], data)[0] || args[2]?.replace(/^["']|["']$/g, '') || 0
  },
  
  AND: (args, data) => getArgValues(args, data).every(v => v !== 0) ? 1 : 0,
  
  OR: (args, data) => getArgValues(args, data).some(v => v !== 0) ? 1 : 0,
  
  NOT: (args, data) => getArgValues(args, data)[0] === 0 ? 1 : 0,
  
  // Text Functions
  CONCAT: (args, data) => getStringArgValues(args, data).join(''),
  
  CONCATENATE: (args, data) => getStringArgValues(args, data).join(''),
  
  UPPER: (args, data) => getStringArgValues(args, data)[0]?.toUpperCase() || '',
  
  LOWER: (args, data) => getStringArgValues(args, data)[0]?.toLowerCase() || '',
  
  PROPER: (args, data) => {
    const str = getStringArgValues(args, data)[0] || ''
    return str.replace(/\w\S*/g, txt => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase())
  },
  
  TRIM: (args, data) => getStringArgValues(args, data)[0]?.trim() || '',
  
  LEN: (args, data) => getStringArgValues(args, data)[0]?.length || 0,
  
  LEFT: (args, data) => {
    const str = getStringArgValues([args[0]], data)[0] || ''
    const count = getArgValues([args[1]], data)[0] || 1
    return str.substring(0, count)
  },
  
  RIGHT: (args, data) => {
    const str = getStringArgValues([args[0]], data)[0] || ''
    const count = getArgValues([args[1]], data)[0] || 1
    return str.substring(str.length - count)
  },
  
  MID: (args, data) => {
    const str = getStringArgValues([args[0]], data)[0] || ''
    const start = getArgValues([args[1]], data)[0] || 1
    const count = getArgValues([args[2]], data)[0] || 1
    return str.substring(start - 1, start - 1 + count)
  },
  
  SUBSTITUTE: (args, data) => {
    const strs = getStringArgValues(args, data)
    return strs[0]?.replace(new RegExp(strs[1], 'g'), strs[2] || '') || ''
  },
  
  REPT: (args, data) => {
    const str = getStringArgValues([args[0]], data)[0] || ''
    const times = getArgValues([args[1]], data)[0] || 1
    return str.repeat(Math.max(0, Math.floor(times)))
  },
  
  // Lookup Functions
  UNIQUE: (args, data) => {
    const vals = getStringArgValues(args, data)
    return [...new Set(vals)].join(', ')
  },
  
  COUNTIF: (args, data) => {
    const vals = getStringArgValues([args[0]], data)
    const criteria = args[1]?.replace(/^["']|["']$/g, '') || ''
    return vals.filter(v => v === criteria).length
  },
  
  SUMIF: (args, data) => {
    // SUMIF(range, criteria, [sum_range])
    const rangeVals = getStringArgValues([args[0]], data)
    const criteria = args[1]?.replace(/^["']|["']$/g, '') || ''
    const sumRangeVals = args[2] ? getArgValues([args[2]], data) : getArgValues([args[0]], data)
    
    let sum = 0
    for (let i = 0; i < rangeVals.length; i++) {
      if (rangeVals[i] === criteria && sumRangeVals[i] !== undefined) {
        sum += sumRangeVals[i]
      }
    }
    return sum
  },
  
  // Date Functions (basic)
  TODAY: () => new Date().toISOString().split('T')[0],
  
  NOW: () => new Date().toISOString().replace('T', ' ').substring(0, 19),
  
  YEAR: (args, data) => {
    const dateStr = getStringArgValues(args, data)[0]
    return dateStr ? new Date(dateStr).getFullYear() : new Date().getFullYear()
  },
  
  MONTH: (args, data) => {
    const dateStr = getStringArgValues(args, data)[0]
    return dateStr ? new Date(dateStr).getMonth() + 1 : new Date().getMonth() + 1
  },
  
  DAY: (args, data) => {
    const dateStr = getStringArgValues(args, data)[0]
    return dateStr ? new Date(dateStr).getDate() : new Date().getDate()
  },
  
  // Financial Functions
  ROUND2: (args, data) => {
    const num = getArgValues(args, data)[0] || 0
    return Math.round(num * 100) / 100
  },
  
  // Random
  RAND: () => Math.random(),
  
  RANDBETWEEN: (args, data) => {
    const vals = getArgValues(args, data)
    const min = vals[0] || 0
    const max = vals[1] || 1
    return Math.floor(Math.random() * (max - min + 1)) + min
  },
  
  // Info Functions
  ISNUMBER: (args, data) => !isNaN(getArgValues(args, data)[0]) ? 1 : 0,
  
  ISBLANK: (args, data) => getStringArgValues(args, data)[0] === '' ? 1 : 0,
}

// Evaluate a formula
const evaluateFormula = (formula: string, data: CellData[][], visited: Set<string> = new Set()): number | string => {
  if (!formula.startsWith('=')) return formula
  
  const expr = formula.substring(1).trim().toUpperCase()
  
  // Check for function call
  const funcMatch = expr.match(/^([A-Z]+)\((.*)\)$/s)
  if (funcMatch) {
    const funcName = funcMatch[1]
    const argsStr = funcMatch[2]
    const args = parseArguments(argsStr)
    
    if (formulaFunctions[funcName]) {
      try {
        return formulaFunctions[funcName](args, data)
      } catch (e) {
        return '#ERROR!'
      }
    }
    return '#NAME?'
  }
  
  // Check for simple cell reference
  const cellRef = parseCellRef(expr)
  if (cellRef && data[cellRef.row]?.[cellRef.col]) {
    const cellKey = `${cellRef.row},${cellRef.col}`
    if (visited.has(cellKey)) return '#REF!'
    visited.add(cellKey)
    return getCellNumericValue(data[cellRef.row][cellRef.col].value, data, visited)
  }
  
  // Check for simple arithmetic with cell refs
  const arithmeticMatch = expr.match(/^([A-Z]+\d+)\s*([\+\-\*\/])\s*([A-Z]+\d+|\d+\.?\d*)$/)
  if (arithmeticMatch) {
    const left = parseCellRef(arithmeticMatch[1])
    const op = arithmeticMatch[2]
    const rightVal = parseCellRef(arithmeticMatch[3])
    
    const leftNum = left && data[left.row]?.[left.col] 
      ? getCellNumericValue(data[left.row][left.col].value, data, visited) 
      : 0
    const rightNum = rightVal && data[rightVal.row]?.[rightVal.col]
      ? getCellNumericValue(data[rightVal.row][rightVal.col].value, data, visited)
      : parseFloat(arithmeticMatch[3]) || 0
    
    switch (op) {
      case '+': return leftNum + rightNum
      case '-': return leftNum - rightNum
      case '*': return leftNum * rightNum
      case '/': return rightNum !== 0 ? leftNum / rightNum : '#DIV/0!'
    }
  }
  
  // Try as literal number
  const num = parseFloat(expr)
  if (!isNaN(num)) return num
  
  return '#VALUE!'
}

// Get display value for a cell
const getDisplayValue = (rowIndex: number, colIndex: number): string => {
  const cellValue = data.value[rowIndex]?.[colIndex]?.value || ''
  if (!cellValue.startsWith('=')) return cellValue
  
  const result = evaluateFormula(cellValue, data.value)
  if (typeof result === 'number') {
    // Format nicely - avoid floating point issues
    return Number.isInteger(result) ? String(result) : result.toFixed(4).replace(/\.?0+$/, '')
  }
  return String(result)
}

// Check if cell has a formula
const isFormula = (rowIndex: number, colIndex: number): boolean => {
  return data.value[rowIndex]?.[colIndex]?.value?.startsWith('=') || false
}

// ===== DATA MANAGEMENT =====

// Parse data from JSON string or initialize empty grid
const parseData = (value: string): CellData[][] => {
  if (!value) {
    return Array(props.rows).fill(null).map(() => 
      Array(props.cols).fill(null).map(() => ({ value: '' }))
    )
  }
  try {
    const parsed = JSON.parse(value)
    return parsed.data || []
  } catch {
    return Array(props.rows).fill(null).map(() => 
      Array(props.cols).fill(null).map(() => ({ value: '' }))
    )
  }
}

const data = ref<CellData[][]>(parseData(props.modelValue))

const rowCount = computed(() => data.value.length)
const colCount = computed(() => data.value[0]?.length || props.cols)

// Serialize data to JSON
const serializeData = () => {
  return JSON.stringify({ data: data.value })
}

// Update cell value
const updateCell = (rowIndex: number, colIndex: number, value: string) => {
  data.value[rowIndex][colIndex].value = value
  
  // Auto-expand column if typing in last column
  if (colIndex === colCount.value - 1 && value) {
    addColumn()
  }
  
  emit('update:modelValue', serializeData())
}

// Add row at the end
const addRow = () => {
  const newRow = Array(colCount.value).fill(null).map(() => ({ value: '' }))
  data.value.push(newRow)
  emit('update:modelValue', serializeData())
}

// Remove last row
const removeRow = () => {
  if (rowCount.value > 1) {
    data.value.pop()
    emit('update:modelValue', serializeData())
  }
}

// Add column at the end
const addColumn = () => {
  data.value.forEach(row => {
    row.push({ value: '' })
  })
  emit('update:modelValue', serializeData())
}

// Remove last column
const removeColumn = () => {
  if (colCount.value > 1) {
    data.value.forEach(row => {
      row.pop()
    })
    emit('update:modelValue', serializeData())
  }
}

// Generate column headers (A, B, C, ...)
const getColumnHeader = (index: number): string => {
  return indexToCol(index)
}

// Watch for external updates
watch(() => props.modelValue, (newValue) => {
  const parsed = parseData(newValue)
  if (JSON.stringify(parsed) !== JSON.stringify(data.value)) {
    data.value = parsed
  }
})

// Handle keyboard navigation for auto-expansion
const handleKeydown = (event: KeyboardEvent, rowIndex: number, colIndex: number) => {
  const input = event.target as HTMLInputElement
  
  switch (event.key) {
    case 'ArrowDown':
    case 'Enter':
      event.preventDefault()
      // If at last row, add a new row
      if (rowIndex === rowCount.value - 1) {
        addRow()
      }
      // Focus next row
      setTimeout(() => {
        const nextRow = document.querySelector(
          `[data-cell="${rowIndex + 1}-${colIndex}"]`
        ) as HTMLInputElement
        nextRow?.focus()
      }, 0)
      break
      
    case 'ArrowUp':
      event.preventDefault()
      if (rowIndex > 0) {
        const prevRow = document.querySelector(
          `[data-cell="${rowIndex - 1}-${colIndex}"]`
        ) as HTMLInputElement
        prevRow?.focus()
      }
      break
      
    case 'ArrowRight':
      // Only navigate if cursor is at end of input
      if (input.selectionStart === input.value.length) {
        event.preventDefault()
        if (colIndex === colCount.value - 1) {
          addColumn()
        }
        setTimeout(() => {
          const nextCol = document.querySelector(
            `[data-cell="${rowIndex}-${colIndex + 1}"]`
          ) as HTMLInputElement
          nextCol?.focus()
        }, 0)
      }
      break
      
    case 'ArrowLeft':
      // Only navigate if cursor is at start of input
      if (input.selectionStart === 0 && colIndex > 0) {
        event.preventDefault()
        const prevCol = document.querySelector(
          `[data-cell="${rowIndex}-${colIndex - 1}"]`
        ) as HTMLInputElement
        prevCol?.focus()
      }
      break
      
    case 'Tab':
      // Tab to next cell, expand if needed
      if (!event.shiftKey && colIndex === colCount.value - 1) {
        // At last column, go to next row
        if (rowIndex === rowCount.value - 1) {
          addRow()
        }
      }
      break
  }
}

// Available functions for help display
const availableFunctions = [
  { name: 'SUM', desc: 'Sum of values', example: '=SUM(A1:A5)' },
  { name: 'AVERAGE', desc: 'Average of values', example: '=AVERAGE(A1:A5)' },
  { name: 'COUNT', desc: 'Count numbers', example: '=COUNT(A1:A5)' },
  { name: 'MAX/MIN', desc: 'Maximum/Minimum', example: '=MAX(A1:A5)' },
  { name: 'IF', desc: 'Conditional', example: '=IF(A1>10,"Yes","No")' },
  { name: 'UNIQUE', desc: 'Unique values', example: '=UNIQUE(A1:A5)' },
  { name: 'CONCAT', desc: 'Join text', example: '=CONCAT(A1,B1)' },
  { name: 'ROUND', desc: 'Round number', example: '=ROUND(A1,2)' },
  { name: 'TODAY/NOW', desc: 'Current date/time', example: '=TODAY()' },
]
</script>

<template>
  <div class="note-spreadsheet border border-border rounded-xl overflow-hidden bg-card/50 my-4">
    <!-- Header with controls -->
    <div class="flex items-center justify-between px-3 py-2 bg-secondary/30 border-b border-border">
      <div class="flex items-center gap-1.5 text-xs text-muted-foreground">
        <GripVertical class="h-4 w-4" />
        <span class="font-medium">Spreadsheet</span>
        <span class="opacity-60">({{ rowCount }} × {{ colCount }})</span>
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-5 w-5 ml-1"
          @click="showHelp = !showHelp"
        >
          <HelpCircle class="h-3.5 w-3.5" />
        </Button>
      </div>
      <div class="flex items-center gap-1">
        <Button variant="ghost" size="sm" class="h-6 px-2 text-xs" @click="addRow">
          <Plus class="h-3 w-3 mr-1" />Row
        </Button>
        <Button variant="ghost" size="sm" class="h-6 px-2 text-xs" @click="addColumn">
          <Plus class="h-3 w-3 mr-1" />Col
        </Button>
        <div class="w-px h-4 bg-border mx-1" />
        <Button variant="ghost" size="sm" class="h-6 px-2 text-xs text-muted-foreground" :disabled="rowCount <= 1" @click="removeRow">
          <Minus class="h-3 w-3 mr-1" />Row
        </Button>
        <Button variant="ghost" size="sm" class="h-6 px-2 text-xs text-muted-foreground" :disabled="colCount <= 1" @click="removeColumn">
          <Minus class="h-3 w-3 mr-1" />Col
        </Button>
        <div class="w-px h-4 bg-border mx-1" />
        <Button variant="ghost" size="icon" class="h-6 w-6 text-destructive hover:text-destructive" @click="$emit('remove')">
          <Trash class="h-3 w-3" />
        </Button>
      </div>
    </div>

    <!-- Formula Bar -->
    <div v-if="focusedCell" class="px-3 py-1.5 bg-secondary/20 border-b border-border text-xs flex items-center gap-2">
      <span class="font-mono font-medium text-primary">{{ getColumnHeader(focusedCell.col) }}{{ focusedCell.row + 1 }}</span>
      <span class="text-muted-foreground">=</span>
      <span class="font-mono flex-1 truncate">{{ data[focusedCell.row]?.[focusedCell.col]?.value || '' }}</span>
    </div>

    <!-- Help Panel -->
    <div v-if="showHelp" class="px-3 py-2 bg-primary/5 border-b border-border">
      <p class="text-xs font-medium mb-1.5">Available Functions (start with =)</p>
      <div class="grid grid-cols-3 gap-1.5 text-xs">
        <div v-for="fn in availableFunctions" :key="fn.name" class="flex flex-col">
          <span class="font-mono text-primary">{{ fn.name }}</span>
          <span class="text-muted-foreground text-[10px]">{{ fn.example }}</span>
        </div>
      </div>
      <p class="text-[10px] text-muted-foreground mt-2">
        Also: STDEV, VAR, MEDIAN, PRODUCT, MOD, POWER, SQRT, AND, OR, NOT, UPPER, LOWER, TRIM, LEN, LEFT, RIGHT, MID, COUNTIF, SUMIF, YEAR, MONTH, DAY, RAND, RANDBETWEEN
      </p>
    </div>

    <!-- Spreadsheet Grid -->
    <div class="overflow-x-auto">
      <table class="w-full border-collapse text-sm">
        <!-- Column Headers -->
        <thead>
          <tr>
            <th class="w-10 min-w-[40px] bg-secondary/30 border-b border-r border-border text-center text-xs font-medium text-muted-foreground py-1.5"></th>
            <th 
              v-for="colIndex in colCount" 
              :key="colIndex"
              class="min-w-[100px] bg-secondary/30 border-b border-r border-border text-center text-xs font-medium text-muted-foreground py-1.5"
            >
              {{ getColumnHeader(colIndex - 1) }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(row, rowIndex) in data" :key="rowIndex">
            <!-- Row number -->
            <td class="w-10 bg-secondary/30 border-b border-r border-border text-center text-xs font-medium text-muted-foreground py-1">
              {{ rowIndex + 1 }}
            </td>
            <!-- Cells -->
            <td 
              v-for="(cell, colIndex) in row" 
              :key="colIndex"
              class="border-b border-r border-border p-0 relative"
              :class="{ 'bg-primary/5': isFormula(rowIndex, colIndex) }"
            >
              <input
                type="text"
                :data-cell="`${rowIndex}-${colIndex}`"
                :value="focusedCell?.row === rowIndex && focusedCell?.col === colIndex ? cell.value : getDisplayValue(rowIndex, colIndex)"
                @input="updateCell(rowIndex, colIndex, ($event.target as HTMLInputElement).value)"
                @focus="focusedCell = { row: rowIndex, col: colIndex }"
                @blur="focusedCell = null"
                @keydown="handleKeydown($event, rowIndex, colIndex)"
                class="w-full h-full px-2 py-1.5 bg-transparent outline-none focus:bg-primary/5 focus:ring-1 focus:ring-primary/30 transition-colors text-sm"
                :class="{ 'text-primary font-medium': isFormula(rowIndex, colIndex) && !(focusedCell?.row === rowIndex && focusedCell?.col === colIndex) }"
                placeholder=""
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.note-spreadsheet table {
  table-layout: fixed;
}

.note-spreadsheet input::placeholder {
  color: transparent;
}

.note-spreadsheet input:focus::placeholder {
  color: hsl(var(--muted-foreground) / 0.4);
}

.note-spreadsheet td:last-child,
.note-spreadsheet th:last-child {
  border-right: none;
}

.note-spreadsheet tr:last-child td {
  border-bottom: none;
}
</style>
