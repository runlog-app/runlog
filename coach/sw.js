// RunLog's service worker (one copy for RunLog, one in coach/ for RunLog Coach).
// Network first: with internet the newest version loads every time, so updates arrive by
// themselves; without internet the last copy opens. It caches only this app's own files, and
// never sees the runner's data (that stays in the browser's storage, not in requests).
const CACHE = 'runlog-app-v1';
const SCOPE = self.registration.scope;
const SHELL = SCOPE; // the app page itself
// RunLog's worker leaves RunLog Coach (coach/) to the Coach's own worker.
const OTHER = SCOPE.endsWith('/coach/') ? null : SCOPE + 'coach/';

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll([SHELL, SCOPE + 'manifest.webmanifest'])).catch(() => {}));
});
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

const key = (url) => { const u = new URL(url); u.search = ''; u.hash = ''; if (u.pathname.endsWith('/index.html')) u.pathname = u.pathname.slice(0, -10); return u.href; };

self.addEventListener('fetch', (e) => {
  const r = e.request;
  if (r.method !== 'GET' || !r.url.startsWith(SCOPE) || (OTHER && r.url.startsWith(OTHER))) return;
  const k = r.mode === 'navigate' ? SHELL : key(r.url);
  e.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const net = fetch(r.mode === 'navigate' ? SHELL : r.url, { cache: 'no-cache', credentials: 'same-origin' }).then((res) => {
      if (res.ok) cache.put(k, res.clone());
      return res;
    });
    // On a slow line, the copy we have opens after 4 seconds; the new one is saved for next time.
    const slow = new Promise((resolve) => setTimeout(resolve, 4000)).then(() => cache.match(k));
    try {
      const first = await Promise.race([net, slow]);
      if (first) return first;
      return await net;
    } catch {
      return (await cache.match(k)) || new Response('RunLog needs internet the first time it opens.', { status: 503, headers: { 'Content-Type': 'text/plain' } });
    }
  })());
});
