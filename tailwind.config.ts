/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./**/*.{js,ts,jsx,tsx}"  // scans all your JS files for Tailwind classes
    ],
    theme: {
        extend: {},
    },
    plugins: [],
}
