# SSD SoC 데모 Makefile (Verilator/Icarus 기반)
TOP ?= ssd_soc_top
VERILATOR ?= verilator
ICARUS    ?= iverilog
VERIBLE   ?= verible-verilog-lint

FILELIST := ssd_soc/scripts/compile.f
BUILD    := build

.PHONY: sim lint clean elab

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
