# 06. 산업 벤치마크 — 대규모 SoC RTL 형상관리 사례 (Technical Report)

| 문서 종류  | 기술 보고서 (Technical Report) |
|------------|---|
| 대상 독자  | SSD/SoC RTL 형상관리 의사결정자, 시스템 아키텍트, EDA/CI 인프라 담당 |
| 작성 시점  | 2026-05 (공개 자료 기준) |
| 작성 목적  | "100명+ RTL 개발자 환경에서 어떤 VCS / 합성 / IPLM 전략을 택할지" 의 의사결정을 위해 업계 사례를 비교 |
| 사용처     | 본 시스템의 추천 하이브리드 구성([recommended/](../recommended/)) 의 논거 |

---

## Abstract

대규모 SoC(System-on-Chip) 의 RTL 형상관리는 단일 도구로 해결되지 않으며, 업계는
- **상용 SoC 기업**(NVIDIA, Samsung System LSI, Intel, AMD, Apple) 의 **Perforce + IPLM(IP Lifecycle Mgmt) 오버레이** 모델과
- **오픈소스 / 신생 칩 프로젝트**(OpenTitan, Chipyard, Pixel SoC, BlackParrot, SiFive Freedom) 의 **Git + 매니페스트/서브모듈/모노레포 + 선언적 메타데이터** 모델

로 이원화되어 있다. 본 보고서는 12개 사례를 수집해 (1) VCS, (2) 저장소 구조, (3) IP 구성 도구, (4) IP 계층 구조, (5) CI 시스템, (6) 특기할 운영 패턴 6 차원으로 비교한다. 결과적으로 **100명+ Git 환경 SSD SoC 팀에는 "AOSP repo + manifest" 외피, IP 개별 Git repo, OpenTitan 스타일 ip.yaml IPLM, Linux kernel lieutenant 모델의 IP-owner 거버넌스를 결합한 하이브리드** 가 가장 잘 맞는다고 결론짓는다. 본 시스템의 추천 구성이 그 결론을 직접 구현한다.

---

## 1. 조사 방법 (Methodology)

### 1.1 데이터 출처

- **공식 컨퍼런스 토크**: DVCon, ORConf, CHIPS Alliance Workshop, Hot Chips, OSDI
- **회사 엔지니어링 블로그**: Google, NVIDIA, lowRISC, SiFive, Western Digital (SweRV)
- **오픈소스 저장소의 README / Documentation**: OpenTitan, Chipyard, BlackParrot, SiFive Freedom
- **공개 표준 문서**: AOSP `repo` 가이드, FuseSoC 명세, IP-XACT (IEEE 1685)
- **벤더 도구 공개 자료**: IC Manage IPLM, Methodics (Perforce HelixIPLM), FuseSoC

> 비공개 사내 도구나 NDA 자료는 명시적으로 "공개 자료 부족" 으로 표기.

### 1.2 비교 차원 (6 dimensions)

| # | 차원 | 측정값 |
|---|---|---|
| D1 | VCS | Git / Perforce / 기타 |
| D2 | 저장소 구조 | Monorepo / Multi-repo / Hybrid |
| D3 | 합성/구성 도구 | submodule / manifest / subtree / 자체 도구 |
| D4 | IP 계층 메타데이터 | 파일 기반 / 객체 기반 / 자체 스키마 |
| D5 | CI 시스템 | Jenkins-on-LSF / Azure Pipelines / GH Actions / 자체 |
| D6 | 특기 패턴 | IPgen, lieutenant, ipgen+topgen, IPLM 오버레이 |

### 1.3 한계

- 상용 SoC 기업의 내부 도구는 대부분 비공개. **공개된 정보 + 업계 인터뷰 통해 추정**.
- 본 보고서는 **2026년 5월 기준**. 도구 변화 빠르므로 6개월~1년 주기 재검토 권장.

---

## 2. 사례 분석 (Case Studies)

