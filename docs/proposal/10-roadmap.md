# 10. 로드맵 — 3·6·12개월 마일스톤

본 장은 본 제안의 채택을 **시간 축에 분해**한다. 각 마일스톤은 (a) 산출물,
(b) 조직 책임자, (c) 통과 기준(exit criteria)을 가진다.

---

## 10.1 한눈에 보는 12개월

```mermaid
gantt
    dateFormat YYYY-MM
    axisFormat %Y-%m
    title  AI 친화 SoC 산출물 관리 — 12개월 로드맵

    section M0 — 포맷 마이그레이션 (prereq)
    킥오프 + 본 보고서 승인          :crit, m0a, 2026-06, 1M
    Word→Markdown 변환 파이프라인    :m0b, 2026-06, 1M
    Excel→SystemRDL 변환 스크립트    :crit, m0c, 2026-06, 2M
    Reference IP 2종 변환 완료       :m0d, 2026-07, 1M

    section M1 — 4-repo 인프라 + Lane A
    RTL/Doc/FW/Test 4-repo 셋업      :m1a, 2026-07, 1M
    Doc CI (D1–D5) PR-required       :m1b, 2026-08, 1M
    FW CI (F1–F3) + Test CI (T1–T4)  :m1c, 2026-08, 1M
    Release gate R1 자동화           :m1d, 2026-09, 1M
    신규 IP Lane A 적용 시작         :m1e, 2026-08, 11M

    section M2 — AI 자동 생성 도구
    Guide → HAL.c (FW Repo)          :m2a, 2026-08, 2M
    Guide → Python (Test Repo)       :m2b, 2026-09, 2M
    AI 프롬프트 표준화                :m2c, 2026-10, 1M

    section M3 — Lane B 마이그레이션
    Top-5 활성 IP 변환                :crit, m3a, 2026-09, 3M
    Next-10 IP 변환                   :m3b, 2026-12, 4M
    잔여 활성 IP 변환                 :m3c, 2027-03, 3M

    section M4 — 측정 & 거버넌스
    KPI 대시보드 (web 확장)          :m4a, 2026-09, 2M
    분기 1회 효과 회고                :milestone, m4b, 2026-10, 0d
    분기 1회 효과 회고                :milestone, m4c, 2027-01, 0d
    분기 1회 효과 회고                :milestone, m4d, 2027-04, 0d

    section M5 — 신규 SoC 파생
    파생 SoC 부트스트랩 PoC          :crit, m5a, 2026-11, 2M
    파생 SoC 첫 HW/SW coverif        :milestone, m5b, 2027-01, 0d
```

---

## 10.2 3개월 (M0 종료)

**목표**: 포맷 마이그레이션 완료. 신규 IP가 4-repo 인프라로 흐를 수 있는 토대.

| 산출물 | 책임자 | Exit criteria |
|---|---|---|
| 본 제안서 임원 승인 | 본 보고서 작성자 + 사업부 | 사업부장 승인 + 분기 OKR 등재 |
| **Word(`.docx`) → Markdown 변환 파이프라인** | 문서 owner | Pandoc + 수동 보정 표준 절차. 1 IP HLD/DLD 변환 0.5–1일 |
| **Excel(`.xlsx`) → SystemRDL(`.rdl`) 자동 변환기** | DevOps | 사내 Excel template → RDL 1:1 자동 (소요 1–2주 개발, 그 후 IP당 분 단위) |
| Reference IP 2종 변환 완료 (`irq_ctrl`, `trng`) | RTL팀 | Word→MD + Excel→RDL 후 Doc Repo D1–D5 PASS |
| 4-repo (RTL/Doc/FW/Test) 셋업 | DevOps | 4개 repo 생성 + 권한 분리 + submodule 한 방향 잠금 |
| Onboarding 가이드 1.0 | 본 보고서 작성자 | 새 엔지니어가 가이드만 보고 첫 PR 가능 |

---

## 10.3 6개월 (M1–M2 + M3 일부)

**목표**: 4-repo CI invariants 가동. AI 자동 생성 도구 정상 동작. 활성 IP의 30%가 Lane B 완료.

