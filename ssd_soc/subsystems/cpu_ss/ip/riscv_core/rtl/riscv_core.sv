// SPDX-License-Identifier: Apache-2.0
// IP: riscv_core
// RISC-V RV32IMC core (stub)
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef RISCV_CORE_SV
`define RISCV_CORE_SV

module riscv_core #(
  parameter int XLEN = 32,
  parameter int MHARTID = 0
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, XLEN=%0d, MHARTID=%0d", XLEN, MHARTID);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // RISCV_CORE_SV
