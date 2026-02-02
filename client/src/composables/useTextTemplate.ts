import { api } from '@/services/api'

export function useTextTemplate(type: string) {
    const search = async (query: string): Promise<string[]> => {
        try {
            // Allow empty query to show all suggestions on focus
            const response = await api.suggestTemplates(type, query.trim())
            return response.data
        } catch (e) {
            console.error(`Failed to search templates for ${type}`, e)
            return []
        }
    }

    const save = async (value: string) => {
        try {
            if (!value.trim()) return
            // Fire and forget
            api.saveTemplate(type, value).catch((e: unknown) => {
                console.error(`Failed to save template for ${type}`, e)
            })
        } catch (e: unknown) {
            console.error(`Failed to initiate save template for ${type}`, e)
        }
    }

    const deleteTemplate = async (value: string): Promise<boolean> => {
        try {
            if (!value.trim()) return false
            await api.deleteTextTemplate(type, value)
            return true
        } catch (e: unknown) {
            console.error(`Failed to delete template for ${type}`, e)
            return false
        }
    }

    return {
        search,
        save,
        deleteTemplate
    }
}
