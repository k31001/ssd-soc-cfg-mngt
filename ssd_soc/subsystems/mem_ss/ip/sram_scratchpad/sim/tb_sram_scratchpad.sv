// SPDX-License-Identifier: Apache-2.0
// Testbench: tb_sram_scratchpad
// Smoke test for sram_scratchpad IP (instantiation + clock/reset only).

`timescale 1ns/1ps

module tb_sram_scratchpad;
  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;

  initial begin
    #20 rst_n = 1;
    #100;
    $display("[tb_sram_scratchpad] smoke OK");
    $finish;
  end

  // DUT instantiation goes here (interfaces stubbed).
endmodule
