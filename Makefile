# SSD SoC 데모 Makefile (Verilator/Icarus 기반)
TOP ?= ssd_soc_top
VERILATOR ?= verilator
ICARUS    ?= iverilog
VERIBLE   ?= verible-verilog-lint

FILELIST := ssd_soc/scripts/compile.f
BUILD    := build

.PHONY: sim lint clean elab report-sync report-serve

elab:
	$(VERILATOR) --lint-only -Wall -Wno-fatal -f $(FILELIST) --top-module $(TOP)

sim:
	mkdir -p $(BUILD)
	$(VERILATOR) --binary -Wno-fatal -f $(FILELIST) --top-module $(TOP) -Mdir $(BUILD)/obj_dir
	$(BUILD)/obj_dir/V$(TOP) || true

lint:
	@find ssd_soc -name '*.sv' -print0 | xargs -0 $(VERIBLE) --rules=-line-length || true

clean:
	rm -rf $(BUILD)

# ─────────────────── Proposal report viewer (web/report/) ───────────────────
# docs/proposal/*.md → web/report/content/*.md 동기화.
# CI(.github/workflows/deploy-pages.yml) 도 동일 step 을 호출한다.
report-sync:
	@bash web/report/sync.sh

# 로컬에서 보고서·발표·대시보드를 한 번에 미리보기.
#   http://localhost:8000/         (워크플로우 대시보드)
#   http://localhost:8000/report/  (제안 보고서)
#   http://localhost:8000/present/ (발표 슬라이드)
report-serve: report-sync
	@echo "Serving web/ on http://localhost:8000  (Ctrl-C to stop)"
	@python3 -m http.server -d web 8000
