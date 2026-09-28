import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "byte_me",
  description: "A fast, isolate-driven download and HLS remuxing engine for Dart/Flutter.",
  base: '/byte_me/',
  cleanUrls: true,
  head: [
    ['link', { rel: 'preconnect', href: 'https://fonts.googleapis.com' }],
    ['link', { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' }],
    ['link', { href: 'https://fonts.googleapis.com/css2?family=Montserrat:ital,wght@0,100..900;1,100..900&display=swap', rel: 'stylesheet' }]
  ],
  themeConfig: {
    lastUpdated: {
      text: 'Last updated',
      formatOptions: {
        dateStyle: 'medium'
      }
    },
    editLink: {
      pattern: 'https://github.com/roshancodespace/ShonenX/edit/main/packages/byte_me/docs/:path',
      text: 'Edit this page'
    },
    footer: {
      message: 'Released under the <a href="https://github.com/roshancodespace/ShonenX/blob/main/LICENSE" target="_blank" rel="noopener">GNU General Public License v3.0</a>.',
      copyright: 'Copyright © 2026-present Roshan (<a href="https://github.com/roshancodespace" target="_blank" rel="noopener">@roshancodespace</a>)'
    },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/' },
      { text: 'API', link: '/api/' }
    ],

    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'What is byte_me?', link: '/' },
          { text: 'Getting Started', link: '/guide/' }
        ]
      },
      {
        text: 'Usage',
        items: [
          { text: 'Downloading Files', link: '/guide/downloading-files' },
          { text: 'Downloading HLS', link: '/guide/downloading-hls' },
          { text: 'MKV Remuxing', link: '/guide/mkv-remuxing' },
          { text: 'Adding Subtitles', link: '/guide/subtitles' }
        ]
      },
      {
        text: 'Architecture',
        items: [
          { text: 'Isolates & Performance', link: '/architecture/isolates' },
          { text: 'TS Demuxing', link: '/architecture/ts-demuxing' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/roshancodespace/shonenx' }
    ],

    search: {
      provider: 'local'
    }
  }
})
