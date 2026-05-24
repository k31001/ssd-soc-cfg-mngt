# 5. AI 자동화 — Programmer's Guide를 SW-HW 계약으로 두고 HAL을 1-shot 생성

본 장은 "AI가 SoC 산출물을 자동 생성한다"는 막연한 표어를 **구체적인
4가지 자동 생성 시나리오**로 분해한다. 그리고 각 시나리오에서 AI에게
어떤 컨텍스트를 어떻게 (RAG 아닌 직접 read로) 주는지 명시한다.

---

## 5.1 AI가 생성하는 4가지 산출물 — 저장소별 분담

| # | 실행 저장소 | 입력 (AI가 읽는 것) | 출력 (AI가 쓰는 것) | 검증 게이트 |
|---|---|---|---|---|
| A | **Doc Repo** | RTL Repo의 `*.sv` (fetch) + DLD §5 표 초안 | `doc/<ip>/<ip>.rdl` (SystemRDL) 또는 `.ipxact.xml` | D1 / D2 |
| B | **Doc Repo** | `<ip>.rdl` 또는 `.ipxact.xml` | `include/<ip>_hal.h` (auto-gen via peakrdl/ipxact2c) | D3 |
| C | **FW Repo** | `doc/include/<ip>_hal.h` (submodule) + `doc/<ip>/PROGRAMMERS_GUIDE.md` (submodule) | `fw/hal/<ip>_hal.c` 구현체 | F1 + host smoke |
| D | **Test Repo** | `doc/<ip>/PROGRAMMERS_GUIDE.md §6, §8` (submodule) | `tests/scenarios/<ip>/*.py` (SSD Host용 Python coverif) | T1 / T2 |

각 시나리오의 공통 특징:
- **AI는 git 안의 마크다운/RDL/XML/Verilog/Python을 직접 read** 한다 (RAG 없음).
- **출력은 해당 저장소의 PR**. CI invariant가 정합성을 강제하므로
  AI 환각은 머지 단계에서 차단된다.
- **시나리오 A, B는 Doc Repo**가 닫는다 → Doc Repo가 새 tag를 release.
- **시나리오 C는 FW Repo**가, **시나리오 D는 Test Repo**가 각자 자기 `doc/` submodule을 새 tag로 갱신한 직후 자동 실행.
- **사람의 역할은 의도 검토** — 즉 "기능이 맞는가"에 집중하고 "이름이
  맞는가"는 CI가 본다.

---

## 5.2 왜 submodule + 직접 read인가 — RAG와의 결정적 차이

### RAG/MCP 방식의 AI 컨텍스트 주입
```
[질의] "irq_ctrl HAL에 enable 함수 구현 ..."
   ↓
[Vector search] top-k 청크 회수 (수십 개)
   ↓
[LLM context] 무관·중복 청크 다수 + 진짜 필요한 SFR 정보 일부
   ↓
[출력] 환각 위험 (인접 IP의 enable 함수 시그너처와 혼동 가능)
```

### 본 제안의 AI 컨텍스트 주입 (FW Repo 시점)
```
[질의] "nvme_ctrl HAL에 admin queue enable 함수 구현 ..."
   ↓
[AI 도구 호출]  Read("doc/nvme_ctrl/PROGRAMMERS_GUIDE.md")   # submodule
               Read("doc/include/nvme_ctrl_hal.h")           # submodule
               Read("fw/hal/nvme_ctrl_hal.c")                # 현재 구현
   ↓
[LLM context] 정확히 3개 파일 — 모두 FW Repo working copy 안
   ↓
[출력] HAL .c 패치 → FW Repo CI가 F1 + host smoke 로 검증
```

### 본 제안의 AI 컨텍스트 주입 (Test Repo 시점)
```
[질의] "Guide §6.2 admin queue enable worked example 을 Python으로 변환 ..."
   ↓
[AI 도구 호출]  Read("doc/nvme_ctrl/PROGRAMMERS_GUIDE.md")   # submodule (§6, §8)
               Read("tests/lib/nvme_host.py")                # Host NVMe helper
   ↓
[LLM context] 2개 파일 — 모두 Test Repo working copy 안
   ↓
[출력] tests/scenarios/nvme_ctrl/sc_admin_queue_enable.py
       → Test Repo CI가 T1 + pytest --collect-only 로 검증
```

