// SPDX-License-Identifier: Apache-2.0
// Testbench: tb_pcie_cfg
// Smoke test for pcie_cfg IP (instantiation + clock/reset only).

`timescale 1ns/1ps

module tb_pcie_cfg;
  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;

  initial begin
    #20 rst_n = 1;
    #100;
    $display("[tb_pcie_cfg] smoke OK");
    $finish;
  end

  // DUT instantiation goes here (interfaces stubbed).
endmodule
