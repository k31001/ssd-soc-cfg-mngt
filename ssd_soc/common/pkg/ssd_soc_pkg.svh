// SPDX-License-Identifier: Apache-2.0
// ssd_soc_pkg — SoC-wide type definitions.

`ifndef SSD_SOC_PKG_SVH
`define SSD_SOC_PKG_SVH

package ssd_soc_pkg;
  // Generic widths
  parameter int AXI_ADDR_W = 40;
  parameter int AXI_DATA_W = 64;
  parameter int APB_ADDR_W = 32;
  parameter int APB_DATA_W = 32;

  typedef enum logic [1:0] {
    LINK_DOWN = 2'b00,
    LINK_INIT = 2'b01,
    LINK_UP   = 2'b10,
    LINK_ERR  = 2'b11
  } link_state_e;
endpackage

// Bring interfaces into scope for `include consumers.
`include "axi_if.sv"
`include "apb_if.sv"

`endif // SSD_SOC_PKG_SVH
