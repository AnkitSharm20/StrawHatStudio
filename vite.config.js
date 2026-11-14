import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (!id.includes('/node_modules/')) return undefined;
          if (id.includes('/node_modules/@supabase/')) return 'supabase-vendor';
          if (id.includes('/node_modules/lucide-react/')) return 'icons-vendor';
          if (
            id.includes('/node_modules/react/') ||
            id.includes('/node_modules/react-dom/') ||
            id.includes('/node_modules/react-router/') ||
            id.includes('/node_modules/react-router-dom/') ||
            id.includes('/node_modules/@remix-run/router/') ||
            id.includes('/node_modules/scheduler/')
          ) return 'react-vendor';
          return undefined;
        }
      }
    }
  }
});
