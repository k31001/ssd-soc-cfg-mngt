# 9. 리스크와 마이그레이션 전략

본 장은 본 제안의 약점과 그에 대한 완화책, 그리고 기존 환경에서 신환경
으로의 점진적 이행 경로를 정리한다.

---

## 9.1 리스크 7가지와 완화책

| # | 리스크 | 영향 | 완화책 |
|---|---|---|---|
| R0 | **현재 산출물 포맷 마이그레이션** — HLD/DLD가 Word, SFR이 Excel | 본 제안 채택 전 변환 필요 | **Phase 0 (M0)**: Pandoc으로 Word→Markdown, Excel→SystemRDL 자동 변환 스크립트. 사람이 만지는 페이지를 표 제목·헤딩 보정 정도로 제한. 9.3 §에서 상세 |
| R1 | FW/Test Repo의 `git submodule` 학습 곡선 | FW/DV 엔지니어가 익숙하지 않음 | 양쪽 저장소의 `make doc-update` · `make doc-pin <tag>` 한 줄 wrapper. 일반 사용자는 submodule 명령 직접 입력 안 함 |
| R2 | 대용량 binary / waveform / FPGA bitstream | git에 두기 무거움 | git LFS 또는 별도 artifact bucket (S3). RTL/문서/HAL/Python은 git, bitstream/wave는 별도 |
| R3 | Doc submodule 핀이 detached HEAD로 떠도는 위험 | FW/Test가 임의 commit을 가리킬 가능성 | FW Repo F2, Test Repo T3 invariant — submodule SHA가 Doc Repo의 release tag와 일치하는지 강제 |
| R4 | **FW와 Test의 doc 정렬 어긋남** | "FW는 doc v2.5, Test는 doc v2.4로 검증" 같은 미세 분기로 결과 해석 불가 | Release gate R1 — `FW.doc-SHA == Test.doc-SHA` 자동 강제 (§4.2.4) |
| R5 | AI 자동 생성 환각 (HAL.c, Python scenario) | 잘못된 HAL/시나리오 | Doc / FW / Test 각 CI invariant가 PR 시점에 차단. AI 출력 신뢰는 CI가 검증 |
| R6 | SystemRDL/IP-XACT 작성 부담 | XML 직접 편집은 비친화적 | **SystemRDL `.rdl`을 author format으로**, peakrdl이 XML/HAL.h/Markdown 일괄 emit (§2.2 (3)). AI 자동 생성 (시나리오 A, §5) 병행 |
| R7 | FPGA / Veloce / Zebu 가용성 병목 | Python scenario 실행이 큐에 적체 | nightly 회귀 + 변경 영향분석 기반 우선순위. Host smoke + Test Repo pytest collect는 PR 게이트에 두고, 실측 coverif는 비동기 |
| R8 | Cross-repo coordination latency | RTL 변경이 검증까지 가는 데 Doc·FW·Test 3개 PR이 끼임 | Critical path SLA: RTL → Doc (D당), Doc → {FW,Test} (D+1) 정의. 비-critical은 nightly batch |
| R9 | 조직 변화 저항 | "지금까지 Word/Excel로 잘 해왔다" | Phase 0 자동 변환으로 진입장벽 최소화. 신규 IP부터 우선 적용. 기존 자산은 일정 기간 read-only 병행 |

---

## 9.2 마이그레이션 전략 — Risk-tiered 3-Lane

기존 환경의 인공물을 한 번에 옮기지 않고, 다음 3 lane으로 점진적
이행한다. (Phase 0의 포맷 변환은 9.3에서 별도 다룸 — 모든 lane의 prerequisite)

### Lane A — 신규 IP/SoC (Day 1부터 본 제안)
- 모든 신규 IP는 본 워크플로우의 4-repo 산출물 구조를 따른다.
- Reference IP (`irq_ctrl`, `trng`) 템플릿에서 시작.
- Doc D1–D5 + FW F1–F3 + Test T1–T4 + Release R1 invariant를 PR Required Status Check로 강제.
- **이 lane은 비용이 가장 낮고 효과가 가장 빠르다**.

### Lane B — 활발히 수정되는 in-house IP (점진적)
- IP 단위로 우선순위를 정해 마이그레이션.
- 우선순위는 ① RTL 수정 빈도 ② SoC 파생 사용 빈도 ③ FW 팀 의존도.
- 1 IP당 평균 1–2주 (Word→MD + Excel→SystemRDL 변환 + 가이드 작성 + invariant 통과).

### Lane C — 안정화된 legacy IP (read-only 유지)
- 더 이상 수정되지 않는 legacy IP는 Confluence/SharePoint에 그대로
  read-only 보관.
- Doc Repo에는 "legacy 참조 링크"만 둠.
- 새 SoC가 이 IP를 사용하려면 lane B로 승급 (그 시점에만 변환 비용).

## 9.3 Phase 0 — 현재 포맷 마이그레이션 (Word/Excel → MD/SystemRDL)

본 제안 채택의 **prerequisite**이며, 자동 변환을 우선한다.

### 9.3.1 HLD/DLD: Word(`.docx`) → Markdown
- **자동 변환**: `pandoc -f docx -t gfm <file>.docx > <file>.md`
- **수동 보정**: 표 헤더, 헤딩 번호, 이미지 경로, Mermaid로 다시 그려야 할 다이어그램 (Visio/PowerPoint 다이어그램은 별도 작업)
- **소요**: 1 IP당 0.5–1일 (200페이지 미만의 일반적 IP 기준)
- **검수**: Doc Repo D1 (RTL ↔ DLD §5) invariant가 register map 정합성을 한 번에 잡아냄

