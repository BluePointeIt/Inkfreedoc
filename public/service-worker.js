self.addEventListener('install', () => {
  console.log('InkFreeDoc App installed')
})

self.addEventListener('activate', () => {
  console.log('InkFreeDoc App activated')
})

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request))
})
