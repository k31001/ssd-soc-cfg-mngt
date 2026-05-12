// SPDX-License-Identifier: Apache-2.0
// Minimal AXI BFM stub for smoke tests.
module axi_bfm_stub (axi_if.master m);
  initial begin
    m.awvalid = 0; m.wvalid = 0; m.arvalid = 0;
    m.rready  = 1; m.bready = 1;
  end
endmodule
