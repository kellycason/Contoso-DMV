import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    rollupOptions: {
      output: {
        // Fixed filenames so we can overwrite existing portal web files — DO NOT CHANGE
        entryFileNames: 'assets/index-CcBGzUdW.js',
        assetFileNames: 'assets/index-BksZUihr[extname]',
        inlineDynamicImports: true,
      },
    },
    chunkSizeWarningLimit: 1200,
  },
})
