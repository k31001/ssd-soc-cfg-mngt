// SPDX-License-Identifier: Vendor-Proprietary-Demo
// Mock vendor LDPC codec stub.
module ldpc_codec_vendor #(
  parameter int CODEWORD   = 4096,
  parameter int ITERATIONS = 16
)(
  input  logic clk,
  input  logic rst_n,
  // simplified streaming interface
  input  logic        in_valid,
  input  logic [7:0]  in_data,
  output logic        out_valid,
  output logic [7:0]  out_data
);
  assign out_valid = in_valid;
  assign out_data  = in_data;  // pass-through stub
endmodule
