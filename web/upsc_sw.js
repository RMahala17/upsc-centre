/* Offline support for UPSC Command Centre.
 *
 * Strategy: network first, cache as a fallback.
 *  - Online: every file comes fresh from the server (so a new deploy shows up
 *    straight away) and a copy is kept.
 *  - Offline, or the network takes more than 4 seconds: the kept copy is used.
 * All study data lives in the browser's database, not here, so nothing in this
 * file can lose it. Only same-origin GET requests are handled. Build with
 * `--no-web-resources-cdn` so the engine files are same-origin and get cached.
 */
const CACHE = 'upsc-runtime-v1';
const SLOW_MS = 4000;

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

function fetchWithTimeout(request, ms) {
  if (!ms) return fetch(request);
  return Promise.race([
    fetch(request),
    new Promise((_, reject) => setTimeout(() => reject(new Error('slow')), ms)),
  ]);
}

async function networkFirst(request) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(request);
  try {
    const response = await fetchWithTimeout(request, cached ? SLOW_MS : 0);
    if (response && response.status === 200 && response.type === 'basic') {
      cache.put(request, response.clone());
    }
    return response;
  } catch (err) {
    if (cached) return cached;
    if (request.mode === 'navigate') {
      const shell =
        (await cache.match(self.registration.scope)) ||
        (await cache.match(new URL('index.html', self.registration.scope)));
      if (shell) return shell;
    }
    throw err;
  }
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  if (request.headers.has('range')) return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  event.respondWith(networkFirst(request));
});