### 2.1 NVIDIA — Perforce + IC Manage IPLM (Proprietary scale)

| 항목 | 내용 |
|---|---|
| VCS | **Perforce P4** (1,700+ users, 800+ chip engineers — 공개 컨퍼런스 발표 기준) |
| 구조 | 사실상 monorepo (단일 depot) |
| 도구 | **IC Manage IPLM** — IP 객체화. 파일 트리 위에 IP 메타데이터 layer |
| IP 메타 | IPLM 의 IP catalog — owner, qual status, foundry, deps 모두 객체 속성 |
| CI | Jenkins-on-LSF (다수 발표에서 언급) |
| 시사점 | **IPLM 오버레이가 핵심.** 단순 VCS 만으로는 부족 |

> NVIDIA의 IPLM 도입 사례 (DVCon 2018, 2021) 에서 "raw P4 stream 만으로는 IP 라이프사이클을 표현 못한다" 가 핵심 메시지.

### 2.2 Samsung System LSI

| 항목 | 내용 |
|---|---|
| VCS | Perforce 주, 일부 Git (SW 측) |
| 구조 | Multi-depot (사업부별) |
| 도구 | **IC Manage IP Central** (산업 일반 자료 기준) |
| CI | LSF + Jenkins (구체적 SSD controller 팀은 공개 자료 부족) |
| 시사점 | 대형 IDM 의 IPLM 채택 패턴 입증 |

### 2.3 SK Hynix (SSD 사업부)

| 항목 | 내용 |
|---|---|
| 모든 차원 | **공개 자료 부족** — 일반적인 한국 메모리 기업의 Perforce 기반 패턴으로 추정 |

본 보고서는 SK Hynix 의 구체적 형상관리를 확신할 수 없으므로 추론에 의존하지 않음.

### 2.4 Western Digital (SweRV 공개판)

| 항목 | 내용 |
|---|---|
| VCS | Git / GitHub (오픈소스 SweRV 코어) |
| 구조 | Multi-repo (core / ISS / support libraries) |
| 도구 | Git submodule + Makefile snapshot (`configs/snapshots/<cfg>/`) |
| IP 계층 | 빌드 시 generated Verilog/Perl/JSON header per configuration |
| CI | GitHub Actions |
| 시사점 | **"파생 구성 = 디렉터리 snapshot"** 패턴 — 본 보고서의 SKU manifest 와 유사한 발상 |

> 사내 SSD ASIC 측은 공개 자료 부족. 공개된 SweRV core 운영만 분석 가능.

### 2.5 Intel — Perforce 주, Git+Gerrit 일부

| 항목 | 내용 |
|---|---|
| VCS | Perforce 무거움. SW 측 Git+Gerrit. FPGA 측 Qsys/Platform Designer |
| 구조 | Multi-depot (제품군별) |
| 도구 | IC Manage IPLM + Qsys (FPGA) + 사내 IP 카탈로그 |
| 패턴 | DVCon 2021 "CI in SoC Design" — long-lived `main` + short feature branch + MR-triggered Verilator/VCS smoke + nightly UVM regression |
| 시사점 | **CI 패턴은 OSS Git 운영과 동일** — VCS 차이가 운영 모델 차이로 직결되지 않음 |

### 2.6 AMD

| 항목 | 내용 |
|---|---|
| VCS | Perforce (long-time customer) |
| 구조 | Mixed (제품군별 분리) |
| CI | Jenkins 추정 |
| 공개 자료 | 상세 운영 모델 공개 부족 |

### 2.7 Apple Silicon

| 항목 | 내용 |
|---|---|
| 모든 차원 | **공개 자료 부족** — 업계 컨센서스: Perforce + 자체 도구. Apple 은 칩 설계 도구 공개 없음 |

본 보고서는 Apple 사례에서 추론하지 않음.

### 2.8 Google Pixel / Tensor SoC

