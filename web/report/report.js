// SPDX-License-Identifier: Apache-2.0
// 보고서 뷰어 — content/<chapter>.md 를 fetch + marked 로 렌더.
//
// CI(.github/workflows/deploy-pages.yml) 또는 `make report-sync` 가
// docs/proposal/*.md → web/report/content/*.md 로 복사한다.

const CHAPTERS = [
  'README',
  '00-executive-summary',
  '01-problem',
  '02-proposal',
  '03-artifact-taxonomy',
  '04-rtl-doc-consistency',
  '05-ai-automation',
  '06-workflow-e2e',
  '07-llmwiki-benchmark',
  '08-quantitative-impact',
  '09-risks-migration',
  '10-roadmap',
  '11-conclusion',
];

const TITLES = {
  'README': '표지 / 목차',
  '00-executive-summary': '00 — Executive Summary',
  '01-problem': '01 — 문제 정의',
  '02-proposal': '02 — 제안 (3-repo 아키텍처)',
  '03-artifact-taxonomy': '03 — 산출물 5종 분류',
  '04-rtl-doc-consistency': '04 — 정합성 CI (D/F invariants)',
  '05-ai-automation': '05 — AI 자동화',
  '06-workflow-e2e': '06 — End-to-End 워크플로우',
  '07-llmwiki-benchmark': '07 — LLM Wiki / DeepWiki 비교',
  '08-quantitative-impact': '08 — 정량 효과',
  '09-risks-migration': '09 — 리스크 · 마이그레이션',
  '10-roadmap': '10 — 로드맵',
  '11-conclusion': '11 — 결론',
};

const PRESETS = {
  exec: ['00-executive-summary', '02-proposal', '08-quantitative-impact', '11-conclusion'],
  rtl:  ['01-problem', '02-proposal', '04-rtl-doc-consistency', '06-workflow-e2e'],
  sw:   ['03-artifact-taxonomy', '05-ai-automation', '06-workflow-e2e'],
};

let currentChapter = null;
let presetQueue = null;

marked.use({ gfm: true, breaks: false });

// marked v12: code 렌더러 시그너처 변화에 휘둘리지 않도록
// 렌더 결과 HTML 에서 mermaid pre-block 을 div.mermaid 로 후처리.
function mermaidPostProcess(html) {
  return html.replace(
    /<pre><code class="language-mermaid">([\s\S]*?)<\/code><\/pre>/g,
    (_, encoded) => {
      const decoded = encoded
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&amp;/g, '&');
      return `<div class="mermaid">${decoded}</div>`;
    }
  );
}

function rewriteMarkdownLinks(md) {
  // Markdown 안의 상대 링크 ([..]/proposal/xx.md, ../docs/...) 를 viewer 해시 라우팅으로 변환
  return md
    // [text](./xx-name.md ...) or [text](xx-name.md ...)
    .replace(/\]\(\.?\/?((?:\d{2}-[a-z0-9-]+|README))\.md(#[^)]*)?\)/g,
             (_, name, anchor) => `](#${name}${anchor || ''})`)
    // [text](../WORKFLOW.md) → soc-cfg-mngt repo의 원본으로 (viewer 외부) — 그대로 두되 raw view
    .replace(/\]\(\.\.\/(?!\.\.\/)([A-Za-z0-9._-]+\.md)\)/g,
             (_, name) => `](../../docs/${name})`)
    // [text](../../cm-strategies/README.md) → 외부 경로 그대로
    .replace(/\]\(\.\.\/\.\.\/([^)]+)\)/g, (_, p) => `](../../${p})`)
    // [text](../../tools/ipflow.py) etc.
    ;
}

function setActive(ch) {
  document.querySelectorAll('.toc-item').forEach(el => {
    const isActive = el.dataset.ch === ch;
    el.classList.toggle('active', isActive);
    if (isActive) {
      el.scrollIntoView({ block: 'nearest' });
    }
  });
  const crumb = document.getElementById('crumb');
  if (crumb) crumb.textContent = (TITLES[ch] || ch);
  document.title = (TITLES[ch] || ch) + ' — AI 친화 SoC 산출물 관리';
}

