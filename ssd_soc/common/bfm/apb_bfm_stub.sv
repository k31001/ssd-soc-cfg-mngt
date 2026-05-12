// SPDX-License-Identifier: Apache-2.0
// Minimal APB BFM stub for smoke tests.
module apb_bfm_stub (apb_if.master m);
  initial begin
    m.psel    = 0; m.penable = 0; m.pwrite = 0;
    m.paddr   = '0; m.pwdata = '0;
  end
endmodule
