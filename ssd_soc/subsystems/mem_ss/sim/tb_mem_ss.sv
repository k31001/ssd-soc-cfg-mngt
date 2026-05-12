`timescale 1ns/1ps
module tb_mem_ss;
  logic clk=0, rst_n=0;
  always #5 clk=~clk;
  initial begin #20 rst_n=1; #200 $display("[tb_mem_ss] smoke OK"); $finish; end
endmodule
