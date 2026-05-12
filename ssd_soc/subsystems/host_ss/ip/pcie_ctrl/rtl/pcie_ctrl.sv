// SPDX-License-Identifier: Apache-2.0
// IP: pcie_ctrl
// PCIe controller MAC + DLL + TLP
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef PCIE_CTRL_SV
`define PCIE_CTRL_SV

module pcie_ctrl #(
  parameter int LANES = 4,
  parameter int MAX_PAYLOAD = 256
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, LANES=%0d, MAX_PAYLOAD=%0d", LANES, MAX_PAYLOAD);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // PCIE_CTRL_SV
