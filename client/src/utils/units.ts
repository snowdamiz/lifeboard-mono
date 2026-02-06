/**
 * Default unit measurements available in the system
 * These are pre-made options that show by default in unit dropdowns
 */
export const DEFAULT_UNIT_MEASUREMENTS = [
    // Weight
    { name: 'oz', category: 'weight', displayName: 'oz (ounces)' },
    { name: 'lb', category: 'weight', displayName: 'lb (pounds)' },
    { name: 'g', category: 'weight', displayName: 'g (grams)' },
    { name: 'kg', category: 'weight', displayName: 'kg (kilograms)' },

    // Volume
    { name: 'fl oz', category: 'volume', displayName: 'fl oz (fluid ounces)' },
    { name: 'ml', category: 'volume', displayName: 'ml (milliliters)' },
    { name: 'L', category: 'volume', displayName: 'L (liters)' },
    { name: 'gal', category: 'volume', displayName: 'gal (gallons)' },
    { name: 'qt', category: 'volume', displayName: 'qt (quarts)' },
    { name: 'pt', category: 'volume', displayName: 'pt (pints)' },
    { name: 'cup', category: 'volume', displayName: 'cup' },

    // Count/Quantity
    { name: 'ct', category: 'count', displayName: 'ct (count)' },
    { name: 'ea', category: 'count', displayName: 'ea (each)' },
    { name: 'pk', category: 'count', displayName: 'pk (pack)' },
    { name: 'dz', category: 'count', displayName: 'dz (dozen)' },
    { name: 'box', category: 'count', displayName: 'box' },
    { name: 'bag', category: 'count', displayName: 'bag' },
    { name: 'roll', category: 'count', displayName: 'roll' },
    { name: 'sheet', category: 'count', displayName: 'sheet' },
    { name: 'pair', category: 'count', displayName: 'pair' },
    { name: 'set', category: 'count', displayName: 'set' },

    // Length
    { name: 'in', category: 'length', displayName: 'in (inches)' },
    { name: 'ft', category: 'length', displayName: 'ft (feet)' },
    { name: 'yd', category: 'length', displayName: 'yd (yards)' },
    { name: 'm', category: 'length', displayName: 'm (meters)' },
    { name: 'cm', category: 'length', displayName: 'cm (centimeters)' },

    // Area
    { name: 'sq ft', category: 'area', displayName: 'sq ft (square feet)' },
    { name: 'sq in', category: 'area', displayName: 'sq in (square inches)' },

    // Other common
    { name: 'serving', category: 'other', displayName: 'serving' },
    { name: 'portion', category: 'other', displayName: 'portion' },
    { name: 'slice', category: 'other', displayName: 'slice' },
    { name: 'piece', category: 'other', displayName: 'piece' },
    { name: 'load', category: 'other', displayName: 'load' }
] as const

export type DefaultUnit = typeof DEFAULT_UNIT_MEASUREMENTS[number]

/**
 * Get all default unit names as a simple array
 */
export const getDefaultUnitNames = (): string[] =>
    DEFAULT_UNIT_MEASUREMENTS.map(u => u.name)

/**
 * Check if a unit name is one of the defaults
 */
export const isDefaultUnit = (name: string): boolean =>
    DEFAULT_UNIT_MEASUREMENTS.some(u => u.name.toLowerCase() === name.toLowerCase())

/**
 * Merge default units with custom units from the store
 * Returns defaults first, then any custom units not in defaults
 */
export const mergeUnitsWithDefaults = (customUnits: Array<{ name: string; id?: string }>): Array<{ name: string; id?: string; isDefault?: boolean }> => {
    const defaultUnitNames = new Set(getDefaultUnitNames().map(n => n.toLowerCase()))

    // Start with defaults (marked as such)
    const result: Array<{ name: string; id?: string; isDefault?: boolean }> =
        DEFAULT_UNIT_MEASUREMENTS.map(u => ({ name: u.name, isDefault: true }))

    // Add any custom units that aren't already in defaults
    customUnits.forEach(u => {
        if (!defaultUnitNames.has(u.name.toLowerCase())) {
            result.push({ ...u, isDefault: false })
        }
    })

    return result
}

/**
 * Count unit options - container types for the "count" measurement
 * These represent how items are packaged (e.g., "1 package of 16oz")
 */
export const COUNT_UNIT_OPTIONS = [
    { name: 'package', displayName: 'package(s)' },
    { name: 'bag', displayName: 'bag(s)' },
    { name: 'box', displayName: 'box(es)' },
    { name: 'case', displayName: 'case(s)' },
    { name: 'carton', displayName: 'carton(s)' },
    { name: 'bundle', displayName: 'bundle(s)' },
    { name: 'roll', displayName: 'roll(s)' },
    { name: 'bottle', displayName: 'bottle(s)' },
    { name: 'can', displayName: 'can(s)' },
    { name: 'jar', displayName: 'jar(s)' },
    { name: 'container', displayName: 'container(s)' },
    { name: 'pack', displayName: 'pack(s)' },
    { name: 'unit', displayName: 'unit(s)' },
    { name: 'item', displayName: 'item(s)' },
] as const

export type CountUnit = typeof COUNT_UNIT_OPTIONS[number]['name']

/**
 * Format count and units for unified display
 * e.g., "1 package of 16oz" or "2 bags of 5lb"
 * 
 * @param count - Number of items (e.g., 1, 2)
 * @param countUnit - Container type (e.g., "package", "bag")
 * @param unitMeasurement - Size per container (e.g., "16oz", "5lb")
 * @returns Formatted string like "1 package of 16oz" or null if no valid data
 */
export const formatCountAndUnits = (
    count: string | number | null | undefined,
    countUnit: string | null | undefined,
    unitMeasurement: string | null | undefined
): string | null => {
    const countNum = typeof count === 'string' ? parseFloat(count) : count

    if (!countNum && countNum !== 0) {
        // No count, just return unit measurement if available
        return unitMeasurement || null
    }

    // Build the display string
    let result = String(countNum)

    if (countUnit) {
        // Pluralize simple count units
        const plural = countNum !== 1
        const displayUnit = plural && !countUnit.endsWith('s') ? `${countUnit}s` : countUnit
        result += ` ${displayUnit}`
    }

    if (unitMeasurement) {
        result += ` of ${unitMeasurement}`
    }

    return result
}

