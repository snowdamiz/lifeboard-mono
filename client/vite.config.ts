import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:4000',
        changeOrigin: true
      },
      // Proxy /auth/refresh specifically as it's an API call, not a page load
      '/auth/refresh': {
        target: 'http://localhost:4000',
        changeOrigin: true
      }
      // Note: Other /auth routes are NOT proxied because OAuth uses full-page redirects
      // The frontend callback at /auth/callback is handled by Vue Router
    }
  }
})

