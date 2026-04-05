import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import { defineConfig, loadEnv } from 'vite';

// ─────────────────────────────────────────────────────────────────────────────
// Vite config — optimised for Flutter WebView static export
// ─────────────────────────────────────────────────────────────────────────────
//
// Key changes from original:
//
// 1. base: './'
//    All asset paths are relative → works when loaded via loadFlutterAsset()
//    from a file:// origin. Firebase SDK, Tailwind, everything still loads.
//
// 2. build.outDir: 'dist'
//    Standard Vite output. After building, copy dist/ → flutter/assets/www/
//
// 3. build.assetsInlineLimit: 0
//    Don't inline assets as base64 data URIs. Flutter's asset server handles
//    files directly; inlining just bloats index.html.
//
// 4. HashRouter (already used in App.tsx) is the correct router for offline
//    WebView. Fragment-based routes (#/login, #/app) never hit a server, so
//    the static index.html handles every navigation.
//
// ─────────────────────────────────────────────────────────────────────────────

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, '.', '');

  return {
    // Relative base is mandatory for Flutter asset loading.
    base: './',

    plugins: [react(), tailwindcss()],

    define: {
      // Expose build-time env vars to the React bundle.
      // At runtime, Firebase reads its own config from firebase.ts — no
      // server-side env injection needed.
      'process.env.GEMINI_API_KEY': JSON.stringify(env.GEMINI_API_KEY),
    },

    build: {
      // Output directory — copy this to flutter/assets/www after building.
      outDir: 'dist',
      emptyOutDir: true,

      // Don't inline small assets; Flutter serves them from its asset system.
      assetsInlineLimit: 0,

      rollupOptions: {
        output: {
          // Deterministic chunk names help Flutter's asset bundler.
          chunkFileNames: 'assets/js/[name]-[hash].js',
          entryFileNames: 'assets/js/[name]-[hash].js',
          assetFileNames: 'assets/[ext]/[name]-[hash].[ext]',
        },
      },
    },

    resolve: {
      alias: {
        '@': path.resolve(__dirname, '.'),
      },
    },

    server: {
      hmr: process.env.DISABLE_HMR !== 'true',
    },
  };
});
