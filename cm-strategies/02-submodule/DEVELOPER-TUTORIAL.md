# 02-Submodule — Developer Tutorial

> Git Submodule 전략에서 IP 개발자가 일상적으로 마주치는 모든 워크플로를
> 실제 명령어로 한 줄씩 체험. 소요 시간 약 **25분**.

대상: SSD SoC 의 IP-level 개발자. 전제: macOS/Linux + Git ≥ 2.40.

> Submodule 의 디테일을 이해하는 것이 함정 회피의 핵심입니다. detached HEAD,
> 부모 push 누락, 다단계 submodule 등의 함정이 다른 전략보다 많습니다.

---

## STEP 0. 로컬 데모 환경 만들기

원격 GitHub Enterprise 가 없어도 submodule 흐름을 실험할 수 있도록 bare repo 모킹:

```bash
cd /Users/euihyeokkwon/Works/soc-cfg-mngt
./cm-strategies/02-submodule/bootstrap-bare-repos.sh /tmp/sub-demo
ls /tmp/sub-demo/remotes | head -10
# common-libs.git, host_ss.git, fcc_ss.git, ip-pcie_phy.git, ...
ls /tmp/sub-demo/work
# ssd-soc-top   (Top repo with submodules wired)
```

이 시점에서 `/tmp/sub-demo/work/ssd-soc-top` 이 우리 "회사" 의 Top SoC repo,
`/tmp/sub-demo/remotes/*.git` 들이 IP/Subsystem 각각의 원격 저장소 역할.

---

## STEP 1. 신규 개발자의 첫 클론

```bash
mkdir -p /tmp/me/work && cd /tmp/me/work
git clone --recurse-submodules /tmp/sub-demo/remotes/ip-pcie_phy.git
cd ip-pcie_phy
ls
# cfg  doc  rtl  sim
```

내 IP 만 작업하면 위 명령이 끝. **Top SoC 차원의 통합**까지 보려면:

```bash
cd /tmp/me/work
git clone --recurse-submodules /tmp/sub-demo/work/ssd-soc-top top
cd top
git submodule status | head -5
# (각 submodule 의 SHA + path)
ls ip/
# 25개 IP 디렉터리
```

> `--recurse-submodules` 안 하면 IP 디렉터리들이 **빈 채로** 나옵니다.
> 까먹었으면: `git submodule update --init --recursive`

---

## STEP 2. 부분 동기화 — host_ss 만 필요하면

```bash
cd /tmp/me/work && rm -rf top-host
git clone --no-recurse-submodules /tmp/sub-demo/work/ssd-soc-top top-host
cd top-host
git submodule update --init common-libs subsystems/host_ss \
    ip/pcie_phy ip/pcie_ctrl ip/nvme_cmd_proc ip/host_dma ip/pcie_cfg

ls ip/
# 활성화된 5개만 실제 코드, 나머지는 빈 디렉터리
du -sh ip/*
```

> manifest 방식에 비해 **명령이 장황한 것** 이 submodule 의 약점.

---

## STEP 3. 내 IP 에 dummy 레지스터 추가 (개발 사이클)

```bash
cd /tmp/me/work/ip-pcie_phy   # 자기 IP 만 클론한 곳
git checkout -b feature/add-status-reg

# RTL 수정
cat >> rtl/pcie_phy.sv <<'EOF'

  // STATUS register (read-only, demo)
  logic [31:0] status_reg;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) status_reg <= 32'h0;
    else        status_reg <= status_reg + 1'b1;
  end
EOF

# ip.yaml version bump
sed -i.bak 's/version:     0\.1\.0/version:     0.2.0/' cfg/pcie_phy.ip.yaml
rm cfg/pcie_phy.ip.yaml.bak

git add -A
git -c user.email=demo@example.com -c user.name=demo \
    commit -m "pcie_phy: add status counter (v0.2.0)"
git push -q -u origin feature/add-status-reg
```

→ IP repo PR 생성 후 머지. 그러면 IP repo 의 main 이 새 SHA.

---

## STEP 4. 릴리스 태그 push (= manifest 갱신 트리거)

```bash
cd /tmp/me/work/ip-pcie_phy
git checkout main && git pull -q
git tag -a v0.2.0 -m "add status counter"
git push -q origin v0.2.0
```

> Submodule 운영에서는 이 tag push 만으로 부모 repo 의 SHA 가 자동 갱신되지 않습니다.
> 다음 STEP 5 가 필요.

---

## STEP 5. Top SoC repo 의 submodule pin 갱신 (별도 PR)

```bash
cd /tmp/me/work/top    # 전체 submodule 클론한 곳
cd ip/pcie_phy
git fetch -q origin
git checkout v0.2.0       # 새 tag 로 이동
cd ../..

git checkout -b bump/pcie_phy-v0.2.0
git add ip/pcie_phy
git -c user.email=demo@example.com -c user.name=demo \
    commit -m "ip/pcie_phy: bump to v0.2.0"
git push -q -u origin bump/pcie_phy-v0.2.0 || echo "(local — would open PR)"
```

> **이게 submodule 의 가장 큰 약점.** monorepo 면 STEP 3 이 끝이지만,
> submodule 은 STEP 3 → STEP 4 → STEP 5 라는 3-step ceremony 가 필수.

