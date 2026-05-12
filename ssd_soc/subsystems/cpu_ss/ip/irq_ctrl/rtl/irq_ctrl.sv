// SPDX-License-Identifier: Apache-2.0
// IP: irq_ctrl  —  PLIC-style Platform-Level Interrupt Controller (single hart, single context)
//
// Synthesizable, APB-slave-attached interrupt aggregator.
// - (NUM_IRQ-1) external sources (source 0 is reserved per PLIC convention).
// - Per-source 4-bit priority (0 = disabled-by-priority, 1..15 = active).
// - Per-source enable bit.
// - Edge-or-level configurable detection per source (compile-time via EDGE_MASK).
// - Threshold register: only sources with priority > threshold can fire eip.
// - Claim/complete handshake: read CLAIM_COMPLETE returns winning source ID and
//   atomically clears its pending state (edge sources); write to CLAIM_COMPLETE
//   acknowledges completion (currently informational — no gating).

`ifndef IRQ_CTRL_SV
`define IRQ_CTRL_SV

module irq_ctrl #(
  parameter int unsigned NUM_IRQ   = 32,    // includes reserved source 0
  parameter int unsigned PRIO_W    = 4,
  // Per-source edge detection mask. Bit i = 1 => source i is edge-triggered
  // (rising edge sets pending; pending stays until claim or W1C clears it).
  // Bit i = 0 => level-triggered (pending follows irq_src_i[i]).
  parameter logic [NUM_IRQ-1:0] EDGE_MASK = '0
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // APB slave (flattened — interface-version provided as wrapper, see below)
  input  logic [11:0]                paddr,
  input  logic                       psel,
  input  logic                       penable,
  input  logic                       pwrite,
  input  logic [31:0]                pwdata,
  output logic [31:0]                prdata,
  output logic                       pready,
  output logic                       pslverr,

  // Interrupt sources (source 0 ignored)
  input  logic [NUM_IRQ-1:0]         irq_src_i,

  // CPU-facing external interrupt pending (active high, level)
  output logic                       eip_o,

  // Currently-winning source ID (informational; CPU normally reads CLAIM)
  output logic [$clog2(NUM_IRQ)-1:0] eip_id_o
);

  // ───────────────────────── Local params / regmap ─────────────────────────
  localparam int ID_W = $clog2(NUM_IRQ);

  localparam logic [11:0] OFF_PRIO_BASE      = 12'h000; // 0x000..0x07C : 32 words
  localparam logic [11:0] OFF_PRIO_LIMIT     = 12'h07C;
  localparam logic [11:0] OFF_PENDING        = 12'h100;
  localparam logic [11:0] OFF_PENDING_CLEAR  = 12'h104;
  localparam logic [11:0] OFF_ENABLE         = 12'h200;
  localparam logic [11:0] OFF_THRESHOLD      = 12'h300;
  localparam logic [11:0] OFF_CLAIM_COMPLETE = 12'h304;
  localparam logic [11:0] OFF_IP_ID          = 12'h308;
  localparam logic [11:0] OFF_IP_VERSION     = 12'h30C;

  localparam logic [31:0] IP_ID_VALUE        = 32'h4952_4301; // "IRC\1"
  localparam logic [31:0] IP_VERSION_VALUE   = 32'h0001_0000; // v1.0.0

  // ───────────────────────── Storage ─────────────────────────
  logic [PRIO_W-1:0]   priority_q [NUM_IRQ];
  logic [NUM_IRQ-1:0]  enable_q;
  logic [NUM_IRQ-1:0]  pending_q;
  logic [PRIO_W-1:0]   threshold_q;
  logic [NUM_IRQ-1:0]  irq_src_d;       // for edge detection

  // ───────────────────────── APB handshake helpers ─────────────────────────
  wire access_phase = psel & penable;
  wire wr_access    = access_phase &  pwrite;
  wire rd_access    = access_phase & ~pwrite;
  wire is_prio_range = (paddr <= OFF_PRIO_LIMIT);
  wire [4:0] prio_idx = paddr[6:2];

  // Forward-declared (used in pending logic)
  logic              claim_rd_fire;
  logic [ID_W-1:0]   claim_id;

  // ───────────────────────── Combinational priority winner ─────────────────────────
  logic [NUM_IRQ-1:0] eligible;
  always_comb begin
    eligible = '0;
    for (int i = 1; i < NUM_IRQ; i++) begin
      eligible[i] = pending_q[i] & enable_q[i] & (priority_q[i] > threshold_q);
    end
  end

  logic [PRIO_W-1:0] best_prio;
  logic [ID_W-1:0]   best_id;
  always_comb begin
    best_prio = '0;
    best_id   = '0;
    for (int i = 1; i < NUM_IRQ; i++) begin
      if (eligible[i] && priority_q[i] > best_prio) begin
        best_prio = priority_q[i];
        best_id   = i[ID_W-1:0];
      end
    end
  end

  assign eip_o    = (best_id != '0);
  assign eip_id_o = best_id;
  assign claim_id = best_id;

  // ───────────────────────── Pending update ─────────────────────────
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pending_q <= '0;
      irq_src_d <= '0;
    end else begin
      irq_src_d <= irq_src_i;

      for (int i = 0; i < NUM_IRQ; i++) begin
        if (i == 0) begin
          pending_q[0] <= 1'b0;                 // reserved
        end else if (EDGE_MASK[i]) begin
          if (irq_src_i[i] & ~irq_src_d[i])
            pending_q[i] <= 1'b1;               // set on rising edge
        end else begin
          pending_q[i] <= irq_src_i[i];         // level-track
        end
      end

      // W1C from SW (only effective for edge sources)
      if (wr_access && paddr == OFF_PENDING_CLEAR) begin
        for (int i = 0; i < NUM_IRQ; i++) begin
          if (i != 0 && pwdata[i] && EDGE_MASK[i])
            pending_q[i] <= 1'b0;
        end
      end

      // Atomic clear on claim (edge sources only)
      if (claim_rd_fire && claim_id != '0 && EDGE_MASK[claim_id])
        pending_q[claim_id] <= 1'b0;
    end
  end

  // ───────────────────────── APB read mux ─────────────────────────
  logic [31:0] rdata_c;
  always_comb begin
    rdata_c = 32'h0;
    unique case (1'b1)
      is_prio_range:                       rdata_c = {{(32-PRIO_W){1'b0}}, priority_q[prio_idx]};
      (paddr == OFF_PENDING):              rdata_c = pending_q;
      (paddr == OFF_PENDING_CLEAR):        rdata_c = 32'h0;       // W1C — read 0
      (paddr == OFF_ENABLE):               rdata_c = enable_q;
      (paddr == OFF_THRESHOLD):            rdata_c = {{(32-PRIO_W){1'b0}}, threshold_q};
      (paddr == OFF_CLAIM_COMPLETE):       rdata_c = {{(32-ID_W){1'b0}}, best_id};
      (paddr == OFF_IP_ID):                rdata_c = IP_ID_VALUE;
      (paddr == OFF_IP_VERSION):           rdata_c = IP_VERSION_VALUE;
      default:                             rdata_c = 32'h0;
    endcase
  end

  assign claim_rd_fire = rd_access && (paddr == OFF_CLAIM_COMPLETE);

  // Address-decode error & writes to RO
  logic addr_valid;
  always_comb begin
    addr_valid = is_prio_range
              || (paddr == OFF_PENDING)
              || (paddr == OFF_PENDING_CLEAR)
              || (paddr == OFF_ENABLE)
              || (paddr == OFF_THRESHOLD)
              || (paddr == OFF_CLAIM_COMPLETE)
              || (paddr == OFF_IP_ID)
              || (paddr == OFF_IP_VERSION);
  end

  logic wr_to_ro;
  always_comb begin
    wr_to_ro = wr_access && ( (paddr == OFF_PENDING)
                           || (paddr == OFF_IP_ID)
                           || (paddr == OFF_IP_VERSION) );
  end

  // ───────────────────────── APB write side ─────────────────────────
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      enable_q    <= '0;
      threshold_q <= '0;
      for (int i = 0; i < NUM_IRQ; i++) priority_q[i] <= '0;
    end else begin
      priority_q[0] <= '0;  // source 0 priority pinned

      if (wr_access) begin
        if (is_prio_range && prio_idx != 0) begin
          priority_q[prio_idx] <= pwdata[PRIO_W-1:0];
        end else if (paddr == OFF_ENABLE) begin
          enable_q    <= pwdata[NUM_IRQ-1:0];
          enable_q[0] <= 1'b0;
        end else if (paddr == OFF_THRESHOLD) begin
          threshold_q <= pwdata[PRIO_W-1:0];
        end
        // CLAIM_COMPLETE write is informational (no gating in this revision).
      end
    end
  end

  // ───────────────────────── APB outputs ─────────────────────────
  assign prdata  = rd_access ? rdata_c : 32'h0;
  assign pready  = access_phase;       // 2-cycle access; ready in ACCESS phase
  assign pslverr = access_phase & (~addr_valid | wr_to_ro);

endmodule

// ─────────────────────────────────────────────────────────────────────────────
// Thin wrapper that adapts the project-wide `apb_if` to the flat-port core.
// Existing instantiations using `apb_if.slave` continue to compile.
// ─────────────────────────────────────────────────────────────────────────────
module irq_ctrl_apbif #(
  parameter int unsigned NUM_IRQ = 32,
  parameter int unsigned PRIO_W  = 4,
  parameter logic [NUM_IRQ-1:0] EDGE_MASK = '0
) (
  input  logic                       clk,
  input  logic                       rst_n,
  apb_if.slave                       s_apb,
  input  logic [NUM_IRQ-1:0]         irq_src_i,
  output logic                       eip_o,
  output logic [$clog2(NUM_IRQ)-1:0] eip_id_o
);
  irq_ctrl #(
    .NUM_IRQ   (NUM_IRQ),
    .PRIO_W    (PRIO_W),
    .EDGE_MASK (EDGE_MASK)
  ) u_core (
    .clk      (clk),
    .rst_n    (rst_n),
    .paddr    (s_apb.paddr[11:0]),
    .psel     (s_apb.psel),
    .penable  (s_apb.penable),
    .pwrite   (s_apb.pwrite),
    .pwdata   (s_apb.pwdata),
    .prdata   (s_apb.prdata),
    .pready   (s_apb.pready),
    .pslverr  (s_apb.pslverr),
    .irq_src_i(irq_src_i),
    .eip_o    (eip_o),
    .eip_id_o (eip_id_o)
  );
endmodule

`endif // IRQ_CTRL_SV