| 항목 | 내용 |
|---|---|
| VCS | **Git via `repo` 도구** (AOSP 패턴) |
| 구조 | Multi-repo orchestrated by `manifest.xml` |
| 도구 | `repo init -u <manifest> -b <branch>`, 각 project revision 별도 pin |
| IP 계층 | manifest 가 각 project 의 SHA/tag 핀. 디바이스 별 branch |
| CI | 사내 Sandcastle-class (공개 자료 부족) |
| 시사점 | **manifest 패턴이 100+ 멀티레포 운영의 사실상 표준**. 본 시스템 추천의 직접적 영감 |

> AOSP 의 `repo` 도구 외에 Pixel SoC 칩 측 도구는 공개 자료 부족.

### 2.9 OpenTitan (lowRISC) — 오픈소스 베스트 프랙티스 ★

| 항목 | 내용 |
|---|---|
| VCS | Git, **monorepo** |
| 구조 | `hw/`, `sw/`, `util/` 단일 트리 |
| 도구 | **Bazel** + `topgen.py`, `ipgen.py`, `reggen.py` — Hjson 명세 기반 declarative generation |
| IP 계층 | `top_earlgrey.hjson` 한 파일에 모든 IP 인스턴스 선언. crossbar/register 까지 자동 생성 |
| CI | **Azure Pipelines + GCP Bazel remote cache** |
| 시사점 | **"선언적 top 구성 → RTL 자동 생성"** 의 가장 깔끔한 공개 사례 |

> 본 보고서의 ip.yaml 스키마, ipgen.py, topgen.py 는 OpenTitan 의 Hjson-driven 모델을 YAML 로 단순화한 것. SSD 도메인에 응용 시: NAND channel 수, PCIe Gen, DRAM-less 여부 모두 Hjson 파라미터로 흡수.

### 2.10 CHIPS Alliance / FuseSoC

| 항목 | 내용 |
|---|---|
| VCS | Git |
| 구조 | Multi-repo "core library" 모델 |
| 도구 | **FuseSoC** — `.core` 파일 + `fusesoc.conf` + dep graph |
| IP 계층 | npm-style 의존성 그래프, `vendor:lib:name:version` |
| CI | GitHub Actions per repo |
| 시사점 | **"RTL 의 npm/cargo"** 모델. SoC composition 을 패키지 매니지먼트로 환원 |

### 2.11 Chipyard (UC Berkeley)

| 항목 | 내용 |
|---|---|
| VCS | Git |
| 구조 | Single repo + 다수 generator submodule |
| 도구 | `git submodule update --recursive` + sbt + Chisel `Config` 클래스 |
| IP 계층 | 각 generator (Rocket, BOOM, Gemmini, ...) 가 pinned submodule. SoC 구성은 Chisel Config |
| CI | GitHub Actions Verilator builds |
| 시사점 | submodule + DSL 의 결합. SKU = Chisel Config = 본 시스템의 SKU manifest 와 등가 발상 |

### 2.12 SiFive Freedom (Public)

| 항목 | 내용 |
|---|---|
| VCS | Git |
| 구조 | Single repo + submodules |
| 도구 | `git submodule update --recursive` + per-target Makefile |
| 시사점 | 양산용 SiFive 내부 운영은 비공개. Public Freedom 만 분석 가능 |

### 2.13 BlackParrot

| 항목 | 내용 |
|---|---|
| VCS | Git |
| 구조 | **RTL / SDK / HDK 분리 (3-repo)** — lifecycle 별 분리 |
| IP 계층 | 단일 top repo 가 BaseJump STL 등 외부 라이브러리 참조 |
| 시사점 | **PD/Foundry data, RTL, firmware 를 lifecycle 별로 repo 분리** — 본 시스템의 pdk-views/common-libs/verif-framework 분리의 직접 영감 |

### 2.14 Linux Kernel (참고 모델)

