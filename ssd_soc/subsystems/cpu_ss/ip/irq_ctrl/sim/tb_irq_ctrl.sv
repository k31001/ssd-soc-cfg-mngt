// SPDX-License-Identifier: Apache-2.0
// Testbench: tb_irq_ctrl
// Self-checking testbench for irq_ctrl IP.
//
// Coverage:
//   T1  reset state                       — all regs zero, no eip
//   T2  IP_ID / IP_VERSION readback       — RO regs return constants
//   T3  priority/enable RW                — write-then-read consistency
//   T4  level source                      — pending tracks line; eip rises/falls
//   T5  edge source rising-edge capture   — pending sticks after deassert
//   T6  threshold gating                  — eip suppressed below threshold
//   T7  priority arbitration              — highest priority wins; tie → lowest ID
//   T8  claim atomically clears pending   — edge source cleared by claim read
//   T9  PENDING_CLEAR (W1C) edge          — software-cleared edge bit
//   T10 pslverr on unmapped address       — error response
//   T11 pslverr on RO write               — write to PENDING/IP_ID/IP_VERSION

`timescale 1ns/1ps

module tb_irq_ctrl;
  // ─── Parameters ───
  localparam int NUM_IRQ = 32;
  // Edge for sources 1..7, level for 8..31
  localparam logic [NUM_IRQ-1:0] EDGE_MASK = 32'h0000_00FE;

  // Address map
  localparam logic [11:0] OFF_PRIO_BASE      = 12'h000;
  localparam logic [11:0] OFF_PENDING        = 12'h100;
  localparam logic [11:0] OFF_PENDING_CLEAR  = 12'h104;
  localparam logic [11:0] OFF_ENABLE         = 12'h200;
  localparam logic [11:0] OFF_THRESHOLD      = 12'h300;
  localparam logic [11:0] OFF_CLAIM_COMPLETE = 12'h304;
  localparam logic [11:0] OFF_IP_ID          = 12'h308;
  localparam logic [11:0] OFF_IP_VERSION     = 12'h30C;

  // ─── Clock / reset ───
  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;  // 100 MHz

  // ─── DUT signals ───
  logic [11:0] paddr;
  logic        psel, penable, pwrite;
  logic [31:0] pwdata, prdata;
  logic        pready, pslverr;
  logic [NUM_IRQ-1:0] irq_src;
  logic        eip;
  logic [$clog2(NUM_IRQ)-1:0] eip_id;

  // ─── DUT ───
  irq_ctrl #(
    .NUM_IRQ   (NUM_IRQ),
    .PRIO_W    (4),
    .EDGE_MASK (EDGE_MASK)
  ) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .paddr    (paddr),
    .psel     (psel),
    .penable  (penable),
    .pwrite   (pwrite),
    .pwdata   (pwdata),
    .prdata   (prdata),
    .pready   (pready),
    .pslverr  (pslverr),
    .irq_src_i(irq_src),
    .eip_o    (eip),
    .eip_id_o (eip_id)
  );

  // ─── Score keeping ───
  int errors = 0;
  task automatic CHECK(input string tag, input bit cond);
    if (!cond) begin
      $display("[FAIL] %s @%0t", tag, $time);
      errors++;
    end else begin
      $display("[ pass ] %s", tag);
    end
  endtask

  // ─── APB driver (2-cycle SETUP+ACCESS) ───
  task automatic apb_write(input logic [11:0] addr, input logic [31:0] data, output logic err);
    @(posedge clk);
    paddr   <= addr;
    pwdata  <= data;
    pwrite  <= 1'b1;
    psel    <= 1'b1;
    penable <= 1'b0;
    @(posedge clk);
    penable <= 1'b1;
    @(posedge clk);
    err     = pslverr;
    psel    <= 1'b0;
    penable <= 1'b0;
    pwrite  <= 1'b0;
  endtask

  task automatic apb_read(input logic [11:0] addr, output logic [31:0] data, output logic err);
    @(posedge clk);
    paddr   <= addr;
    pwrite  <= 1'b0;
    psel    <= 1'b1;
    penable <= 1'b0;
    @(posedge clk);
    penable <= 1'b1;
    @(posedge clk);
    data    = prdata;
    err     = pslverr;
    psel    <= 1'b0;
    penable <= 1'b0;
  endtask

  // Wrappers that ignore err
  task automatic W(input logic [11:0] a, input logic [31:0] d);
    logic e; apb_write(a, d, e);
  endtask
  task automatic R(input logic [11:0] a, output logic [31:0] d);
    logic e; apb_read(a, d, e);
  endtask

  // ─── Main scenario ───
  logic [31:0] rd;
  logic        err;

  initial begin
    // Init
    paddr=0; psel=0; penable=0; pwrite=0; pwdata=0;
    irq_src = '0;
    repeat (3) @(posedge clk);
    rst_n = 1;
    repeat (3) @(posedge clk);

    // ── T1: reset state ──
    R(OFF_ENABLE,    rd); CHECK("T1 enable reset = 0",    rd == 32'h0);
    R(OFF_PENDING,   rd); CHECK("T1 pending reset = 0",   rd == 32'h0);
    R(OFF_THRESHOLD, rd); CHECK("T1 threshold reset = 0", rd == 32'h0);
    CHECK("T1 eip low at reset", eip == 1'b0);

    // ── T2: RO id/version ──
    R(OFF_IP_ID,      rd); CHECK("T2 IP_ID",      rd == 32'h4952_4301);
    R(OFF_IP_VERSION, rd); CHECK("T2 IP_VERSION", rd == 32'h0001_0000);

    // ── T3: priority/enable RW ──
    W(OFF_PRIO_BASE + 12'(5*4), 32'h7);
    R(OFF_PRIO_BASE + 12'(5*4), rd); CHECK("T3 prio[5] rw", rd == 32'h7);
    W(OFF_ENABLE, 32'hFFFF_FFFF);
    R(OFF_ENABLE, rd); CHECK("T3 enable rw (src0 forced 0)", rd == 32'hFFFF_FFFE);

    // ── T4: level source (src 16) ──
    W(OFF_PRIO_BASE + 12'(16*4), 32'h5);
    irq_src[16] = 1'b1;
    repeat (3) @(posedge clk);
    R(OFF_PENDING, rd); CHECK("T4 level pending set", rd[16] == 1'b1);
    CHECK("T4 eip high for level",       eip == 1'b1);
    CHECK("T4 eip_id == 16",             eip_id == 16);
    irq_src[16] = 1'b0;
    repeat (3) @(posedge clk);
    R(OFF_PENDING, rd); CHECK("T4 level pending clears", rd[16] == 1'b0);
    CHECK("T4 eip low after deassert",   eip == 1'b0);

    // ── T5: edge source (src 3) ──
    W(OFF_PRIO_BASE + 12'(3*4), 32'h6);
    irq_src[3] = 1'b1;
    repeat (2) @(posedge clk);
    irq_src[3] = 1'b0;   // line goes low but pending must stick (edge)
    repeat (3) @(posedge clk);
    R(OFF_PENDING, rd); CHECK("T5 edge pending sticks", rd[3] == 1'b1);
    CHECK("T5 eip high for edge",        eip == 1'b1);
    CHECK("T5 eip_id == 3",              eip_id == 3);

    // ── T6: threshold gating ──
    W(OFF_THRESHOLD, 32'hA);    // 0xA > prio 6 — should mask src3
    repeat (2) @(posedge clk);
    CHECK("T6 eip masked by threshold",  eip == 1'b0);
    W(OFF_THRESHOLD, 32'h0);
    repeat (2) @(posedge clk);
    CHECK("T6 eip restored",             eip == 1'b1);

    // ── T7: arbitration. Add src 5 (edge? no — 5 is level per EDGE_MASK=0xFE → only 1..7 edge; 5 IS edge).
    //       Use src 5 (edge, prio 7) vs src 3 (edge, prio 6). 5 should win.
    irq_src[5] = 1'b1;
    repeat (2) @(posedge clk);
    irq_src[5] = 1'b0;
    repeat (2) @(posedge clk);
    CHECK("T7 higher prio wins (5 over 3)",   eip_id == 5);

    // Tie: set src 7 prio = 7 too — lowest ID (5) should still win.
    W(OFF_PRIO_BASE + 12'(7*4), 32'h7);
    irq_src[7] = 1'b1;
    repeat (2) @(posedge clk);
    irq_src[7] = 1'b0;
    repeat (2) @(posedge clk);
    CHECK("T7 tie → lowest ID wins",          eip_id == 5);

    // ── T8: claim atomically clears pending (src 5) ──
    R(OFF_CLAIM_COMPLETE, rd);  // reading claim must return 5 and clear it
    CHECK("T8 claim returns winning ID",      rd == 32'd5);
    repeat (2) @(posedge clk);
    R(OFF_PENDING, rd); CHECK("T8 src 5 pending cleared by claim", rd[5] == 1'b0);
    // Now src 7 should be the winner (still pending, lower-or-equal prio? src 3 prio 6, src 7 prio 7)
    CHECK("T8 next winner = 7",               eip_id == 7);

    // ── T9: PENDING_CLEAR W1C — clear src 3 ──
    W(OFF_PENDING_CLEAR, 32'h0000_0008);   // bit 3
    repeat (2) @(posedge clk);
    R(OFF_PENDING, rd); CHECK("T9 W1C clears src 3", rd[3] == 1'b0);

    // After clearing 3, src 7 remains. Claim it too.
    R(OFF_CLAIM_COMPLETE, rd); CHECK("T9 claim 7", rd == 32'd7);
    repeat (2) @(posedge clk);
    CHECK("T9 eip low (all cleared)", eip == 1'b0);

    // ── T10: pslverr on unmapped address ──
    apb_read(12'h0FC, rd, err);
    CHECK("T10 unmapped read raises pslverr", err == 1'b1);

    // ── T11: pslverr on RO write ──
    apb_write(OFF_IP_ID, 32'hDEADBEEF, err);
    CHECK("T11 write to IP_ID raises pslverr", err == 1'b1);
    apb_write(OFF_PENDING, 32'h1, err);
    CHECK("T11 write to PENDING raises pslverr", err == 1'b1);

    // ─── Done ───
    if (errors == 0)
      $display("[tb_irq_ctrl] ALL TESTS PASSED");
    else
      $display("[tb_irq_ctrl] %0d FAILURES", errors);
    $finish;
  end

  // Watchdog
  initial begin
    #100000;
    $display("[tb_irq_ctrl] TIMEOUT");
    $finish;
  end
endmodule