| 산출물 | 책임자 | Exit criteria |
|---|---|---|
| Doc CI (D1–D5) + FW CI (F1–F3) + Test CI (T1–T4) | DevOps | 4-repo 각각 GitHub Required Status Checks 활성 |
| Release gate R1 자동화 (`FW.doc-SHA == Test.doc-SHA`) | DevOps | nightly + release manifest 단계에서 자동 강제 |
| AI 자동 생성 도구 (4 시나리오) | DevOps + AI 도입 TF | 각 시나리오에서 CI invariant pass 확인된 PR 사례 ≥ 3건 |
| 프롬프트 / 컨텍스트 패키지 표준화 | AI 도입 TF | IP-별 README에 표준 프롬프트 등재 |
| Lane B Top-5 IP 변환 완료 | IP owners | 5개 IP 모두 D1–D5 + 상응 F/T invariant PASS |
| KPI 대시보드 (web/ 확장) | DevOps | 토큰 사용·invariant fail율·lead-time 가시화 |
| Confluence legacy 인벤토리 | 문서 owner | Lane C로 분류된 산출물 목록 |

---

## 10.4 12개월 (M3 종료 + M5 완료)

**목표**: 활성 IP 100% Lane B 완료. 신규 SoC 파생 PoC 성공.

| 산출물 | 책임자 | Exit criteria |
|---|---|---|
| 활성 IP 100% Lane B 완료 | 사업부 | 모든 활성 IP가 본 워크플로우 |
| 파생 SoC 부트스트랩 PoC | HW + AI TF | 신규 SoC 1건이 본 워크플로우로 first tape-out ready |
| FW 팀 핸드오프 표준 | FW lead | super-repo clone 만으로 펌웨어 개발 착수 가능 |
| ROI 보고서 (KPI 실측) | 본 보고서 작성자 | §8 정량 효과를 사내 실측 데이터로 갱신 |
| Lane C legacy 결정 | 사업부 | 유지 / 디지털 폐기 결정 명문화 |

---

## 10.5 단계별 의사결정 게이트

각 분기 종료 시점에 다음 4개 질문으로 go/no-go를 판단:

```
Q1. 정량 KPI가 산업 평균 범위 안에 있는가?
    (토큰 효율 -30% 이상, lead-time -30% 이상, drift 0)
Q2. 사용자(IP owner) 만족도가 임계 이상인가?
    (Net Promoter Score 또는 사내 설문)
Q3. CI invariant false-positive 비율이 허용 범위인가?
    (월 PR의 5% 이하)
Q4. 다음 분기에 흡수 가능한 IP 수 / 인력이 충분한가?
```

4개 중 3개 이상 yes → 진행. 아니면 다음 분기에서 원인 분석 + 보강.

---

## 10.6 인력 추정 (예시)

| 역할 | 헤드카운트 (FTE) | 기간 |
|---|---|---|
| 본 제안 PM | 0.5 | 12M |
| DevOps (CI / harness 보강) | 1.0 | 12M |
| AI 도입 TF (프롬프트 표준화) | 0.5 | 6M |
| Onboarding & docs | 0.3 | 12M |
| IP owner 측의 마이그레이션 부담 | 0.2 / IP | spike |

위 수치는 1차 추정. 실제 산정은 사업부 인력 풀과 IP 수에 의존.

---

## 10.7 외부 자원 / 도구

| 종류 | 후보 | 비고 |
|---|---|---|
| AI 어시스턴트 | Claude Code (Anthropic) / Cursor | grep-first 패턴이 본 제안과 가장 일치[^2] |
| Verilator | OSS | RTL TB sim, CI 통합 |
| IP-XACT 도구 | Kactus2 (OSS), Magillem (commercial) | 변환·검증 보조 |
| Mermaid / WaveDrom | OSS | 다이어그램 |
| MkDocs Material / Docusaurus | OSS | 마크다운 → 사내 wiki (필요시) |

---

## 10.8 다음 — Call to Action

§11에서 본 보고서가 임원/리더에게 요청하는 **3가지 결정**을 정리한다.

---

[^1]: 본 레포 [`docs/VERIFICATION_REPORT.md`](../VERIFICATION_REPORT.md).
[^2]: §7 참고.
