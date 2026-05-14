# web/ — IP Closed-Loop Workflow Dashboard

본 디렉터리는 `docs/WORKFLOW.md` 에서 정의한 closed-loop workflow 를
설명하고, 레포 내 25개 IP 의 stage 완료도를 실시간으로 보여주는 정적
사이트다.

## 구성

| 파일              | 역할                                            |
|-------------------|------------------------------------------------|
| `index.html`      | 단일 페이지 (Mermaid + 표 + 매핑 trace)         |
| `styles.css`      | 라이트 테마 스타일                               |
| `app.js`          | `data/status.json` 을 읽어 IP × stage 매트릭스 렌더 |
| `data/status.json`| `tools/ipflow.py status --json` 의 출력 (CI 가 갱신) |

외부 의존성은 **Mermaid CDN** 한 가지뿐이며, 빌드 단계가 없다.

## 로컬에서 미리보기

```bash
# 데이터 갱신
tools/ipflow.py status --json > web/data/status.json

# 정적 서버
cd web && python3 -m http.server 8000
# → http://localhost:8000
```

`file://` 로 열면 fetch 가 CORS 로 막히므로 반드시 HTTP 서버를 통해 본다.

## GitHub Pages 배포

레포 Settings → Pages 에서:
- Source: `Deploy from a branch`
- Branch: `main` / `/web`

설정 후 `https://k31001.github.io/ssd-soc-cfg-mngt/` 로 노출.

## 데이터 자동 갱신

`ci/ip-ci.yml` 의 `refresh-web-status` job 이 push 마다
`tools/ipflow.py status --json > web/data/status.json` 을 실행한 뒤
변경분이 있으면 자동 commit (또는 PR comment) 한다. 상세는
`docs/WORKFLOW.md §5` 참조.