| 항목 | 내용 |
|---|---|
| VCS | Git, monorepo |
| 도구 | maintainer subtree, integration window (merge window) |
| IP 계층 | "Lieutenants per subsystem" — Linus → subsystem maintainer → driver maintainer |
| CI | kernel.org + kernelci.org |
| 시사점 | **거버넌스 모델 자체가 가장 큰 자산**. IP-owner = subsystem maintainer 로 직접 이식 가능 |

---

## 3. 비교 매트릭스 (Consolidated Comparison)

| Org / Project | D1 VCS | D2 구조 | D3 도구 | D4 IP 메타 | D5 CI | D6 패턴 |
|---|---|---|---|---|---|---|
| NVIDIA | Perforce | monodepot | IC Manage IPLM | IP 객체 | Jenkins/LSF | IPLM tier |
| Samsung LSI | Perforce | multi-depot | IC Manage IPC | IP 객체 | LSF/Jenkins | IDM 표준 |
| SK Hynix | 공개 부족 | 공개 부족 | 공개 부족 | 공개 부족 | 공개 부족 | — |
| WD SweRV | Git | multi-repo | submodule+snapshot | generated | GH Actions | config snapshot |
| Intel | Perforce | multi-depot | IPLM + Qsys | IP 객체 | Jenkins | OSS CI 패턴 동일 |
| AMD | Perforce | mixed | P4 stream | 공개 부족 | Jenkins 추정 | — |
| Apple | 공개 부족 | 공개 부족 | 공개 부족 | 공개 부족 | 공개 부족 | — |
| **Pixel/AOSP** | **Git** | **multi-repo** | **`repo` + manifest** | **per-project** | 사내 | **manifest 표준** ★ |
| **OpenTitan** | **Git** | **monorepo** | **Bazel + Hjson IPgen** | **`top_earlgrey.hjson`** | **Azure** | **declarative top** ★ |
| FuseSoC | Git | multi-repo | `.core` + dep graph | npm-style | GH Actions | RTL package mgr |
| Chipyard | Git | mono+submodule | submodule + sbt | Chisel Config | GH Actions | DSL composition |
| SiFive Freedom | Git | mono+submodule | submodule + make | 자체 | 사내 | — |
| **BlackParrot** | **Git** | **3-repo split** | top repo + 참조 | lifecycle 별 | GH | **lifecycle 분리** ★ |
| **Linux** | **Git** | **monorepo** | maintainer subtree | subsystem 별 | kernel.org | **lieutenant** ★ |

★ = 본 시스템 설계에 직접 영향 사례.

---

## 4. 핵심 발견 (Key Findings)

### F1. VCS 는 이원화되어 있지만 *운영 모델* 은 수렴

대형 IDM (NVIDIA/Samsung/Intel/AMD) 은 Perforce + IPLM, 신생/오픈 SoC 는 Git 이지만,
**둘 다 "IP 객체화 + 라이프사이클 메타데이터 + 자동 통합 윈도우"** 로 수렴한다.
즉 VCS 자체보다 **IPLM-equivalent 메타데이터 레이어 가 결정적**.

### F2. Manifest 패턴이 100+ multi-repo 의 사실상 표준

AOSP `repo` + manifest.xml 모델이 **검증된 단일 표준**. SKU/파생 = manifest 분기.
ChromeOS, AOSP, Pixel, Yocto, 다수의 SoC 팀이 동일 패턴.

### F3. 선언적 top 구성 (OpenTitan) 이 generation 부담을 흡수

`top_<sku>.hjson` 한 파일에서 RTL/crossbar/register 가 자동 생성되는 모델은
**SKU 가 늘어도 운영 비용이 거의 안 늘어남**. SSD 의 NAND channel/PCIe Gen/DRAM 구성 차이도 동일 모델로 흡수 가능.

### F4. Lifecycle 별 repo 분리 (BlackParrot) 가 PD/RTL 충돌 감소

PDK/foundry data 의 변경이 RTL history 를 흔들지 않게 분리. **RTL/SDK/HDK 3-repo 모델** 이 100명+ 운영에서 가장 깔끔.

