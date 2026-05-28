# 3. 산출물 분류 — 5종 문서 + 3종 코드 + 1종 외부 reference

## 3.1 산출물 매트릭스

| # | 산출물 | 포맷 | 사는 저장소 | Diátaxis |
|---|---|---|---|---|
| 1 | **HLD** | Markdown + Mermaid | ② Design | Explanation |
| 2 | **DLD** | Markdown + Mermaid + WaveDrom | ② Design | Explanation + Reference |
| 3 | **Programmer's Guide** ⭐ | Markdown | ④ PG | Tutorials + How-to |
| 4 | **SFR (SystemRDL)** | `.rdl` + IP-XACT XML (peakrdl) | ③ RDL | Reference (machine) |
| 5 | **HAL.h + HAL.c** | C 헤더 (auto) + C source (Claude) | ⑤ HAL | Reference + 실행 |
| 6 | FW driver/app | C source | ⑦ FW | 실행 (FPGA·Veloce·Zebu) |
| 7 | Python coverif | Python (pytest) | ⑧ Test | 검증 (SSD Host) |
| 8 | 표준 spec | PDF (LFS) + 자동 MD extract | ⑥ Spec | External reference |

⭐ = SW-HW 계약. 모든 invariant 의 정합성 중심점.

## 3.2 Diátaxis 매핑 — 5종은 자의적이지 않다

```
                Action ↑                Cognition ↑
   Learning →   [Tutorials]    |    [Explanation]
                ───────────────┼─────────────────────
   Working  →   [How-to]       |    [Reference]
```

| Diátaxis | SoC 산출물 |
|---|---|
| Tutorials | PG §1 "Getting started" |
| How-to | PG §6 worked examples |
| Reference | SFR (RDL), HAL.h |
| Explanation | HLD, DLD §1-4 |

DLD §5 register map 은 Reference 영역이지만 사람이 의도를 보강 → Explanation+Reference hybrid.

## 3.3 마크다운에서의 시각화 — 흔한 질문 답변

> "산출물을 전부 마크다운으로 옮긴다면 Visio · UML · 웨이브폼은?"

| 시각화 유형 | 도구 | 본 워크플로우 |
|---|---|---|
| 블록 · 플로우 · 시퀀스 · 클래스 · 상태 · ER · Gantt | **Mermaid** | 기본 (GitHub · 본 뷰어 네이티브) |
| 신호 타이밍 · bitfield (DLD §6) | **WaveDrom** | 산업 표준, JSON source diff 가능 |
| 고급 UML | PlantUML | Kroki.io 게이트웨이 또는 사전 렌더 SVG |
| 복잡 그래프 · DAG | D2 · Graphviz | Kroki 동일 패턴 |
| 자유 스케치 · 사진 | draw.io · excalidraw → SVG commit | 최후 수단 |
| 수식 · 차트 | KaTeX · Chart.js | inline embed |

[Kroki.io](https://kroki.io) 단일 게이트웨이로 20+종 통합 가능. 어떤 도구로도 못 그리는 케이스는 SVG export → git commit → `<img>` 한 줄로 흡수. **모든 경우의 출구가 있다**.

**라이브 증명**: 발표 슬라이드 11번이 Mermaid 클래스 다이어그램 + WaveDrom 타이밍을 같은 페이지에서 동시 렌더 — 본 뷰어 자체가 증거.

## 3.4 절제 — 5종을 넘기지 않는 이유

| 자주 제안되는 추가 산출물 | 우리 대응 |
|---|---|
| 별도 "SoC Architecture spec" | HLD 에 흡수 |
| 별도 "Verification Plan" | PG §6 worked example + §8 pitfall → Python scenario 로 분해 |
| 별도 "Driver API spec" | HAL.h Doxygen |
| Performance characterization | DLD §1 목표 + PG §7 실측 + Python scenario measurement |

"한 문서가 두 청중을 동시에 만족시키려 하면 둘 다 실패" — Diátaxis 원칙.

→ §4 가 이 5종의 정합성을 CI invariant 로 어떻게 강제하는지 다룬다.