자동화 — `cm-strategies/02-submodule/update-submodules-to-tag.sh`:
```bash
cd /tmp/me/work/top
bash /Users/euihyeokkwon/Works/soc-cfg-mngt/cm-strategies/02-submodule/update-submodules-to-tag.sh
git status   # 모든 submodule 이 최신 tag 로 이동된 staged 상태
```

---

## STEP 6. Atomic Cross-IP 변경 — submodule 의 약점

`pcie_ctrl` 과 `nvme_cmd_proc` 인터페이스를 동시에 바꿔야 한다면:

```bash
# 1) IP repo A 변경 → PR → tag
cd /tmp/me/work
git clone -q /tmp/sub-demo/remotes/ip-pcie_ctrl.git pcie_ctrl
( cd pcie_ctrl && git checkout -b refactor/new-api && \
  echo "// new API" >> rtl/pcie_ctrl.sv && \
  git -c user.email=d@e -c user.name=d commit -aq -m "refactor: new API" && \
  git push -q origin refactor/new-api )

# 2) IP repo B 변경 → PR → tag
git clone -q /tmp/sub-demo/remotes/ip-nvme_cmd_proc.git nvme_cmd_proc
( cd nvme_cmd_proc && git checkout -b refactor/new-api && \
  echo "// new API" >> rtl/nvme_cmd_proc.sv && \
  git -c user.email=d@e -c user.name=d commit -aq -m "refactor: new API" && \
  git push -q origin refactor/new-api )

# 3) Top repo 에서 두 submodule SHA 동시 갱신 PR
cd top
git submodule update --remote ip/pcie_ctrl ip/nvme_cmd_proc 2>&1 | head
git checkout -b refactor/new-api-bump
git add ip/pcie_ctrl ip/nvme_cmd_proc
git -c user.email=d@e -c user.name=d commit -aq -m "bump pcie_ctrl + nvme_cmd_proc: new API"
git push -q -u origin refactor/new-api-bump || echo "(local)"
```

**합계 PR 수: 3개** (IP A + IP B + Top). monorepo 의 1개 PR 대비 운영 부담 증가.

운영에서는 자동화 봇 (`tools/manifest_bump.py` 와 유사한 submodule 버전) 으로
3) 단계를 자동 PR 화해야 100명+ 운영이 가능합니다.

---

## STEP 7. 함정 1 — Detached HEAD

submodule 의 가장 흔한 함정. 클론 직후 IP 디렉터리는 detached HEAD 상태:

```bash
cd /tmp/me/work/top/ip/pcie_phy
git status -bs
# ## HEAD (no branch)         ← detached
git log --oneline -1
```

> **여기서 바로 코드 수정/commit 하면**, 그 commit 은 어떤 브랜치에도 속하지 않습니다.
> 다음 `git submodule update` 가 그것을 **그냥 지워버립니다**.

**올바른 절차**:
```bash
cd /tmp/me/work/top/ip/pcie_phy
git fetch origin
git checkout main           # 또는 git checkout -b feature/...
# 이제 commit 안전
```

---

## STEP 8. 함정 2 — Top SHA 미푸시

```bash
cd /tmp/me/work/top
# (이전 STEP 5 에서 commit 만 하고 push 안 했다고 가정)
git status
# 로컬에 commit 이 쌓여있지만 origin 은 옛 SHA 만 알고 있음

# 동료가 clone 하면 → 옛 IP 버전을 받음
# 해결: 반드시 push 한다.
git push -q origin HEAD:main || echo "(가짜 origin)"
```

**모범 사례** — pre-commit hook 또는 CI 가 다음을 검사:
- Top SHA 가 staged 됐는데 IP 의 원격 SHA 와 mismatch → 경고
- IP repo 의 새 tag push 후 일정 시간 (예: 12h) 안에 Top SHA 갱신 PR 없으면 알림

---

## STEP 9. 함정 3 — `.gitmodules` URL 변경

Submodule URL 이 사내 mirror 로 바뀌면 (예: GitHub → 사내 GitLab) 모든 클론이 깨집니다.

```bash
# Git 의 url insteadOf 로 흡수 — 사용자 ~/.gitconfig 또는 회사 표준 설정
git config --global url."git@gitlab.acme:".insteadOf "git@github.com:acme-ssd/"
```

이러면 `.gitmodules` 의 GitHub URL이 그대로 있어도 사내 mirror 가 사용됩니다.

---

## STEP 10. 정리

| 한 줄 요약 | "Submodule = 명시적이지만 장황. 자동화 없이는 100명+ 운영에서 ceremony 비용 폭증." |
|---|---|

**Submodule 이 잘 맞는 환경**
- IP 마다 라이선스/ACL 분리가 필수
- 각 IP 의 릴리스 주기가 독립적 (외부 vendor 도 OK)
- detached HEAD 등의 함정을 팀이 잘 인지

**Submodule 의 시그널 (다른 전략 고려)**
- SKU 파생이 5개 이상으로 늘어남 → `repo+manifest` 로 전환
- 자동 bump PR 봇 없이 운영 → 통합 비용 폭발

다음 단계: 같은 작업을 [03-repo-manifest DEVELOPER-TUTORIAL](../03-repo-manifest/DEVELOPER-TUTORIAL.md) 로 — submodule 의 ceremony 가 어떻게 manifest 한 줄로 단순화되는지 비교.