async function loadChapter(ch, opts = {}) {
  if (!CHAPTERS.includes(ch)) {
    ch = '00-executive-summary';
  }
  currentChapter = ch;
  setActive(ch);

  const content = document.getElementById('content');
  content.innerHTML = '<div class="loading">불러오는 중…</div>';

  try {
    const resp = await fetch(`content/${ch}.md`, { cache: 'no-store' });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    let md = await resp.text();
    md = rewriteMarkdownLinks(md);
    let html = marked.parse(md);
    html = mermaidPostProcess(html);
    content.innerHTML = html;

    // Re-run mermaid
    if (window.mermaid) {
      window.mermaid.run({ querySelector: '#content .mermaid', suppressErrors: false });
    }

    // Update URL hash without scrolling
    if (!opts.skipHash) {
      const newHash = '#' + ch;
      if (location.hash !== newHash) {
        history.replaceState(null, '', newHash);
      }
    }

    // Smooth scroll to top of content
    window.scrollTo({ top: 0, behavior: opts.instant ? 'instant' : 'smooth' });

    // Close sidebar on mobile
    document.body.classList.remove('sidebar-open');

  } catch (err) {
    content.innerHTML = `
      <div class="error">
        <strong>챕터를 불러올 수 없습니다.</strong><br/>
        <code>content/${ch}.md</code> — ${err.message}<br/><br/>
        <p style="color:#5b6470; font-size:14px">
          개발 중이라면 다음을 먼저 실행하세요:<br/>
          <code>make report-sync</code> &nbsp;또는&nbsp;
          <code>bash web/report/sync.sh</code><br/>
          그 후 <code>python3 -m http.server -d web 8000</code> 로 서비스.
        </p>
      </div>
    `;
  }
}

function indexOfChapter(ch) {
  return CHAPTERS.indexOf(ch);
}

function jumpRelative(delta) {
  const i = indexOfChapter(currentChapter);
  const j = Math.max(0, Math.min(CHAPTERS.length - 1, i + delta));
  loadChapter(CHAPTERS[j]);
}

function loadFromHash() {
  let h = window.location.hash.replace(/^#/, '');
  if (!h) h = '00-executive-summary';
  loadChapter(h, { skipHash: true, instant: true });
}

// ─────────────────── wiring ───────────────────
document.addEventListener('click', (e) => {
  const item = e.target.closest('.toc-item');
  if (!item) return;
  if (item.dataset.ch) {
    e.preventDefault();
    loadChapter(item.dataset.ch);
    return;
  }
  if (item.dataset.preset) {
    e.preventDefault();
    const list = PRESETS[item.dataset.preset];
    if (!list) return;
    presetQueue = list.slice();
    const first = presetQueue.shift();
    loadChapter(first);
  }
});

document.addEventListener('keydown', (e) => {
  if (e.target && /^(input|textarea|select)$/i.test(e.target.tagName)) return;
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  switch (e.key) {
    case 'j': case 'J':
    case 'ArrowDown':
      if (e.key.toLowerCase() === 'j') { e.preventDefault(); jumpRelative(+1); }
      break;
    case 'k': case 'K':
    case 'ArrowUp':
      if (e.key.toLowerCase() === 'k') { e.preventDefault(); jumpRelative(-1); }
      break;
    case 'p': case 'P':
      e.preventDefault();
      window.print();
      break;
    case '/':
      e.preventDefault();
      document.body.classList.toggle('sidebar-open');
      break;
  }
});

window.addEventListener('hashchange', loadFromHash);

const menuToggle = document.getElementById('menu-toggle');
if (menuToggle) menuToggle.addEventListener('click', () => {
  document.body.classList.toggle('sidebar-open');
});

const printBtn = document.getElementById('print-btn');
if (printBtn) printBtn.addEventListener('click', () => window.print());

// Mermaid init
if (window.mermaid) {
  window.mermaid.initialize({
    startOnLoad: false,
    theme: 'default',
    themeVariables: {
      background: '#ffffff',
      primaryColor: '#f6f8fa',
      primaryBorderColor: '#d0d7de',
      primaryTextColor: '#1f2328',
      lineColor: '#0969da',
      fontFamily: 'system-ui',
    },
  });
}

loadFromHash();
