// SPDX-License-Identifier: Apache-2.0
// IP: nand_ctrl
// NAND command sequencer + timing engine
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef NAND_CTRL_SV
`define NAND_CTRL_SV

module nand_ctrl #(
  parameter int CHANNELS = 8,
  parameter int CE_PER_CH = 4
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, CHANNELS=%0d, CE_PER_CH=%0d", CHANNELS, CE_PER_CH);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // NAND_CTRL_SV
