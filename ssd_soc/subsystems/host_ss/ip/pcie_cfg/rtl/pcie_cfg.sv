// SPDX-License-Identifier: Apache-2.0
// IP: pcie_cfg
// PCIe configuration space + capability registers
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef PCIE_CFG_SV
`define PCIE_CFG_SV

module pcie_cfg #(
  parameter int PCIE_GEN = 4
) (
  input  logic        clk,
  input  logic        rst_n,
  apb_if.slave        s_apb
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, PCIE_GEN=%0d", PCIE_GEN);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // PCIE_CFG_SV
