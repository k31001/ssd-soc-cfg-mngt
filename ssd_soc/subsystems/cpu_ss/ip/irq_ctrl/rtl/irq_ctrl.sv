// SPDX-License-Identifier: Apache-2.0
// IP: irq_ctrl  —  PLIC 계열 Platform-Level Interrupt Controller (single hart, single context)
//
// 합성 가능하며 APB-slave에 연결되는 interrupt aggregator.
// - (NUM_IRQ-1)개의 외부 source (source 0은 PLIC 관례에 따라 예약).
// - source별 4-bit priority (0 = priority 기준 비활성, 1..15 = 활성).
// - source별 enable 비트.
// - source별 edge/level 감지 모드 (compile-time EDGE_MASK).
// - Threshold register: priority > threshold인 source만 eip를 fire.
// - Claim/complete handshake: CLAIM_COMPLETE read는 winning source ID 반환 및
//   해당 pending atomic clear (edge source 전용); write는 완료 ack
//   (현재는 informational — gating 없음).

`ifndef IRQ_CTRL_SV
`define IRQ_CTRL_SV

module irq_ctrl #(
  parameter int unsigned NUM_IRQ   = 32,    // 예약된 source 0 포함
  parameter int unsigned PRIO_W    = 4,
  // source별 edge 감지 mask. 비트 i = 1 => source i가 edge-triggered
  // (rising edge에서 pending set; claim 또는 W1C로 clear될 때까지 유지).
  // 비트 i = 0 => level-triggered (pending이 irq_src_i[i]를 추적).
  parameter logic [NUM_IRQ-1:0] EDGE_MASK = '0
) (
  input  logic                       clk,
  input  logic                       rst_n,

  // APB slave (flattened — interface 버전은 아래 wrapper로 제공)
  input  logic [11:0]                paddr,
  input  logic                       psel,
  input  logic                       penable,
  input  logic                       pwrite,
  input  logic [31:0]                pwdata,
  output logic [31:0]                prdata,
  output logic                       pready,
  output logic                       pslverr,

  // Interrupt source (source 0 무시)
  input  logic [NUM_IRQ-1:0]         irq_src_i,

  // CPU에 전달되는 external interrupt pending (active high, level)
  output logic                       eip_o,

  // 현재 winning source ID (informational; CPU는 보통 CLAIM을 read)
  output logic [$clog2(NUM_IRQ)-1:0] eip_id_o
);

  // ───────────────────────── Local params / regmap ─────────────────────────
  localparam int ID_W = $clog2(NUM_IRQ);

  // PRIORITY array region: 0x000..0x07C — `is_prio_range` 가 이 비교만 사용.
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
  logic [NUM_IRQ-1:0]  irq_src_d;       // edge 검출용

  // ───────────────────────── APB handshake helpers ─────────────────────────
  wire access_phase = psel & penable;
  wire wr_access    = access_phase &  pwrite;
  wire rd_access    = access_phase & ~pwrite;
  wire is_prio_range = (paddr <= OFF_PRIO_LIMIT);
  wire [4:0] prio_idx = paddr[6:2];

  // Forward 선언 (pending logic에서 사용)
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
          pending_q[0] <= 1'b0;                 // 예약 source
        end else if (EDGE_MASK[i]) begin
          if (irq_src_i[i] & ~irq_src_d[i])
            pending_q[i] <= 1'b1;               // rising edge에서 set
        end else begin
          pending_q[i] <= irq_src_i[i];         // level 추적
        end
      end

      // SW의 W1C (edge source에만 유효)
      if (wr_access && paddr == OFF_PENDING_CLEAR) begin
        for (int i = 0; i < NUM_IRQ; i++) begin
          if (i != 0 && pwdata[i] && EDGE_MASK[i])
            pending_q[i] <= 1'b0;
        end
      end

      // Claim 시 atomic clear (edge source 전용)
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
      (paddr == OFF_PENDING_CLEAR):        rdata_c = 32'h0;       // W1C — read는 0
      (paddr == OFF_ENABLE):               rdata_c = enable_q;
      (paddr == OFF_THRESHOLD):            rdata_c = {{(32-PRIO_W){1'b0}}, threshold_q};
      (paddr == OFF_CLAIM_COMPLETE):       rdata_c = {{(32-ID_W){1'b0}}, best_id};
      (paddr == OFF_IP_ID):                rdata_c = IP_ID_VALUE;
      (paddr == OFF_IP_VERSION):           rdata_c = IP_VERSION_VALUE;
      default:                             rdata_c = 32'h0;
    endcase
  end

  assign claim_rd_fire = rd_access && (paddr == OFF_CLAIM_COMPLETE);

  // 주소 decode 에러 & RO write 검출
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
      priority_q[0] <= '0;  // source 0 priority는 0으로 고정

      if (wr_access) begin
        if (is_prio_range && prio_idx != 0) begin
          priority_q[prio_idx] <= pwdata[PRIO_W-1:0];
        end else if (paddr == OFF_ENABLE) begin
          enable_q    <= pwdata[NUM_IRQ-1:0];
          enable_q[0] <= 1'b0;
        end else if (paddr == OFF_THRESHOLD) begin
          threshold_q <= pwdata[PRIO_W-1:0];
        end
        // CLAIM_COMPLETE write는 informational (본 revision에는 gating 없음).
      end
    end
  end

  // ───────────────────────── APB outputs ─────────────────────────
  assign prdata  = rd_access ? rdata_c : 32'h0;
  assign pready  = access_phase;       // 2-cycle access; ACCESS phase에 ready
  assign pslverr = access_phase & (~addr_valid | wr_to_ro);

endmodule

// ─────────────────────────────────────────────────────────────────────────────
// 프로젝트 공통 `apb_if`를 flat-port core에 연결하는 얇은 wrapper.
// `apb_if.slave`를 사용하는 기존 instantiation은 그대로 compile된다.
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
