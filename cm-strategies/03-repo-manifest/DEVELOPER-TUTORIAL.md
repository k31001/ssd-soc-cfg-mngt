# 03-Repo+Manifest — Developer Tutorial

> AOSP `repo` 도구 + `manifest.xml` 기반 워크플로를 IP 개발자가 처음부터 끝까지
> 따라하며 익히는 튜토리얼. 소요 시간 약 **30분**.

대상: SSD SoC 의 IP-level 개발자. 전제: macOS/Linux + Python 3.10+.

> `repo` 바이너리가 없어도 본 저장소의 `tools/repo_lite.py` 가 같은 manifest
> 흐름을 시연합니다. 실제 운영 환경에서는 사내 mirror 의 `repo` 사용.

---

## STEP 0. 로컬 환경 부트스트랩

```bash
cd /Users/euihyeokkwon/Works/soc-cfg-mngt
./cm-strategies/03-repo-manifest/bootstrap-local.sh /tmp/rm-demo
ls /tmp/rm-demo/work
# manifest/  (manifest repo)
# checkout/  (sync 결과 워크스페이스)
```

이 시점에서 `/tmp/rm-demo/work/checkout/` 이 **개발자 워크스페이스** 라고 생각하면 됩니다.

---

## STEP 1. 워크스페이스 구조 이해

```bash
ls /tmp/rm-demo/work/checkout
# common-libs/  ip/  pdk/  subsystems/  top/  verif/
ls /tmp/rm-demo/work/checkout/ip | head
# 25개 IP 디렉터리 — 각각 독립 git repo
git -C /tmp/rm-demo/work/checkout/ip/pcie_phy remote -v
# origin  /tmp/rm-demo/remotes/ip-pcie_phy.git
```

> **핵심 인식**: 워크스페이스 안의 각 디렉터리는 **독립된 Git repo**. submodule 처럼
> Top repo 가 SHA 를 박는 게 아니라, `manifest.xml` 이 외부에서 "이 디렉터리는
> 이 repo 의 이 revision 으로 채워라" 라고 지시합니다.

---

## STEP 2. 신규 개발자 첫 sync

원격이 GitHub Enterprise 라면:

```bash
mkdir -p ~/work/ssd-soc && cd ~/work/ssd-soc
repo init -u git@github.com:acme-ssd/ssd-soc-manifest.git -b main -m default.xml
repo sync -j 16
```

로컬 데모에서는:
```bash
mkdir -p /tmp/rm-demo/me && cd /tmp/rm-demo/me
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/repo_lite.py sync \
   --manifest /tmp/rm-demo/work/manifest/default.xml \
   --workdir  . 2>&1 | tail -5
ls
# 34개 component (1 top + 5 ss + 25 ip + common + verif + pdk + manifest)
```

---

## STEP 3. 부분 sync — host 팀만

```bash
mkdir -p /tmp/rm-demo/host-only && cd /tmp/rm-demo/host-only
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/repo_lite.py sync \
   --manifest /tmp/rm-demo/work/manifest/default.xml \
   --workdir  . \
   --groups   default,ip,host,common
ls ip | head
# host_ss 산하 5개 IP 만 (pcie_phy, pcie_ctrl, nvme_cmd_proc, host_dma, pcie_cfg)
```

> 한 줄로 부분 sync — submodule 의 장황한 명령 대비 핵심 우위.

---

## STEP 4. SKU 별 워크스페이스 분리

같은 머신에서 두 SKU 를 동시에 작업:

```bash
mkdir -p /tmp/rm-demo/gen5 && cd /tmp/rm-demo/gen5
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/repo_lite.py sync \
   --manifest /tmp/rm-demo/work/manifest/sku-gen5-4tb.xml \
   --workdir  .

# pcie_phy 가 gen5 태그 (실제로는 v3.0.1-gen5) 로 핀
cd ip/pcie_phy
git describe --tags --always
git rev-parse HEAD
```

mainline 워크스페이스의 같은 IP 와 다른 commit/tag 입니다. **`repo` 의 결정적 우위**.

---

## STEP 5. 일상 개발 사이클 (IP 1개)

```bash
cd /tmp/rm-demo/me/ip/pcie_phy
git status -bs
# ## main...origin/main

git checkout -b feature/add-status-reg
cat >> rtl/pcie_phy.sv <<'EOF'

  // STATUS register (read-only, demo)
  logic [31:0] status_reg;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) status_reg <= 32'h0;
    else        status_reg <= status_reg + 1'b1;
  end
EOF

sed -i.bak 's/version:     0\.1\.0/version:     0.2.0/' cfg/pcie_phy.ip.yaml
rm cfg/pcie_phy.ip.yaml.bak

git add -A
git -c user.email=d@e -c user.name=d commit -m "pcie_phy: add status counter (v0.2.0)"
git push -q -u origin feature/add-status-reg
```

