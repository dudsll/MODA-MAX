// Comportamentos gerais da interface ModaMax: tema claro/escuro, menu no celular,
// busca global estilo Spotlight (Cmd/Ctrl + K) e instalacao como aplicativo (PWA).
(function () {
    'use strict';

    const raiz = document.documentElement;

    // ---------- tema claro/escuro ----------------------------------------------------------
    function aplicarTema(tema) {
        raiz.setAttribute('data-theme', tema);
        raiz.setAttribute('data-bs-theme', tema);
        try { localStorage.setItem('modamax-tema', tema); } catch (e) { /* navegacao privada */ }
        document.dispatchEvent(new CustomEvent('modamax:tema', { detail: tema }));
    }

    document.querySelectorAll('[data-alternar-tema]').forEach(botao =>
        botao.addEventListener('click', () => aplicarTema(raiz.getAttribute('data-theme') === 'dark' ? 'light' : 'dark')));

    // ---------- menu lateral no celular -----------------------------------------------------
    const abrirMenu = () => document.body.classList.add('sidebar-aberta');
    const fecharMenu = () => document.body.classList.remove('sidebar-aberta');
    document.querySelectorAll('[data-abrir-menu]').forEach(b => b.addEventListener('click', abrirMenu));
    document.querySelectorAll('[data-fechar-menu]').forEach(b => b.addEventListener('click', fecharMenu));

    // ---------- busca global (Spotlight) ---------------------------------------------------
    const spotlight = document.getElementById('spotlight');
    if (spotlight) {
        const campo = document.getElementById('spotlight-campo');
        const lista = document.getElementById('spotlight-resultados');
        let itens = [];
        let selecionado = 0;
        let temporizador = null;
        let ultimaBusca = 0;

        // Atalhos para as telas, mostrados antes de digitar.
        const telas = Array.from(document.querySelectorAll('.sidebar nav a')).map(a => ({
            titulo: a.textContent.trim(),
            subtitulo: 'Ir para a tela',
            url: a.getAttribute('href'),
            icone: (a.querySelector('use') || { getAttribute: () => '' }).getAttribute('href').split('#')[1] || 'i-arrow-up-right'
        }));

        const escapar = texto => String(texto ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

        function desenhar(grupos) {
            itens = [];
            const html = [];
            grupos.forEach(grupo => {
                if (!grupo.itens.length) return;
                html.push(`<li class="spotlight-grupo" role="presentation">${escapar(grupo.titulo)}</li>`);
                grupo.itens.forEach(item => {
                    const indice = itens.push(item) - 1;
                    const figura = item.foto
                        ? `<img src="${escapar(item.foto)}" alt="" />`
                        : `<svg class="icone" aria-hidden="true"><use href="/img/icones.svg#${escapar(item.icone || 'i-arrow-up-right')}" /></svg>`;
                    html.push(`<li class="spotlight-item" role="option" id="spot-${indice}" data-indice="${indice}">
                        <a href="${escapar(item.url)}" tabindex="-1"><span class="spotlight-icone">${figura}</span>
                        <span>${escapar(item.titulo)}<small>${escapar(item.subtitulo)}</small></span></a></li>`);
                });
            });
            lista.innerHTML = html.length ? html.join('') : '<li class="vazio">Nada encontrado. Tente o nome, o código de barras ou o número do pedido.</li>';
            selecionado = 0;
            marcar();
        }

        function marcar() {
            lista.querySelectorAll('.spotlight-item').forEach(li => {
                const ativo = Number(li.dataset.indice) === selecionado;
                li.classList.toggle('selecionado', ativo);
                li.setAttribute('aria-selected', ativo);
                if (ativo) {
                    li.scrollIntoView({ block: 'nearest' });
                    campo.setAttribute('aria-activedescendant', li.id);
                }
            });
        }

        async function buscar(termo) {
            const numero = ++ultimaBusca;
            if (termo.trim().length < 2) {
                const filtro = termo.trim().toLowerCase();
                desenhar([{ titulo: 'Telas', itens: telas.filter(t => t.titulo.toLowerCase().includes(filtro)) }]);
                return;
            }
            try {
                const resposta = await fetch(`/Busca?q=${encodeURIComponent(termo)}`, { headers: { Accept: 'application/json' } });
                if (!resposta.ok || numero !== ultimaBusca) return;
                const dados = await resposta.json();
                const filtro = termo.trim().toLowerCase();
                desenhar([...dados.grupos, { titulo: 'Telas', itens: telas.filter(t => t.titulo.toLowerCase().includes(filtro)) }]);
            } catch (e) {
                lista.innerHTML = '<li class="vazio">Não foi possível buscar agora.</li>';
            }
        }

        function abrir() {
            spotlight.hidden = false;
            campo.value = '';
            buscar('');
            setTimeout(() => campo.focus(), 10);
        }

        function fechar() {
            spotlight.hidden = true;
        }

        document.querySelectorAll('[data-abrir-busca]').forEach(b => b.addEventListener('click', () => { fecharMenu(); abrir(); }));
        spotlight.addEventListener('click', e => { if (e.target === spotlight) fechar(); });

        campo.addEventListener('input', () => {
            clearTimeout(temporizador);
            temporizador = setTimeout(() => buscar(campo.value), 160);
        });

        campo.addEventListener('keydown', e => {
            if (e.key === 'ArrowDown') { e.preventDefault(); selecionado = Math.min(selecionado + 1, itens.length - 1); marcar(); }
            else if (e.key === 'ArrowUp') { e.preventDefault(); selecionado = Math.max(selecionado - 1, 0); marcar(); }
            else if (e.key === 'Enter' && itens[selecionado]) { e.preventDefault(); window.location.href = itens[selecionado].url; }
        });

        lista.addEventListener('mousemove', e => {
            const li = e.target.closest('.spotlight-item');
            if (li && Number(li.dataset.indice) !== selecionado) { selecionado = Number(li.dataset.indice); marcar(); }
        });

        document.addEventListener('keydown', e => {
            if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
                e.preventDefault();
                spotlight.hidden ? abrir() : fechar();
            } else if (e.key === 'Escape' && !spotlight.hidden) {
                fechar();
            }
        });
    }

    // ---------- copiar texto (ex.: PIX copia e cola) ---------------------------------------
    document.querySelectorAll('[data-copiar]').forEach(botao => botao.addEventListener('click', async () => {
        const alvo = document.querySelector(botao.dataset.copiar);
        if (!alvo) return;
        try {
            await navigator.clipboard.writeText(alvo.value || alvo.textContent);
        } catch (e) {
            alvo.select && alvo.select();
            document.execCommand('copy');
        }
        const original = botao.innerHTML;
        botao.textContent = 'Copiado';
        setTimeout(() => { botao.innerHTML = original; }, 1600);
    }));

    // ---------- avisos flutuantes somem sozinhos ------------------------------------------
    document.querySelectorAll('.aviso-flutuante').forEach(aviso => setTimeout(() => aviso.remove(), 5000));

    // ---------- PWA: permite instalar o sistema como aplicativo -----------------------------
    if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) {
        window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(() => { }));
    }

    // Cores dos graficos acompanham o tema.
    window.ModaMax = {
        cores() {
            const estilo = getComputedStyle(raiz);
            const cor = nome => estilo.getPropertyValue(nome).trim();
            return {
                texto: cor('--texto-2'),
                grade: cor('--separador'),
                azul: cor('--azul'),
                paleta: ['#0a84ff', '#5e5ce6', '#30d158', '#ff9f0a', '#ff375f', '#64d2ff', '#bf5af2']
            };
        }
    };
})();
