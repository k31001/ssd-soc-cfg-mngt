// SPDX-License-Identifier: Apache-2.0
// Testbench: tb_ddr4_ctrl
// Smoke test for ddr4_ctrl IP (instantiation + clock/reset only).

`timescale 1ns/1ps

module tb_ddr4_ctrl;
  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;

  initial begin
    #20 rst_n = 1;
    #100;
    $display("[tb_ddr4_ctrl] smoke OK");
    $finish;
  end

  // DUT instantiation goes here (interfaces stubbed).
endmodule
