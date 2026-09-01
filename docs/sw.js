// 첫 방문 뒤에는 인터넷 없이도 열리도록 앱 파일을 캐시한다.
// 파일을 고칠 때마다 CACHE 이름의 숫자를 올리면 새 버전이 반영된다.
const CACHE = 'gametimer-v4';
const ASSETS = [
  './',
  'index.html',
  'app.css',
  'app.js',
  'core.js',
  'store.js',
  'auth.js',
  'manifest.webmanifest',
  'icons/icon-180.png',
  'icons/icon-192.png',
  'icons/icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  // 네트워크를 먼저 보고, 안 되면 캐시로. 새로고침하면 최신 버전을 받는다.
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const copy = response.clone();
        caches.open(CACHE).then((cache) => cache.put(event.request, copy)).catch(() => {});
        return response;
      })
      .catch(() => caches.match(event.request).then((hit) => hit ?? caches.match('index.html'))),
  );
});
