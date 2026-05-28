# 9. 리스크와 마이그레이션 전략

본 장은 본 제안의 약점과 그에 대한 완화책, 그리고 기존 환경에서 신환경
으로의 점진적 이행 경로를 정리한다.

---

## 9.1 리스크 7가지와 완화책

| # | 리스크 | 영향 | 완화책 |
|---|---|---|---|
| R0 | **현재 산출물 포맷 마이그레이션** — HLD/DLD가 Word, SFR이 Excel, 표준 spec PDF | 본 제안 채택 전 변환 필요 | **Phase 0 (M0)**: Pandoc 으로 Word→Markdown, Excel→SystemRDL 자동 변환, PDF→Markdown extract (`pdftotext` + 사내 후처리). 사람이 만지는 페이지를 표 제목·헤딩 보정 정도로 제한. 9.3 §에서 상세 |
| R10 | **3개 문서 저장소 (Design/RDL/PG) 의 수동 편집 정합성** | 자유 편집 시 drift 가능 | **Hybrid: authored zone (자유) + shadow zone (자동 sync, 수동 차단)**. shadow zone 은 마크다운 주석 `<!-- @shadow:gen -->` 으로 명시, CI 가 수동 편집 PR 차단. §4.2.0 참고 |
| R11 | **표준 spec PDF (NVMe/PCIe/ONFI) 참조 방식** | 모두 첨부 / MCP / submodule 3개 옵션 trade-off | **Spec Repo + submodule (LFS PDF + auto MD extract)**. MCP·전체 첨부 모두 배제. §5.5 참고 |
| R12 | **Claude Code 가 자체 검증 단계를 건너뛸 위험** | self-check 안 하면 CI 가 fail 하는 PR 다수 | CI invariant 가 신뢰의 마지막 관문 — self-check 는 latency·노이즈 절감 도구. Skip 해도 결과는 같음. |
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

## 9.2 마이그레이션 스코프 — 전 IP 동시, 부분 채택 없음

본 제안은 lane 분할이나 단계적 흡수를 하지 않는다. **모든 IP가 한 번에
신 워크플로우로 전환**되며, 컷오버 시점 이후 예전 포맷은 read-only로만
존재한다. 그 이유:

- **양립 운영의 비용**. Lane을 나누면 "이 IP는 Confluence + 저것은 Markdown",
  "이 IP는 SV TB + 저것은 Python coverif" 같은 이중 운영이 6–12개월간
  계속된다. AI 컨텍스트 일관성·CI invariant·release 매니페스트가 모두 부분
  지원을 처리해야 해 복잡도가 폭증한다.
- **결정의 지연 비용**. "다음 IP는 언제 옮길지" 결정이 매 분기 반복되며,
  IP owner의 자원 배분이 흔들린다. 일제 전환은 이 결정을 한 번에 끝낸다.
- **AI 컨텍스트의 결정론**. submodule 모델은 모든 IP가 같은 패턴을 따를 때
  가장 강하다. 일부만 적용하면 LLM이 "이 IP는 어디 봐야 하나" 추론을
  계속해야 한다.

스코프 결정:

| 항목 | 정책 |
|---|---|
| **신규 IP** | 컷오버 후 신 워크플로우로만 작성 |
| **활성 in-house IP** | 12주 안에 **전부** 변환 (§10 참조) |
| **Legacy/freeze IP** | 변환은 하되, 컷오버 후 추가 수정 없음 (사실상 read-only) |
| **외주/IP vendor** | 흡수 시점에 변환 — 표준 절차로 흡수 (`docx2md` + `xlsx2rdl`) |

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

## 9.4 조직 변화 관리 — 익숙함과 어떻게 화해하는가

| 우려 (현장 목소리) | 대응 |
|---|---|
| "Confluence 쓰던 게 더 편한데" | 마크다운 PR 리뷰 1주 체험 → diff·comment의 강력함 체감 |
| "Git submodule은 우리 팀에 너무 어렵다" | `make ip-clone <ip>` 한 줄로 추상. 일반 사용자는 submodule 명령 직접 입력 안 함 |
| "AI가 만든 산출물을 어떻게 믿나" | 사람이 믿을 필요 없음. CI가 검증. 사람은 intent만 본다 |
| "EDA 벤더 AI(JedAI 등) 도입하면 되는 거 아닌가" | 가능. 단 락인 + 비용. 본 제안은 비vender solution을 병행 가능 (벤더 도구의 입력 산출물 자체가 본 워크플로우에서 나옴) |
| "Python scenario 작성이 가이드를 두 번 쓰는 거 아닌가" | Python scenario는 가이드의 **실측 가능한 펌웨어 구동 시퀀스 변환**. AI가 1-shot 생성하므로 중복 비용 0 |

---

## 9.5 12주 안 실패 시나리오와 대응

일제 전환이라 "부분 후퇴" 옵션이 없다. 대신 12주 안에 발생할 수 있는
3가지 실패 모드를 사전에 식별하고 mitigation을 준비한다.

| 시점 | 실패 모드 | 진단 | 대응 |
|---|---|---|---|
| Week 2 종료 | 변환 도구 신뢰성 부족 | `docx2md` 결과의 다이어그램 누락 多, `xlsx2rdl` 매핑 미적용 케이스 | DevOps 인력 +1 spike, 사내 Excel template 강제 표준화. Week 3까지 회복 |
| Week 6 종료 | Programmer's Guide 초안 작성이 지연 | AI 초안이 SW lead 리뷰 큐에서 정체 | 리뷰 기준을 "intent만 본다"로 명시. CI invariant가 사실 정합성을 잡으므로 사람 리뷰는 의도 확인에만 집중 |
| Week 9 종료 | invariant blocking 전환 시 false-positive 폭증 | Step 4–7 동안 warning 튜닝이 부족 | Week 9-10 동안 invariant 우선순위를 정해 strict한 것부터 blocking, 나머지는 warning 유지. 그래도 12주 컷오버 데드라인은 유지 |

> **데드라인은 협상 대상이 아니지만, 정합성 강도는 단계적으로 조절 가능**.
> 가장 strict한 invariant (D1 RTL ↔ DLD, R1 FW.doc-SHA == Test.doc-SHA)부터
> blocking, 나머지는 컷오버 후 1–2주 안에 강화한다.

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

§10에서 12주 step-by-step 전환 계획을 단계별로 분해하고, §11에서 3개월 후
도달하는 모습과 기회비용을 정리한다.
