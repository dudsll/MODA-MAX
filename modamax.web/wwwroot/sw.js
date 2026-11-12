// Service worker do ModaMax (PWA): deixa o sistema instalavel e guarda os arquivos visuais
// para abrir rapido. Os dados sempre vem do servidor; sem rede, mostra a pagina offline.
const VERSAO = 'modamax-v1';
const ARQUIVOS = [
  '/offline.html',
  '/css/site.css',
  '/js/site.js',
  '/img/icones.svg',
  '/img/icone.svg',
  '/lib/bootstrap/dist/css/bootstrap.min.css',
  '/lib/bootstrap/dist/js/bootstrap.bundle.min.js',
  '/lib/jquery/dist/jquery.min.js',
  '/lib/chartjs/chart.umd.min.js'
];

self.addEventListener('install', evento => {
  evento.waitUntil(caches.open(VERSAO).then(cache => cache.addAll(ARQUIVOS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', evento => {
  evento.waitUntil(caches.keys()
    .then(chaves => Promise.all(chaves.filter(c => c !== VERSAO).map(c => caches.delete(c))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', evento => {
  const pedido = evento.request;
  if (pedido.method !== 'GET' || new URL(pedido.url).origin !== location.origin) return;

  // Paginas: sempre do servidor (dados atualizados); sem rede, a pagina offline.
  if (pedido.mode === 'navigate') {
    evento.respondWith(fetch(pedido).catch(() => caches.match('/offline.html')));
    return;
  }

  // Arquivos estaticos: responde do cache e atualiza em segundo plano.
  const caminho = new URL(pedido.url).pathname;
  if (/^\/(css|js|img|lib)\//.test(caminho)) {
    evento.respondWith(caches.open(VERSAO).then(async cache => {
      const salvo = await cache.match(pedido, { ignoreSearch: true });
      const rede = fetch(pedido).then(resposta => {
        if (resposta.ok) cache.put(pedido, resposta.clone());
        return resposta;
      }).catch(() => salvo);
      return salvo || rede;
    }));
  }
});
