// SPDX-License-Identifier: Apache-2.0
// APB-ish interface (stub).

interface apb_if #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32
) (input logic clk = 0, input logic rst_n = 1);
  logic [ADDR_W-1:0] paddr;
  logic              psel;
  logic              penable;
  logic              pwrite;
  logic [DATA_W-1:0] pwdata, prdata;
  logic              pready;
  logic              pslverr;

  modport master (input  prdata, pready, pslverr,
                  output paddr, psel, penable, pwrite, pwdata);
  modport slave  (output prdata, pready, pslverr,
                  input  paddr, psel, penable, pwrite, pwdata);
endinterface