submodule pin이 같으면 동일 질의는 항상 같은 컨텍스트를 본다. **FW와
Test 두 저장소가 자기 doc submodule을 각자 들고 있어** 컨텍스트가
교차오염되지 않는다. RTL은 참고할 필요가 없다 — 인터페이스 계약은
doc submodule이 이미 갖고 있다.

차이는 단순한 효율이 아니다. **재현 가능성**과 **검증 가능성**이
근본적으로 다르다.

| 측면 | RAG/MCP | Submodule + 직접 read |
|---|---|---|
| 같은 질의 → 같은 컨텍스트? | 인덱스 상태에 의존 | git SHA 핀이면 항상 동일 |
| 컨텍스트의 출처 추적 | 인덱싱 metadata 의존 | file_path:line 직접 |
| 토큰 효율 | 청크 다수 = 폭증 | 필요한 파일만 |
| 검색 인프라 비용 | 벡터DB 운영 | 0 |
| Privacy | 외부 인프라 경유 가능 | git 안에서 끝남 |
| LLM 추론 안정성 | 노이즈로 변동 | 일관 |

---

## 5.3 Programmer's Guide = SW-HW 계약 = AI 생성의 진입점

본 워크플로우는 Stage 5 **Programmer's Guide** 를 **SW-HW 계약**으로 둔다.
이는 AI 자동화 관점에서 결정적인 이점을 가진다:

1. **AI가 HAL을 만드는 정해진 입력 형식이 있다**. 가이드 §6 worked example은
   "어떤 시퀀스로 호출되는가"의 정의이므로, AI는 그 시퀀스를 그대로 C 함수
   본문 골격으로 1:1 변환할 수 있다.
2. **AI가 Python coverif scenario를 만드는 정해진 입력 형식이 있다**. 가이드 §6의
   각 worked example을 FW를 구동하는 Python 시퀀스로 1:1 변환하면 끝.
3. **AI가 만든 HAL과 scenarios가 가이드와 어긋나면 invariant #3, #4가
   PR을 fail**시킨다. 즉 AI 출력의 신뢰는 사람이 아니라 CI가 검증.

> **Tutorial-Driven Development의 SoC 적용**. SW 업계의 *Tutorial-Driven
> Development*가 "문서를 먼저 쓰고 코드가 따라간다"는 관점이라면, 본
> 제안은 "RTL → Guide → HAL/Verif"의 SoC 특화 형태이다. AI는 "Guide →
> HAL/Verif" 구간을 거의 결정론적으로 채울 수 있다.

---

## 5.4 AI 자동 생성의 구체적 시나리오 4종

### 시나리오 A — RTL → IP-XACT 초안 (Doc Repo)
- **저장소**: Doc Repo
- **AI 도구**: Read (RTL Repo fetch) + Edit
- **입력**: RTL Repo의 `rtl/<ip>.sv` (read-only fetch), 사람이 갱신한 `doc/<ip>/DLD.md §5`
- **출력**: `doc/<ip>/<ip>.ipxact.xml` 초안
- **검증**: D1, D2 (RTL ↔ DLD ↔ IP-XACT)
- **사람의 검토 초점**: "DLD §5의 register map이 RTL을 정확히 반영하고 있는가" (intent)

### 시나리오 B — IP-XACT → HAL 헤더 (Doc Repo, auto-gen)
- **저장소**: Doc Repo
- **AI 도구**: 결정론적 생성기 (AI 없이도 가능, AI는 보강 주석 / Doxygen 보강 용도)
- **입력**: `doc/<ip>/<ip>.ipxact.xml`
- **출력**: `include/<ip>_hal.h` — register `#define`, struct, inline accessor
- **검증**: D3 (IP-XACT의 모든 register/field가 HAL.h에 등장), D5 (HAL.h ↔ Guide §6 함수 시그너처)
- **사람의 검토 초점**: 매크로 네이밍 일관성 (대부분 컨벤션 자동)

