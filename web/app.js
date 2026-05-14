// SPDX-License-Identifier: Apache-2.0
// web/app.js — IP closed-loop workflow live status loader.
//
// data/status.json 은 tools/ipflow.py status --json 이 생성한다.
// CI 가 push 마다 갱신하므로 본 스크립트는 fetch 후 표만 렌더하면 충분.

(async function () {
  const target = document.getElementById('status-table');
  if (!target) return;

  let data;
  try {
    const res = await fetch('data/status.json', { cache: 'no-cache' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    data = await res.json();
  } catch (err) {
    target.innerHTML =
      '<div style="padding:18px;color:#cf222e">' +
      'data/status.json 을 불러오지 못했습니다. ' +
      '로컬에서 보고 있다면 <code>tools/ipflow.py status --json &gt; web/data/status.json</code> 을 실행해 주세요.' +
      '</div>';
    console.error(err);
    return;
  }

  const stages = data.stages;
  const ips = data.ips;
  const repoUrl = 'https://github.com/k31001/ssd-soc-cfg-mngt/tree/main/';

  // 짧은 컬럼 헤더 라벨
  const STAGE_LABEL = {
    spec: 'Spec',
    rtl: 'RTL',
    design: 'Design',
    ipxact: 'IP-XACT',
    guide: 'Guide',
    hal: 'HAL',
    scenarios: 'Scen.',
    sim: 'Sim',
  };

  // subsystem grouping
  ips.sort((a, b) =>
    a.subsystem === b.subsystem
      ? a.name.localeCompare(b.name)
      : a.subsystem.localeCompare(b.subsystem)
  );

  const tbl = document.createElement('table');
  tbl.className = 'matrix';

  // header
  const thead = document.createElement('thead');
  const headRow = document.createElement('tr');
  ['IP', 'Subsystem', 'Version', ...stages.map((s) => STAGE_LABEL[s] || s), 'Progress'].forEach(
    (h) => {
      const th = document.createElement('th');
      th.textContent = h;
      headRow.appendChild(th);
    }
  );
  thead.appendChild(headRow);
  tbl.appendChild(thead);

  // body
  const tbody = document.createElement('tbody');
  for (const ip of ips) {
    const tr = document.createElement('tr');

    const nameTd = document.createElement('td');
    nameTd.className = 'ip-name';
    const link = document.createElement('a');
    link.href = repoUrl + ip.path;
    link.target = '_blank';
    link.rel = 'noopener';
    link.textContent = ip.name;
    nameTd.appendChild(link);
    tr.appendChild(nameTd);

    const ssTd = document.createElement('td');
    ssTd.textContent = ip.subsystem;
    tr.appendChild(ssTd);

    const verTd = document.createElement('td');
    verTd.textContent = ip.version || '—';
    tr.appendChild(verTd);

    for (const s of stages) {
      const td = document.createElement('td');
      const on = !!ip.stages[s];
      td.className = 'cell ' + (on ? 'on' : 'off');
      td.textContent = on ? '✓' : '·';
      td.title = STAGE_LABEL[s] + ': ' + (on ? 'complete' : 'pending');
      tr.appendChild(td);
    }

    // progress
    const pctTd = document.createElement('td');
    pctTd.className = 'pct';
    const pct = ip.percent || 0;
    let toneClass = 'low';
    if (pct >= 80) toneClass = '';      // full green
    else if (pct >= 40) toneClass = 'mid';
    pctTd.innerHTML =
      pct + '%' +
      '<span class="bar"><span class="' + toneClass + '" style="width:' + pct + '%"></span></span>';
    tr.appendChild(pctTd);

    tbody.appendChild(tr);
  }
  tbl.appendChild(tbody);

  // legend
  const legend = document.createElement('div');
  legend.className = 'legend';
  legend.innerHTML =
    '<span><span class="chip ok"></span>complete</span>' +
    '<span><span class="chip no"></span>pending</span>' +
    '<span>총 ' + ips.length + ' IP — ' +
    ips.filter((i) => i.percent === 100).length + ' 완료, ' +
    ips.filter((i) => i.percent > 0 && i.percent < 100).length + ' 진행중, ' +
    ips.filter((i) => i.percent === 12 || i.percent === 0).length + ' spec only</span>';

  target.innerHTML = '';
  target.appendChild(tbl);
  target.appendChild(legend);
})();
