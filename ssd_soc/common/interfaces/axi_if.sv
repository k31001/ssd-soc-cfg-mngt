// SPDX-License-Identifier: Apache-2.0
// AXI4-lite-ish interface (stub for compile only).

interface axi_if #(
  parameter int ADDR_W = 40,
  parameter int DATA_W = 64
) (input logic clk = 0, input logic rst_n = 1);
  logic [ADDR_W-1:0] awaddr, araddr;
  logic [DATA_W-1:0] wdata,  rdata;
  logic              awvalid, awready;
  logic              wvalid,  wready;
  logic              arvalid, arready;
  logic              rvalid,  rready;
  logic              bvalid,  bready;

  modport master (input  awready, wready, arready, rdata, rvalid, bvalid,
                  output awaddr, araddr, wdata, awvalid, wvalid, arvalid, rready, bready);
  modport slave  (output awready, wready, arready, rdata, rvalid, bvalid,
                  input  awaddr, araddr, wdata, awvalid, wvalid, arvalid, rready, bready);
endinterface
