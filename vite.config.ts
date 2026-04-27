import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { nodePolyfills } from 'vite-plugin-node-polyfills'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  plugins: [
    react(),
    nodePolyfills({
      include: ['buffer', 'process', 'util', 'events', 'stream'],
      globals: { Buffer: true, process: true, global: true },
    }),
  ],
  define: {
    global: 'globalThis',
  },
  resolve: {
    alias: [
      // Fix broken `main` in this transitive dep (no .js extension in package.json)
      {
        find: /^@microsoft\/botframework-webchat-adapter-azure-communication-chat$/,
        replacement: path.resolve(
          __dirname,
          'node_modules/@microsoft/botframework-webchat-adapter-azure-communication-chat/dist/chat-adapter.js'
        ),
      },
    ],
  },
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
