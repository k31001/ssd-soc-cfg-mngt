`timescale 1ns/1ps
module tb_ssd_soc;
  logic clk=0, rst_n=0;
  always #5 clk=~clk;
  initial begin #20 rst_n=1; #500 $display("[tb_ssd_soc] SoC smoke OK"); $finish; end
  ssd_soc_top dut(.clk(clk), .rst_n(rst_n), .pcie_tx_p(), .pcie_tx_n(), .pcie_rx_p('0), .pcie_rx_n('0),
                  .ddr_dq(), .nand_ce_n(), .nand_dq());
endmodule
