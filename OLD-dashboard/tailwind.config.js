/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.elm'],
  theme: {
    extend: {
    },
  },
  plugins: [
      require('@tailwindcss/typography'),
      require('daisyui')
  ],
}

