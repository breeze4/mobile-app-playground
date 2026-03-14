import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5199,
    proxy: {
      '/api': `http://localhost:${process.env.PORT || 3051}`,
    },
  },
})
