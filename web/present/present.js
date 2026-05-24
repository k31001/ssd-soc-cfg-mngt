// SPDX-License-Identifier: Apache-2.0
// 발표 모드 — 키보드 네비, 진행도 바, 발표자 노트, 프래그먼트 (점진적 reveal)

(function () {
  // ─── Mermaid: 초기화는 동기적으로, run() 은 slide 가 활성화된 뒤에만.
  if (window.mermaid) {
    window.mermaid.initialize({
      startOnLoad: false,
      theme: 'dark',
      themeVariables: {
        background: '#0d1117',
        primaryColor: '#161b22',
        primaryTextColor: '#e6edf3',
        primaryBorderColor: '#30363d',
        lineColor: '#58a6ff',
        secondaryColor: '#21262d',
        tertiaryColor: '#1f2428',
        fontFamily: 'system-ui',
        fontSize: '15px',
      },
    });
  }

  const slides = Array.from(document.querySelectorAll('.slide'));
  const progress = document.getElementById('progress');
  const counter = document.getElementById('counter');
  let idx = 0;
  let fragmentStep = 0;

  function clamp(i) {
    return Math.max(0, Math.min(slides.length - 1, i));
  }

  function currentFragments() {
    return Array.from(slides[idx].querySelectorAll('.fragment'));
  }

  function applyFragments() {
    const frags = currentFragments();
    frags.forEach((el, i) => {
      el.classList.toggle('visible', i < fragmentStep);
    });
  }

  async function ensureMermaidRendered(slideIdx) {
    if (!window.mermaid) return;
    const slide = slides[slideIdx];
    if (!slide) return;
    const blocks = slide.querySelectorAll('.mermaid:not([data-processed="true"])');
    if (blocks.length === 0) return;
    try {
      await window.mermaid.run({ nodes: Array.from(blocks) });
    } catch (e) {
      console.error('mermaid render failed for slide', slideIdx + 1, e);
    }
  }

  // WaveDrom — slide 11 (시각화 종합) 의 timing diagram.
  // 첫 활성화 시점에 processAll() 한 번 호출.
  // 주의: WaveDrom 3.x 는 global 이 소문자 (`window.wavedrom`) 이고 메서드도
  //       camelCase (`processAll`) 이다. 2.x 의 `WaveDrom.ProcessAll()` 과 다름.
  let waveDromProcessed = false;
  function ensureWaveDromRendered(slideIdx) {
    if (!window.wavedrom || waveDromProcessed) return;
    const slide = slides[slideIdx];
    if (!slide) return;
    const hasWaveDrom = slide.querySelector('script[type="WaveDrom"]');
    if (!hasWaveDrom) return;
    try {
      window.wavedrom.processAll();
      waveDromProcessed = true;
    } catch (e) {
      console.error('WaveDrom render failed', e);
    }
  }

  function show(i, opts = {}) {
    idx = clamp(i);
    slides.forEach((s, j) => s.classList.toggle('active', j === idx));
    fragmentStep = opts.atEnd ? currentFragments().length : 0;
    applyFragments();
    if (progress) {
      progress.style.width = ((idx + 1) / slides.length) * 100 + '%';
    }
    if (counter) {
      counter.textContent = (idx + 1) + ' / ' + slides.length;
    }
    if (window.location.hash !== '#' + (idx + 1)) {
      history.replaceState(null, '', '#' + (idx + 1));
    }
    // Lazy render mermaid · WaveDrom only after the slide is laid out (display:flex 적용 후)
    requestAnimationFrame(() => {
      ensureMermaidRendered(idx);
      ensureWaveDromRendered(idx);
    });
  }

  // Expose for the print handler
  window.__deck = { ensureMermaidRendered, ensureWaveDromRendered, slides };

  function next() {
    const frags = currentFragments();
    if (fragmentStep < frags.length) {
      fragmentStep++;
      applyFragments();
      return;
    }
    show(idx + 1);
  }

  function prev() {
    if (fragmentStep > 0) {
      fragmentStep--;
      applyFragments();
      return;
    }
    show(idx - 1, { atEnd: true });
  }

  document.addEventListener('keydown', (e) => {
    if (e.target && /^(input|textarea|select)$/i.test(e.target.tagName)) return;
    switch (e.key) {
      case 'ArrowRight':
      case 'PageDown':
      case ' ':
        e.preventDefault();
        next();
        break;
      case 'ArrowLeft':
      case 'PageUp':
        e.preventDefault();
        prev();
        break;
      case 'Home':
        e.preventDefault();
        show(0);
        break;
      case 'End':
        e.preventDefault();
        show(slides.length - 1);
        break;
      case 'n':
      case 'N':
        document.body.classList.toggle('show-notes');
        break;
      case 'f':
      case 'F':
        if (!document.fullscreenElement) {
          document.documentElement.requestFullscreen?.();
        } else {
          document.exitFullscreen?.();
        }
        break;
      case 'p':
      case 'P':
        e.preventDefault();
        prepareAndPrint();
        break;
      case 'g':
      case 'G': {
        const dest = prompt('Slide # (1–' + slides.length + ')');
        const n = parseInt(dest, 10);
        if (!isNaN(n)) show(n - 1);
        break;
      }
    }
  });

  // Click left/right halves to navigate (mobile / tablet)
  document.getElementById('deck').addEventListener('click', (e) => {
    // Don't navigate when clicking interactive content
    const tag = (e.target.tagName || '').toLowerCase();
    if (['a', 'button', 'input', 'select', 'textarea'].includes(tag)) return;
    if (e.target.closest('.mermaid, .chart-wrap, pre, code')) return;
    const x = e.clientX / window.innerWidth;
    if (x > 0.55) next();
    else if (x < 0.45) prev();
  });

  // Hash navigation
  function fromHash() {
    const m = window.location.hash.match(/^#(\d+)$/);
    if (m) {
      const n = parseInt(m[1], 10);
      if (!isNaN(n)) show(n - 1);
    } else {
      show(0);
    }
  }
  window.addEventListener('hashchange', fromHash);

  // Print mode: show all slides + render any pending mermaid 후 print 호출.
  // (브라우저의 Cmd-P / Ctrl-P 도 같은 경로로 통합)
  async function prepareAndPrint() {
    slides.forEach((s) => s.classList.add('active'));
    if (window.mermaid) {
      const all = document.querySelectorAll('.mermaid:not([data-processed="true"])');
      if (all.length > 0) {
        try { await window.mermaid.run({ nodes: Array.from(all) }); }
        catch (e) { console.error('mermaid render (print) failed', e); }
      }
    }
    // WaveDrom 도 인쇄 전 모두 처리 (3.x: lowercase global, camelCase method)
    if (window.wavedrom && !waveDromProcessed) {
      try { window.wavedrom.processAll(); waveDromProcessed = true; }
      catch (e) { console.error('WaveDrom render (print) failed', e); }
    }
    // 레이아웃 정리 후 인쇄
    setTimeout(() => window.print(), 80);
  }

  window.addEventListener('afterprint', () => {
    slides.forEach((s, j) => s.classList.toggle('active', j === idx));
  });

  // ?notes=1 query → 발표자 노트 자동 표시
  if (new URLSearchParams(window.location.search).get('notes') === '1') {
    document.body.classList.add('show-notes');
  }

  fromHash();
})();

// (Mermaid initialize 는 IIFE 진입 시점에 이미 실행됨 — 위 참고.
//  Lazy render 는 slide show() 가 호출될 때마다 자동 발생.)

// Chart.js init for the impact slide
window.addEventListener('load', () => {
  if (!window.Chart) return;

  const fg = '#e6edf3';
  const grid = 'rgba(139, 148, 158, 0.18)';
  const muted = '#8b949e';

  Chart.defaults.color = fg;
  Chart.defaults.font.family = "system-ui, -apple-system, 'Apple SD Gothic Neo', 'Noto Sans KR', sans-serif";
  Chart.defaults.font.size = 13;
  Chart.defaults.borderColor = grid;

  const tokenCtx = document.getElementById('chart-tokens');
  if (tokenCtx) {
    new Chart(tokenCtx, {
      type: 'bar',
      data: {
        labels: ['컨텍스트 회수', 'LLM 추론 입력', '출력', '합계'],
        datasets: [
          {
            label: 'RAG/MCP 방식',
            data: [5000, 7000, 1000, 13000],
            backgroundColor: 'rgba(248, 81, 73, 0.78)',
            borderColor: '#f85149',
            borderWidth: 1,
          },
          {
            label: '본 제안 (직접 read)',
            data: [1500, 2500, 1000, 5000],
            backgroundColor: 'rgba(63, 185, 80, 0.78)',
            borderColor: '#3fb950',
            borderWidth: 1,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: { beginAtZero: true, grid: { color: grid }, ticks: { color: muted } },
          x: { grid: { display: false }, ticks: { color: muted } },
        },
        plugins: {
          legend: { position: 'top', labels: { color: fg } },
          title: {
            display: true,
            text: 'PR 1건 평균 LLM 토큰 사용 (nvme_ctrl admin queue enable 예시)',
            color: fg,
            font: { size: 15, weight: '600' },
          },
        },
      },
    });
  }

  const roiCtx = document.getElementById('chart-roi');
  if (roiCtx) {
    new Chart(roiCtx, {
      type: 'bar',
      data: {
        labels: [
          'LLM API 비용', '검색 인프라', '신규 IP 부트스트랩',
          '신규 SoC 파생', '문서 drift 결함', 'EDA 락인'
        ],
        datasets: [{
          label: '12개월 누적 효과 (절감 %)',
          data: [50, 100, 70, 60, 90, 100],
          backgroundColor: [
            'rgba(88, 166, 255, 0.78)',
            'rgba(63, 185, 80, 0.78)',
            'rgba(210, 168, 255, 0.78)',
            'rgba(255, 138, 101, 0.78)',
            'rgba(255, 213, 79, 0.78)',
            'rgba(124, 242, 211, 0.78)',
          ],
          borderWidth: 0,
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
        scales: {
          x: { beginAtZero: true, max: 100, grid: { color: grid }, ticks: { color: muted, callback: (v) => v + '%' } },
          y: { grid: { display: false }, ticks: { color: fg } },
        },
        plugins: {
          legend: { display: false },
          title: {
            display: true,
            text: '12개월 시점 ROI 요약 (산업 평균 기준 추정)',
            color: fg,
            font: { size: 15, weight: '600' },
          },
        },
      },
    });
  }
});
