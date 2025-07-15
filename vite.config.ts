import { defineConfig } from 'vite'
import { watch } from 'vite-plugin-watch'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
    plugins: [
        tailwindcss(),
        watch({
            pattern: 'src/shaders/**/*.glsl',
            command: 'node glsl-parser.cjs'
        }),
    ],
})