→ IP repo 의 PR 단독 생성. submodule 처럼 부모 SHA 갱신을 별도 PR 로 할 필요 없음.

---

## STEP 6. 릴리스 tag — manifest 자동 갱신

```bash
cd /tmp/rm-demo/me/ip/pcie_phy
# (PR 머지 가정)
git checkout main && git pull -q
git tag -a v0.2.0 -m "add status counter"
git push -q origin v0.2.0
```

운영에서는 `manifest-bot` 이 `ip-tag-published` 이벤트를 받아
mainline `default.xml` 의 본 IP `revision` 을 갱신하는 PR 을 **자동 생성**합니다.

로컬에서 같은 동작을 수동 시연:
```bash
cp /tmp/rm-demo/work/manifest/default.xml /tmp/m.xml
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/manifest_bump.py bump \
   --manifest /tmp/m.xml --name ip-pcie_phy --revision v0.2.0
grep pcie_phy /tmp/m.xml | head -1
# ip-pcie_phy 가 refs/tags/v0.2.0 로 핀됨
```

---

## STEP 7. Atomic Cross-IP — `topic upload`

`pcie_ctrl` 과 `nvme_cmd_proc` 를 동시에 변경:

```bash
cd /tmp/rm-demo/me/ip/pcie_ctrl
git checkout -b refactor/new-api
echo "// new API" >> rtl/pcie_ctrl.sv
git -c user.email=d@e -c user.name=d commit -aq -m "refactor: new API"

cd ../nvme_cmd_proc
git checkout -b refactor/new-api
echo "// new API" >> rtl/nvme_cmd_proc.sv
git -c user.email=d@e -c user.name=d commit -aq -m "refactor: new API"
```

원격에서는:
```bash
# 실제 repo 도구 환경
repo upload --current-branch --re=reviewer1
# 같은 topic 으로 묶여 Gerrit/리뷰 UI 에서 함께 보임
```

> Monorepo 의 완전 atomic 은 아니지만 **운영의 99% 케이스를 흡수**.
> Submodule 의 3-PR ceremony 대비 큰 개선.

---

## STEP 8. workspace 상태 점검

```bash
cd /tmp/rm-demo/me
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/repo_lite.py status \
   --manifest /tmp/rm-demo/work/manifest/default.xml --workdir . | head -15
# PATH         REV         STATE
# top          xxxxxxx     clean
# common-libs  xxxxxxx     clean
# ip/pcie_phy  xxxxxxx     dirty   ← 내가 작업 중인 곳
```

---

## STEP 9. Release snapshot 받기 (양산 동결 manifest 사용)

양산 시점에 어떤 IP 가 어떤 SHA 였는지 100% 재현하려면:

```bash
# 가상의 release manifest (양산 시점에 release.py 가 생성)
mkdir -p /tmp/rm-demo/release-2026Q3 && cd /tmp/rm-demo/release-2026Q3
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/release.py snapshot \
   --src-manifest /tmp/rm-demo/work/manifest/default.xml \
   --workdir      /tmp/rm-demo/work/checkout \
   --sku gen5-4tb --release-id 2026Q3 \
   --out          release-2026Q3.xml

python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/repo_lite.py sync \
   --manifest release-2026Q3.xml --workdir . 2>&1 | tail -3
```

워크스페이스가 release manifest 의 모든 SHA 와 정확히 일치하게 됩니다.

---

## STEP 10. 함정 (Pitfalls — repo+manifest edition)

| 증상 | 원인 | 해결 |
|---|---|---|
| `repo sync` 가 hang | 인증/네트워크 | `gh auth setup-git`, mirror 사용 |
| 어떤 IP 만 새 commit 이 안 받아짐 | manifest 가 tag pin | 해당 IP 는 SKU 분기 — 의도된 동작 |
| 본인 PR 머지 후 mainline 에서 안 보임 | manifest-bot PR 아직 안 머지 | PR 묶음 리뷰 daily window 확인 |
| Windows 에서 `repo` 가 동작 어색 | repo 도구의 POSIX 의존 | dev container (Ubuntu) 사용 |
| 다른 IP 를 일시적으로 sparse 에 추가 | groups 미숙지 | `--groups default,ip,host,flash` 일시 사용 |

---

## 정리

| 한 줄 요약 | "Manifest = 100+ multi-repo 의 사실상 표준. 학습곡선만 넘으면 SKU/부분 sync/atomic 의 모든 약점이 해소." |
|---|---|

다음 단계: [04-subtree DEVELOPER-TUTORIAL](../04-subtree/DEVELOPER-TUTORIAL.md) — 외부 vendor IP 들여올 때의 subtree 패턴.
