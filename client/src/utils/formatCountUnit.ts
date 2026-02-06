/**
 * Formats count and unit measurement into a standardized display string.
 * Format: "X count_unit of Y unit_measurement" (e.g., "1 box of 16 Batteries")
 * 
 * Falls back gracefully when data is missing:
 * - If only count/countUnit: "2 packs"
 * - If only units/unitMeasurement: "15 oz"
 * - If count but no countUnit: "2 of 15 oz"
 * - If all present: "2 boxes of 15 oz"
 */
export function formatCountUnit(
    count?: string | number | null,
    countUnit?: string | null,
    units?: string | number | null,
    unitMeasurement?: string | null
): string {
    // Parse and clean values
    const countVal = count !== null && count !== undefined && count !== ''
        ? parseFloat(String(count))
        : null
    const hasCount = countVal !== null && !isNaN(countVal)
    const countUnitVal = countUnit?.trim() || null
    const hasCountUnit = !!countUnitVal

    const unitsVal = units !== null && units !== undefined && units !== ''
        ? parseFloat(String(units))
        : null
    const hasUnits = unitsVal !== null && !isNaN(unitsVal)
    const unitMeasurementVal = unitMeasurement?.trim() || null
    const hasUnitMeasurement = !!unitMeasurementVal

    // Format count number (remove trailing zeros)
    const formatNumber = (num: number): string => {
        if (Number.isInteger(num)) return String(num)
        return num.toFixed(2).replace(/\.?0+$/, '')
    }

    // Build the display parts
    const parts: string[] = []

    // Count part (e.g., "2 boxes" or just "2")
    if (hasCount) {
        const countStr = formatNumber(countVal!)
        if (hasCountUnit) {
            // Pluralize simple units (add 's' if count > 1 and unit doesn't end in 's')
            let unit = countUnitVal!
            if (countVal !== 1 && !unit.toLowerCase().endsWith('s')) {
                unit = unit + 's'
            }
            parts.push(`${countStr} ${unit}`)
        } else {
            parts.push(countStr)
        }
    }

    // Units/measurement part (e.g., "16 oz" or just "oz")
    if (hasUnits || hasUnitMeasurement) {
        let unitPart = ''
        if (hasUnits && hasUnitMeasurement) {
            unitPart = `${formatNumber(unitsVal!)} ${unitMeasurementVal}`
        } else if (hasUnits) {
            unitPart = formatNumber(unitsVal!)
        } else if (hasUnitMeasurement) {
            unitPart = unitMeasurementVal!
        }

        if (unitPart) {
            if (parts.length > 0) {
                parts.push(`of ${unitPart}`)
            } else {
                parts.push(unitPart)
            }
        }
    }

    return parts.join(' ') || ''
}

/**
 * Formats a complete item cell display string.
 * Format: "Quantity QuantityUnit of Brand Item of Count CountMeasurement"
 * 
 * Examples:
 * - "2 boxes of Cheerios Cereal of 12 oz"
 * - "1 pack of Kirkland Batteries of 32 ct"
 * - "Generic Gas Can of 5.3 gal" (when quantity is 1 and no unit)
 */
export function formatItemCell(
    count?: string | number | null,
    countUnit?: string | null,
    brand?: string | null,
    item?: string | null,
    units?: string | number | null,
    unitMeasurement?: string | null
): string {
    // Parse and clean values  
    const countVal = count !== null && count !== undefined && count !== ''
        ? parseFloat(String(count))
        : null
    const hasCount = countVal !== null && !isNaN(countVal)
    const countUnitVal = countUnit?.trim() || null
    const hasCountUnit = !!countUnitVal

    const brandVal = brand?.trim() || null
    const hasBrand = !!brandVal
    const itemVal = item?.trim() || null
    const hasItem = !!itemVal

    const unitsVal = units !== null && units !== undefined && units !== ''
        ? parseFloat(String(units))
        : null
    const hasUnits = unitsVal !== null && !isNaN(unitsVal)
    const unitMeasurementVal = unitMeasurement?.trim() || null
    const hasUnitMeasurement = !!unitMeasurementVal

    // Format number (remove trailing zeros)
    const formatNumber = (num: number): string => {
        if (Number.isInteger(num)) return String(num)
        return num.toFixed(2).replace(/\.?0+$/, '')
    }

    // Pluralize simple units (add 's' if count > 1 and unit doesn't end in 's')
    const pluralize = (unit: string, num: number): string => {
        if (num !== 1 && !unit.toLowerCase().endsWith('s')) {
            return unit + 's'
        }
        return unit
    }

    const parts: string[] = []

    // Part 1: Quantity and Quantity Unit (e.g., "2 boxes" or just "1")
    // Always show quantity when we have a count value
    if (hasCount) {
        const countStr = formatNumber(countVal!)
        if (hasCountUnit) {
            parts.push(`${countStr} ${pluralize(countUnitVal!, countVal!)}`)
        } else {
            parts.push(countStr)
        }
    }

    // Part 2: Brand and Item name (e.g., "of Cheerios Cereal" or just "Cheerios Cereal")
    // Use "of" only when we have a quantity unit (e.g., "2 boxes of Brand Item")
    // Otherwise just append directly (e.g., "1 Brand Item")
    const brandItem = [brandVal, itemVal].filter(Boolean).join(' ')
    if (brandItem) {
        if (parts.length > 0 && hasCountUnit) {
            // Has quantity unit: "2 boxes of Brand Item"
            parts.push(`of ${brandItem}`)
        } else {
            // No quantity unit or no quantity: just "Brand Item" or "1 Brand Item"
            parts.push(brandItem)
        }
    }

    // Part 3: Count and Count Measurement (e.g., "of 12 oz")
    if (hasUnits || hasUnitMeasurement) {
        let unitPart = ''
        if (hasUnits && hasUnitMeasurement) {
            unitPart = `${formatNumber(unitsVal!)} ${unitMeasurementVal}`
        } else if (hasUnits) {
            unitPart = formatNumber(unitsVal!)
        } else if (hasUnitMeasurement) {
            unitPart = unitMeasurementVal!
        }

        if (unitPart) {
            if (parts.length > 0) {
                parts.push(`of ${unitPart}`)
            } else {
                parts.push(unitPart)
            }
        }
    }

    return parts.join(' ') || ''
}