### 시나리오 C — Guide + HAL.h → HAL.c 구현체 (FW Repo)
- **저장소**: FW Repo (doc/는 submodule)
- **AI 도구**: Read + Write
- **입력**: `doc/<ip>/PROGRAMMERS_GUIDE.md §6` (submodule), `doc/include/<ip>_hal.h` (submodule)
- **출력**: `fw/hal/<ip>_hal.c` 함수 구현체
- **검증**: F1 (HAL.c export ↔ HAL.h) + `make test` host smoke (F5)
- **사람의 검토 초점**: 함수 내부 로직의 의도, ISR/락 처리, 펌웨어 컨벤션

### 시나리오 D — Guide → Python coverif scenarios (Test Repo, SSD Host용)
- **저장소**: Test Repo (FW Repo와 분리)
- **AI 도구**: Read + Write
- **입력**: `doc/<ip>/PROGRAMMERS_GUIDE.md §6` (worked examples), §8 (pitfalls)
- **출력**:
  - `tests/scenarios/<ip>/sc_<example>.py` — Worked example을 SSD Host에서 NVMe/PCIe 명령 시퀀스로 변환
  - `tests/scenarios/<ip>/regress_<pitfall>.py` — Pitfall을 회귀 시나리오로
- **검증**: T1 (worked example ↔ scenario), T2 (pitfall ↔ regression). 실측 실행은 SSD Host가 NVMe 드라이버를 통해 FPGA/Veloce/Zebu의 펌웨어를 구동 (nightly + on-demand regress)
- **사람의 검토 초점**: scenario coverage, 측정 가능성 (latency·error 카운트·전력 시퀀스), pre/post 검증의 정확성

> **Python scenario 포맷 (예시 스케치 — SSD Host)**:
> ```python
> def sc_admin_queue_enable(host):
>     """ Guide §6.2: admin queue enable 시퀀스 (SSD Host 관점) """
>     # host = NVMe driver wrapper (PCIe로 SoC에 연결)
>     host.controller_reset()
>     assert host.csts() == 0
>     host.set_admin_queue_base(host.dma_buf.addr)
>     host.cc_enable(1)                                    # CC.EN = 1
>     host.wait_csts_ready(timeout_ms=10)                  # CSTS.RDY
>     # post-condition (admin doorbell counter via vendor command)
>     assert host.vendor_metric("admin_q_doorbell_count") >= 1
> ```
> `host`는 SSD Host에서 NVMe 디바이스를 추상화한 helper. 백엔드(FPGA / Veloce / Zebu)는 PCIe transactor 차이만 있을 뿐 같은 API로 보임.

---

## 5.5 AI 자동화의 안전 boundary

> **원칙**: AI는 RTL을 자동으로 수정하지 않는다.

| AI가 자동 생성하는 산출물 | AI가 자동 수정하지 않는 산출물 |
|---|---|
| `doc/<ip>/*.rdl` 또는 `*.ipxact.xml` (초안) — Doc Repo | RTL Repo의 `*.sv` (의도가 농축됨) |
| `doc/include/*_hal.h` (auto-gen) — Doc Repo | `doc/<ip>/DLD.md §1–4` (의도 설명) |
| `fw/hal/*.c` (초안) — FW Repo | `doc/<ip>/PROGRAMMERS_GUIDE.md` (저자 = SW lead) |
| `tests/scenarios/*.py` (worked example 변환) — Test Repo | Python scenario의 측정·assertion 의도 (DV 리뷰) |
| Doxygen 주석 | FW 측 ISR / 락 / DMA 정책 (FW lead 리뷰) |
| Test 측 NVMe wrapper / host helper 보강 | Test 측 host transactor 정책·플랫폼 매핑 (Validation 리뷰) |

이 boundary는 "AI는 사실(facts) 정합성은 자동화하고, **의도(intent)**는
사람이 정의한다"는 원칙에 기반한다. RTL과 가이드는 의도가 농축된 산출물
이므로 자동 수정 대상이 아니다.

다음 장(6장)에서 이 자동화가 **신규 SoC 부트스트랩** 시점에 어떻게
구체적으로 흘러가는지 End-to-End 워크플로우로 보인다.