### 9.3.2 SFR: Excel → SystemRDL (`.rdl`) 또는 IP-XACT XML
- **권장 경로**: Excel → **SystemRDL `.rdl`** (사람·AI 양쪽이 읽기 쉬움) → peakrdl이 IP-XACT XML / HAL.h / Markdown 표 일괄 emit
- **자동 변환**: 사내 Excel template이 정형화되어 있으면 Python 1회성 스크립트로 RDL 생성 가능. 컬럼 매핑 (offset / width / access / reset / desc)이 표준이면 1 IP당 분 단위
- **변환기 도구**:
  - `openpyxl` + 자체 emitter (가장 흔한 경로)
  - `peakrdl-python` (RDL → Python 모델)
  - 상용: SystemRDL-import 기능 제공 EDA 도구
- **소요**: 사내 Excel 포맷 표준화에 1–2주, 그 후 IP당 분 단위 변환
- **검수**: Doc Repo D2 (DLD §5 ↔ SFR), D3 (SFR ↔ HAL.h) invariant가 변환 정합성을 자동 검증

### 9.3.3 변환 후의 양방향 호환 (점진적 전환 기간)
- 변환 초기에는 사람이 Excel을 여전히 편집할 수 있다 — 단, Excel→RDL 자동 변환 step이 PR 단위로 돌고, 변환 결과 RDL이 SoT가 된다.
- 일정 기간 후 (예: 6개월) Excel 편집을 deprecate하고 RDL을 직접 편집.

---

## 9.3 12개월 마이그레이션 로드맵 (요약)

```mermaid
gantt
    dateFormat YYYY-MM
    title  마이그레이션 (12개월)
    section Lane A (신규)
    신규 IP 본 제안 적용         :a1, 2026-06, 12M
    section Lane B (활성 in-house)
    Top-5 IP 변환               :b1, 2026-06, 3M
    Next-10 IP 변환             :b2, 2026-09, 4M
    잔여 활성 IP 변환            :b3, 2026-12, 4M
    section Lane C (legacy)
    인벤토리 + read-only 표시   :c1, 2026-06, 2M
    section Infrastructure
    CI invariant 풀세트         :i1, 2026-06, 1M
    AI 생성 도구 사내 배포       :i2, 2026-07, 3M
    PoC 측정 KPI 대시보드       :i3, 2026-08, 2M
```

세부 마일스톤은 §10에서 다룬다.

---

## 9.4 조직 변화 관리 — 익숙함과 어떻게 화해하는가

| 우려 (현장 목소리) | 대응 |
|---|---|
| "Confluence 쓰던 게 더 편한데" | 마크다운 PR 리뷰 1주 체험 → diff·comment의 강력함 체감 |
| "Git submodule은 우리 팀에 너무 어렵다" | `make ip-clone <ip>` 한 줄로 추상. 일반 사용자는 submodule 명령 직접 입력 안 함 |
| "AI가 만든 산출물을 어떻게 믿나" | 사람이 믿을 필요 없음. CI가 검증. 사람은 intent만 본다 |
| "EDA 벤더 AI(JedAI 등) 도입하면 되는 거 아닌가" | 가능. 단 락인 + 비용. 본 제안은 비vender solution을 병행 가능 (벤더 도구의 입력 산출물 자체가 본 워크플로우에서 나옴) |
| "Python scenario 작성이 가이드를 두 번 쓰는 거 아닌가" | Python scenario는 가이드의 **실측 가능한 펌웨어 구동 시퀀스 변환**. AI가 1-shot 생성하므로 중복 비용 0 |

---

## 9.5 실패 시나리오와 fallback

> **만약 채택 후 6개월 시점에 KPI가 기대 미달이면?**

가능한 원인과 대응:

| 원인 | 진단 | 대응 |
|---|---|---|
| Submodule 운영 부담이 예상보다 큼 | `make` 추상화 도달 못함 | Harness CLI 보강, 사내 onboarding 강의 1회 |
| AI 자동 생성 품질 저조 | 프롬프트·컨텍스트 패키지 미정형화 | 프롬프트 템플릿 표준화, IP-별 sample 축적 |
| Invariant false-positive 다수 | 검사 로직 강도 조정 필요 | 6종 중 가장 strict한 #2를 단계적 강화 |
| 조직 저항 | 가시적 성공 사례 부족 | Lane A의 신규 IP 1건을 사내 사례로 공개 발표 |

본 제안은 **부분 채택 가능**하다. Lane A만 적용해도 가치가 있고, lane B
는 IP 단위로 trade-off를 다시 판단할 수 있다. **all-or-nothing 결정이
아니다**.

---

## 9.6 데이터 거버넌스 / 보안

| 측면 | 본 제안 |
|---|---|
| IP 비밀유지 | 사내 git 안에서 끝남. 외부 API/벡터DB 미경유 |
| 권한 분리 | IP별 git repo 권한으로 자연스럽게 분리 |
| 감사 로그 | git commit 로그 = 변경 이력 = 감사 로그 |
| 외주 IP 흡수 | 외부 git → 사내 git mirror → submodule. 표준 절차 |
| LLM API 사용 시 데이터 노출 | 사용자 콘솔에서 IP 정보가 LLM provider에 평문으로 전송될 가능성은 별도 정책 (사내 LLM 또는 zero-retention 옵션 권장) |

---

## 9.7 다음 장 예고

§10에서 본 마이그레이션을 **3·6·12개월 마일스톤**으로 분해하고, §11에서
임원/리더가 다음으로 취해야 할 액션을 정리한다.
