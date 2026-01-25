import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Store, Trip, Stop, Brand, Unit, Purchase, BrandSuggestion, Driver } from '@/types'
import { api } from '@/services/api'

export const useReceiptsStore = defineStore('receipts', () => {
    // State
    const stores = ref<Store[]>([])
    const trips = ref<Trip[]>([])
    const currentTrip = ref<Trip | null>(null)
    const brands = ref<Brand[]>([])
    const units = ref<Unit[]>([])
    const purchases = ref<Purchase[]>([])
    const loading = ref(false)

    const drivers = ref<Driver[]>([])

    // Stores
    async function fetchStores() {
        loading.value = true
        try {
            const response = await api.listStores()
            stores.value = response.data
        } finally {
            loading.value = false
        }
    }

    async function createStore(store: Partial<Store>) {
        const response = await api.createStore(store)
        stores.value.push(response.data)
        return response.data
    }

    async function updateStore(id: string, updates: Partial<Store>) {
        const response = await api.updateStore(id, updates)
        const index = stores.value.findIndex(s => s.id === id)
        if (index !== -1) {
            stores.value[index] = response.data
        }
        return response.data
    }

    async function deleteStore(id: string) {
        await api.deleteStore(id)
        stores.value = stores.value.filter(s => s.id !== id)
    }

    async function fetchStoreInventory(id: string) {
        const response = await api.getStoreInventory(id)
        return response.data
    }

    async function updateStoreInventoryItem(storeId: string, itemId: string, payload: { source: string; propagate: boolean;[key: string]: any }) {
        const response = await api.updateStoreInventoryItem(storeId, itemId, payload)
        return response.data
    }

    // Drivers
    async function fetchDrivers() {
        loading.value = true
        try {
            const response = await api.listDrivers()
            drivers.value = response.data
        } finally {
            loading.value = false
        }
    }

    async function createDriver(name: string) {
        const response = await api.createDriver({ name })
        drivers.value.push(response.data)
        return response.data
    }

    // Trips
    async function fetchTrips(params?: { start_date?: string; end_date?: string }) {
        loading.value = true
        try {
            const response = await api.listTrips(params)
            trips.value = response.data
        } finally {
            loading.value = false
        }
    }

    async function fetchTrip(id: string) {
        loading.value = true
        try {
            const response = await api.getTrip(id)
            currentTrip.value = response.data
            return response.data
        } finally {
            loading.value = false
        }
    }

    async function createTrip(trip: Partial<Trip>) {
        const response = await api.createTrip(trip)
        trips.value.unshift(response.data)
        return response.data
    }

    async function updateTrip(id: string, updates: Partial<Trip>) {
        const response = await api.updateTrip(id, updates)
        const index = trips.value.findIndex(t => t.id === id)
        if (index !== -1) {
            trips.value[index] = response.data
        }
        if (currentTrip.value?.id === id) {
            currentTrip.value = response.data
        }
        return response.data
    }

    async function deleteTrip(id: string) {
        await api.deleteTrip(id)
        trips.value = trips.value.filter(t => t.id !== id)
        if (currentTrip.value?.id === id) {
            currentTrip.value = null
        }
    }

    // Stops
    async function createStop(tripId: string, stop: Partial<Stop>) {
        const response = await api.createStop(tripId, stop)

        // Update current trip if loaded
        if (currentTrip.value?.id === tripId) {
            currentTrip.value.stops.push(response.data)
        }

        // Update trip in list
        const tripIndex = trips.value.findIndex(t => t.id === tripId)
        if (tripIndex !== -1) {
            trips.value[tripIndex].stops.push(response.data)
        }

        return response.data
    }

    async function updateStop(id: string, updates: Partial<Stop>) {
        const response = await api.updateStop(id, updates)

        // Update in current trip
        if (currentTrip.value) {
            const stopIndex = currentTrip.value.stops.findIndex(s => s.id === id)
            if (stopIndex !== -1) {
                currentTrip.value.stops[stopIndex] = response.data
            }
        }

        // Update in trips list
        for (const trip of trips.value) {
            const stopIndex = trip.stops.findIndex(s => s.id === id)
            if (stopIndex !== -1) {
                trip.stops[stopIndex] = response.data
                break
            }
        }

        return response.data
    }

    async function deleteStop(id: string) {
        await api.deleteStop(id)

        // Remove from current trip
        if (currentTrip.value) {
            currentTrip.value.stops = currentTrip.value.stops.filter(s => s.id !== id)
        }

        // Remove from trips list
        for (const trip of trips.value) {
            trip.stops = trip.stops.filter(s => s.id !== id)
        }
    }

    // Brands
    async function fetchBrands(search?: string) {
        loading.value = true
        try {
            const response = await api.listBrands(search ? { search } : undefined)
            brands.value = response.data
        } finally {
            loading.value = false
        }
    }

    async function searchBrands(query: string) {
        if (!query || query.length < 1) return []
        try {
            const response = await api.searchBrands(query)
            return response.data
        } catch (error) {
            // Silently return empty array on error - autocomplete is non-critical
            return []
        }
    }

    async function createBrand(brand: Partial<Brand>) {
        const response = await api.createBrand(brand)
        brands.value.push(response.data)
        return response.data
    }

    async function updateBrand(id: string, updates: Partial<Brand>) {
        const response = await api.updateBrand(id, updates)
        const index = brands.value.findIndex(b => b.id === id)
        if (index !== -1) {
            brands.value[index] = response.data
        }
        return response.data
    }

    // Units
    async function fetchUnits() {
        loading.value = true
        try {
            const response = await api.listUnits()
            units.value = response.data
        } finally {
            loading.value = false
        }
    }

    async function createUnit(name: string) {
        const response = await api.createUnit({ name })
        units.value.push(response.data)
        return response.data
    }

    // Purchases
    async function fetchPurchases(params?: { stop_id?: string; brand?: string; source_id?: string }) {
        loading.value = true
        try {
            const response = await api.listPurchases(params)
            purchases.value = response.data
        } finally {
            loading.value = false
        }
    }

    async function createPurchase(purchase: Partial<Purchase> & { date?: string }) {
        const response = await api.createPurchase(purchase)
        purchases.value.unshift(response.data)

        // Update stop if it exists in current trip
        if (purchase.stop_id && currentTrip.value) {
            const stop = currentTrip.value.stops.find(s => s.id === purchase.stop_id)
            if (stop && stop.purchases) {
                stop.purchases.push(response.data)
            }
        }

        // Check if brand is new and refresh brands list if so
        if (purchase.brand && !brands.value.some(b => b.name.toLowerCase() === purchase.brand?.toLowerCase())) {
            fetchBrands()
        }

        return response.data
    }

    async function updatePurchase(id: string, updates: Partial<Purchase>) {
        const response = await api.updatePurchase(id, updates)
        const index = purchases.value.findIndex(p => p.id === id)
        if (index !== -1) {
            purchases.value[index] = response.data
        }

        // Update in current trip stops
        if (currentTrip.value) {
            for (const stop of currentTrip.value.stops) {
                if (stop.purchases) {
                    const purchaseIndex = stop.purchases.findIndex(p => p.id === id)
                    if (purchaseIndex !== -1) {
                        stop.purchases[purchaseIndex] = response.data
                        break
                    }
                }
            }
        }

        // Check if brand is new and refresh brands list if so
        if (updates.brand && !brands.value.some(b => b.name.toLowerCase() === updates.brand?.toLowerCase())) {
            fetchBrands()
        }

        return response.data
    }

    async function deletePurchase(id: string) {
        await api.deletePurchase(id)
        purchases.value = purchases.value.filter(p => p.id !== id)

        // Remove from current trip stops
        if (currentTrip.value) {
            for (const stop of currentTrip.value.stops) {
                if (stop.purchases) {
                    stop.purchases = stop.purchases.filter(p => p.id !== id)
                }
            }
        }
    }

    // Auto-complete & Suggestions
    async function getSuggestionsByBrand(brand: string, storeId?: string): Promise<BrandSuggestion> {
        const response = await api.suggestByBrand(brand, storeId)
        return response.data
    }

    async function getSuggestionsByItem(item: string): Promise<BrandSuggestion[]> {
        const response = await api.suggestByItem(item)
        return response.data
    }

    async function searchStores(query: string): Promise<Store[]> {
        const response = await api.suggestStores(query)
        return response.data
    }

    async function searchStoreCodes(query: string): Promise<string[]> {
        const response = await api.suggestStoreCodes(query)
        return response.data
    }

    async function searchReceiptItemNames(query: string): Promise<string[]> {
        const response = await api.suggestReceiptItems(query)
        return response.data
    }

    async function searchItemNames(query: string): Promise<string[]> {
        const response = await api.suggestItems(query)
        return response.data
    }

    // Inventory Integration
    async function addToInventory(purchaseIds: string[], assignments: Record<string, string>) {
        await api.addPurchasesToInventory({
            purchase_ids: purchaseIds,
            sheet_assignments: assignments
        })
    }

    return {
        // State
        stores,
        drivers,
        trips,
        currentTrip,
        brands,
        purchases,
        loading,

        // Stores
        fetchStores,
        createStore,
        updateStore,
        deleteStore,
        fetchStoreInventory,
        updateStoreInventoryItem,

        // Drivers
        fetchDrivers,
        createDriver,

        // Trips
        fetchTrips,
        fetchTrip,
        createTrip,
        updateTrip,
        deleteTrip,

        // Stops
        createStop,
        updateStop,
        deleteStop,

        // Brands
        fetchBrands,
        searchBrands,
        createBrand,
        updateBrand,

        // Purchases
        fetchPurchases,
        createPurchase,
        updatePurchase,
        deletePurchase,

        // Auto-complete
        getSuggestionsByBrand,
        getSuggestionsByItem,
        searchStores,
        searchStoreCodes,
        searchReceiptItemNames,
        searchItemNames,

        // Inventory
        addToInventory,

        // Units
        units,
        fetchUnits,
        createUnit
    }
})