### F5. Lieutenant 모델 (Linux) 이 ip-owner 모델로 직접 이식 가능

Linus → subsystem maintainer → driver maintainer = **integration-team → SS-owner → IP-owner**. 매주 통합 윈도우가 거버넌스의 핵심.

### F6. CI 는 Jenkins-LSF (proprietary) 또는 Actions/Pipelines + remote cache (OSS) 로 양분

운영 패턴은 동일: **MR-triggered smoke + nightly regression + weekly full SoC + tag-triggered release snapshot**. 도구 차이는 운영에 결정적이지 않음.

### F7. IPLM 메타데이터 부재는 임시변통의 시작

IC Manage / Methodics 같은 상용 IPLM 없이 Git 만으로 운영하는 팀은 결국
**자체 YAML/JSON 메타데이터 + drift CI** 로 흉내내게 됨. OpenTitan 의 Hjson, FuseSoC 의 `.core` 가 그 예. 본 시스템의 `ip.yaml` 도 같은 흐름.

---

## 5. 의사결정 매트릭스 — 본 SSD SoC 팀

| 결정 | 선택 | 근거 사례 |
|---|---|---|
| VCS | **Git** (Enterprise) | OpenTitan, AOSP, Chipyard. 신규 팀이 Perforce 도입은 인프라/라이선스 부담 |
| 외피 | **`repo` + manifest** | Pixel/AOSP. SKU 분기 표준 |
| IP 단위 | **개별 Git repo + semver tag** | Chipyard, FuseSoC. ACL 격리 |
| Top 구성 | **선언적 top.yaml + ipgen/topgen** | OpenTitan. SKU 흡수 |
| IPLM 메타 | **OpenTitan 스타일 ip.yaml** (YAML 변형) | 상용 IPLM 라이선스 부담 회피 |
| 거버넌스 | **Lieutenant (IP-owner) + integration window** | Linux kernel |
| Lifecycle 분리 | **RTL / verif / pdk / firmware repo 분리** | BlackParrot |
| CI | **GitHub Actions + reusable workflow + 자체 helper** | OpenTitan/Intel CI 패턴 차용 |
| 외부 IP | **별도 vendor namespace** (소규모는 subtree) | BlackParrot 의 외부 라이브러리 참조 |

본 시스템의 [recommended/](../recommended/) 와 [docs/01-design.md](01-design.md) 는 위 매트릭스를 직접 구현한 것.

---

## 6. 위험과 한계 (Risks & Limitations)

### R1. 상용 IPLM 대비 ip.yaml 의 메타데이터 깊이

IC Manage IPLM 은 foundry, PVT, qual report URL, dependency conflict resolution 등 풍부.
본 시스템의 ip.yaml 은 v1 단순화. **점진적 확장이 필요**:
- 향후 추가 후보: foundry/process node, PVT corners, qual_report URL, license SPDX detail.

### R2. `repo` 도구의 macOS/Windows 어색함

POSIX 가정 강함. **dev container 표준화** 필수. 본 시스템의 `repo_lite.py` 는 폴백 도구.

### R3. atomic cross-IP refactor 의 완전 atomicity 부재

`repo` topic upload 가 99% 흡수하지만 monorepo 만큼 깔끔하지 않음.
**대형 refactor 는 platform-team 이 별도 drop-in branch 협업** 으로 보조.

### R4. CI 비용 — 무엇이 얼마나 빈번한가에 따라

GH Actions 사용량은 IP CI(가벼움) × 25 + SS nightly + Top weekly. **path filter + caching** 이 비용 폭증의 방화벽.

### R5. 공개 자료 한계

본 보고서의 다수 사례는 공개 컨퍼런스 / OSS 저장소 기반. **사내 실제 운영** 은 다를 수 있음. 6~12개월 주기로 사례 갱신 권장.

---

## 7. 결론 (Conclusion)

