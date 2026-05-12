// SPDX-License-Identifier: Apache-2.0
// IP: irq_ctrl
// PLIC-compatible interrupt controller
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef IRQ_CTRL_SV
`define IRQ_CTRL_SV

module irq_ctrl #(
  parameter int NUM_IRQ = 128
) (
  input  logic        clk,
  input  logic        rst_n,
  apb_if.slave        s_apb
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, NUM_IRQ=%0d", NUM_IRQ);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // IRQ_CTRL_SV
