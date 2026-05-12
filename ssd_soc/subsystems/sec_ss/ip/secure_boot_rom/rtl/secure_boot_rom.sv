// SPDX-License-Identifier: Apache-2.0
// IP: secure_boot_rom
// Secure boot ROM + verifier
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef SECURE_BOOT_ROM_SV
`define SECURE_BOOT_ROM_SV

module secure_boot_rom #(
  parameter int ROM_KB = 64
) (
  input  logic        clk,
  input  logic        rst_n,
  axi_if.slave        s_axi
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated, ROM_KB=%0d", ROM_KB);
  end
  // synthesis translate_on

  // Stub tie-offs intentionally omitted (interfaces only).

endmodule

`endif // SECURE_BOOT_ROM_SV