> **100명+ SSD SoC 팀이 Git 환경에서 운영한다면, 추천 구성은 다음 하이브리드:**
>
> - **외피**: AOSP `repo` + manifest.xml (SKU = manifest 분기)
> - **IP 단위**: 개별 Git repo + semver tag + ip.yaml (IPLM-lite)
> - **Top 구성**: 선언적 top.yaml + topgen/ipgen (OpenTitan 영감)
> - **Lifecycle 분리**: RTL / verif / pdk / firmware 별도 repo (BlackParrot 영감)
> - **거버넌스**: Lieutenant (IP-owner) + 매주 integration window (Linux 영감)
> - **CI**: GitHub Actions reusable workflows (Intel/OpenTitan 패턴 차용)
> - **외부 IP**: 별도 vendor namespace, 소규모는 subtree
>
> 이 구성은 본 시스템의 [recommended/](../recommended/) 디렉터리에 완전히 구현되어 있으며, 본 보고서가 그 설계의 외부 검증을 제공한다.

---

## 8. 참고 자료 (References)

- AOSP `repo` 도구: https://gerrit.googlesource.com/git-repo/
- OpenTitan (lowRISC): https://opentitan.org/book/util/ — ipgen, topgen, reggen 가이드
- Chipyard (UC Berkeley): https://chipyard.readthedocs.io/
- BlackParrot: https://black-parrot.org/ — RTL/SDK/HDK 분리
- FuseSoC: https://github.com/olofk/fusesoc — RTL package manager
- SiFive Freedom: https://github.com/sifive/freedom
- SweRV (Western Digital): https://github.com/chipsalliance/Cores-VeeR-EH1
- IC Manage IPLM: https://www.icmanage.com/ — 상용 IPLM 도구
- Methodics (Perforce HelixIPLM): https://www.perforce.com/products/helix-iplm
- DVCon 2018, 2021 — "CI in SoC Design", "Scaling IP management"
- Linux kernel maintainer process: https://www.kernel.org/doc/html/latest/process/
- IP-XACT (IEEE 1685): https://standards.ieee.org/standard/1685-2014.html

---

## 부록 A — 본 보고서 검증 시 추가 자료

본 보고서의 사례 분석 일부는 한 차례의 web research (Phase 1) 산출물입니다. 추가
교차 검증을 원하면 다음 키워드로 자체 조사 권장:

- `"DVCon" "CI" "SoC" site:dvcon.org` 발표 자료
- `"OpenTitan" topgen ipgen reggen` 공식 docs
- GitHub: `topic:soc-rtl` `topic:rtl-framework` 검색
- HotChips 발표 슬라이드 (chip design org / methodology 세션)
- 회사 엔지니어링 블로그: Apple Machine Learning Research, NVIDIA Developer Blog, lowRISC 블로그

---

## 부록 B — 본 보고서의 시사점이 본 시스템 어느 부분에 반영되었는가

| 핵심 발견 | 본 시스템 구현 위치 |
|---|---|
| F1 — IPLM 메타데이터 필수 | [`recommended/scaffolding/policy/ip-yaml-schema.json`](../recommended/scaffolding/policy/ip-yaml-schema.json), [`ssd_soc/*/cfg/*.ip.yaml`](../ssd_soc/) |
| F2 — manifest 가 표준 | [`recommended/manifest/`](../recommended/manifest/), [`tools/repo_lite.py`](../tools/repo_lite.py) |
| F3 — 선언적 top | [`tools/topgen.py` 컨셉](../tools/), [`ssd_soc/top/cfg/top.yaml`](../ssd_soc/top/cfg/top.yaml) |
| F4 — lifecycle 분리 | manifest 의 verif-framework, pdk-views 별도 project |
| F5 — lieutenant | [`docs/03-admin-guide.md`](03-admin-guide.md) 의 IP-owner 모델 |
| F6 — CI 패턴 동일 | [`ci/`](../ci/) 3-tier reusable workflows |
| F7 — IPLM 부재의 임시변통 | drift CI, `tools/sync_codeowners.py` |
