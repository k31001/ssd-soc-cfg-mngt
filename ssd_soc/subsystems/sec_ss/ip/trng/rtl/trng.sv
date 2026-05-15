// SPDX-License-Identifier: Apache-2.0
// IP: trng  —  True Random Number Generator (entropy source emulator + health test + FIFO)
//
// 합성 가능한 APB-slave attached TRNG. 실제 silicon TRNG의 analog entropy
// source 는 본 디자인에서 3개의 32-bit Galois LFSR XOR 로 대체된 emulator
// 이지만, 그 위에 얹은 health test / FIFO / SFR / interrupt 인프라는
// production-grade 동작 그대로이다.
//
// Architecture:
//   3 × Galois LFSR(32-bit, 서로 다른 tap mask) → XOR → candidate word
//   health test (repetition: 4 consecutive equal → fail)
//   16-entry × 32-bit output FIFO
//   APB SFR (CTRL/STATUS/DATA/FIFO_LEVEL/HEALTH/SEEDx/INTR_*/IP_ID/VERSION)
//   irq_o = |( intr_status & intr_en )

`ifndef TRNG_SV
`define TRNG_SV

module trng (
  input  logic        clk,
  input  logic        rst_n,

  // APB slave (flattened — interface 버전은 아래 wrapper 로 제공)
  input  logic [11:0] paddr,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr,

  output logic        irq_o
);

  // ─────────────────────────── Register offsets ───────────────────────────
  localparam logic [11:0] OFF_CTRL         = 12'h000;
  localparam logic [11:0] OFF_STATUS       = 12'h004;
  localparam logic [11:0] OFF_DATA         = 12'h008;
  localparam logic [11:0] OFF_FIFO_LEVEL   = 12'h00C;
  localparam logic [11:0] OFF_HEALTH       = 12'h010;
  localparam logic [11:0] OFF_SEED0        = 12'h014;
  localparam logic [11:0] OFF_SEED1        = 12'h018;
  localparam logic [11:0] OFF_SEED2        = 12'h01C;
  localparam logic [11:0] OFF_INTR_EN      = 12'h020;
  localparam logic [11:0] OFF_INTR_STATUS  = 12'h024;
  localparam logic [11:0] OFF_IP_ID        = 12'h030;
  localparam logic [11:0] OFF_IP_VERSION   = 12'h034;

  localparam logic [31:0] IP_ID_VALUE      = 32'h5452_4E47; // "TRNG"
  localparam logic [31:0] IP_VERSION_VALUE = 32'h0001_0000; // v1.0.0

  // ─────────────────────────── LFSR tap masks ───────────────────────────
  // bit[31] feedback 시 XOR 되는 mask. 0 seed 일 때는 LFSR 이 0 에 갇혀
  // candidate 도 0 으로 머무므로 health test 가 빠르게 fail 한다 — 검증 경로로 활용.
  localparam logic [31:0] TAP0 = 32'h8020_0003;
  localparam logic [31:0] TAP1 = 32'h9000_8001;
  localparam logic [31:0] TAP2 = 32'hA200_0001;

  // ─────────────────────────── APB helpers ───────────────────────────
  wire access_phase = psel & penable;
  wire wr_access    = access_phase &  pwrite;
  wire rd_access    = access_phase & ~pwrite;

  // ─────────────────────────── Storage ───────────────────────────
  logic        ctrl_enable_q;
  logic [31:0] seed0_q, seed1_q, seed2_q;
  logic [31:0] lfsr0_q, lfsr1_q, lfsr2_q;
  logic [31:0] candidate_q;        // 직전 cycle candidate (health 비교용)
  logic [31:0] candidate_new;      // 이번 cycle candidate (조합)
  logic [3:0]  rep_count_q;        // 연속 동일 count
  logic        health_fail_q;

  // FIFO
  localparam int FIFO_DEPTH = 16;
  localparam int FIFO_AW    = 4;
  logic [31:0]        fifo_mem [FIFO_DEPTH];
  logic [FIFO_AW:0]   fifo_count_q;
  logic [FIFO_AW-1:0] fifo_wr_ptr_q;
  logic [FIFO_AW-1:0] fifo_rd_ptr_q;

  // Interrupts
  logic [1:0] intr_en_q;            // bit0=DATA_READY, bit1=HEALTH_FAIL
  logic [1:0] intr_status_q;
  logic       data_ready_d;
  logic       health_fail_d;     // edge-detect for latch

  // Forward signals
  logic       fifo_push;
  logic       fifo_pop;
  wire        fifo_full  = (fifo_count_q == FIFO_DEPTH[FIFO_AW:0]);
  wire        fifo_empty = (fifo_count_q == '0);
  wire        data_ready = ~fifo_empty;

  // ─────────────────────────── LFSR step ───────────────────────────
  function automatic logic [31:0] lfsr_step(input logic [31:0] state, input logic [31:0] mask);
    return state[31] ? ({state[30:0], 1'b0} ^ mask) : {state[30:0], 1'b0};
  endfunction

  wire [31:0] lfsr0_next = lfsr_step(lfsr0_q, TAP0);
  wire [31:0] lfsr1_next = lfsr_step(lfsr1_q, TAP1);
  wire [31:0] lfsr2_next = lfsr_step(lfsr2_q, TAP2);
  assign      candidate_new = lfsr0_next ^ lfsr1_next ^ lfsr2_next;

  wire rep_match = (candidate_new == candidate_q);

  // ─────────────────────────── CTRL self-clearing pulses ───────────────────
  wire soft_reset_pulse = wr_access && (paddr == OFF_CTRL) && pwdata[1];
  wire seed_load_pulse  = wr_access && (paddr == OFF_CTRL) && pwdata[2];

  // DATA read → FIFO pop
  assign fifo_pop  = rd_access && (paddr == OFF_DATA) && ~fifo_empty;
  // FIFO push: ENABLE && !full && health 정상
  assign fifo_push = ctrl_enable_q && ~fifo_full && ~health_fail_q;

  // ─────────────────────────── Sequential ───────────────────────────
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_enable_q <= 1'b0;
      // Default seeds: bit[31] set 이라 reset 직후 LFSR 이 즉시 활성 phase 진입.
      seed0_q       <= 32'h8000_0001;
      seed1_q       <= 32'hA5A5_A5A5;
      seed2_q       <= 32'hC3C3_C3C3;
      lfsr0_q       <= 32'h8000_0001;
      lfsr1_q       <= 32'hA5A5_A5A5;
      lfsr2_q       <= 32'hC3C3_C3C3;
      candidate_q   <= '0;
      rep_count_q   <= '0;
      health_fail_q <= 1'b0;
      fifo_count_q  <= '0;
      fifo_wr_ptr_q <= '0;
      fifo_rd_ptr_q <= '0;
      intr_en_q     <= '0;
      intr_status_q <= '0;
      data_ready_d  <= 1'b0;
      health_fail_d <= 1'b0;
      for (int i = 0; i < FIFO_DEPTH; i++) fifo_mem[i] <= '0;
    end else begin

      // ──── CTRL pulses 우선 처리 ────────────────────────────────────────
      if (soft_reset_pulse) begin
        lfsr0_q       <= seed0_q;
        lfsr1_q       <= seed1_q;
        lfsr2_q       <= seed2_q;
        candidate_q   <= '0;
        rep_count_q   <= '0;
        health_fail_q <= 1'b0;
        fifo_count_q  <= '0;
        fifo_wr_ptr_q <= '0;
        fifo_rd_ptr_q <= '0;
      end else if (seed_load_pulse) begin
        lfsr0_q     <= seed0_q;
        lfsr1_q     <= seed1_q;
        lfsr2_q     <= seed2_q;
        candidate_q <= '0;
        rep_count_q <= '0;
      end else if (ctrl_enable_q) begin
        // ──── 정상 운영: LFSR advance + health update ─────────────────
        lfsr0_q     <= lfsr0_next;
        lfsr1_q     <= lfsr1_next;
        lfsr2_q     <= lfsr2_next;
        candidate_q <= candidate_new;

        if (rep_match) begin
          if (rep_count_q == 4'd3)
            health_fail_q <= 1'b1;
          else
            rep_count_q <= rep_count_q + 4'd1;
        end else begin
          rep_count_q <= '0;
        end

        // FIFO push
        if (fifo_push) begin
          fifo_mem[fifo_wr_ptr_q] <= candidate_new;
          fifo_wr_ptr_q           <= fifo_wr_ptr_q + 1'b1;
          if (!fifo_pop)
            fifo_count_q <= fifo_count_q + 1'b1;
        end
      end

      // ──── DATA read → pop (push/pop simultaneous 시 count 불변) ─────
      if (fifo_pop) begin
        fifo_rd_ptr_q <= fifo_rd_ptr_q + 1'b1;
        if (!fifo_push)
          fifo_count_q <= fifo_count_q - 1'b1;
      end

      // ──── APB writes (단순 RW 레지스터) ────────────────────────────
      if (wr_access) begin
        unique case (paddr)
          OFF_CTRL:        ctrl_enable_q <= pwdata[0];
          OFF_SEED0:       seed0_q       <= pwdata;
          OFF_SEED1:       seed1_q       <= pwdata;
          OFF_SEED2:       seed2_q       <= pwdata;
          OFF_INTR_EN:     intr_en_q     <= pwdata[1:0];
          OFF_INTR_STATUS: intr_status_q <= intr_status_q & ~pwdata[1:0]; // W1C
          default: ;
        endcase
      end

      // ──── Interrupt status latch (rising edge of source) ────────────
      // 두 비트 모두 edge-trigger: source 가 high 상태로 유지되어도 SW 가
      // W1C 후 다시 set 되지 않는다 (다음 rising edge 까지). health_fail_q 는
      // soft_reset 으로만 clear 되므로, edge 가 단 한 번 잡힌다.
      data_ready_d  <= data_ready;
      health_fail_d <= health_fail_q;
      if (data_ready    & ~data_ready_d)  intr_status_q[0] <= 1'b1;
      if (health_fail_q & ~health_fail_d) intr_status_q[1] <= 1'b1;
    end
  end

  // ─────────────────────────── Read mux ───────────────────────────
  wire [31:0] data_word = fifo_empty ? 32'h0 : fifo_mem[fifo_rd_ptr_q];

  logic [31:0] rdata_c;
  always_comb begin
    rdata_c = 32'h0;
    unique case (paddr)
      OFF_CTRL:        rdata_c = {31'h0, ctrl_enable_q};
      OFF_STATUS:      rdata_c = {28'h0, health_fail_q, fifo_empty, fifo_full, data_ready};
      OFF_DATA:        rdata_c = data_word;
      OFF_FIFO_LEVEL:  rdata_c = {{(32 - FIFO_AW - 1){1'b0}}, fifo_count_q};
      OFF_HEALTH:      rdata_c = {16'h0, 4'h0, rep_count_q, 7'h0, health_fail_q};
      OFF_SEED0:       rdata_c = seed0_q;
      OFF_SEED1:       rdata_c = seed1_q;
      OFF_SEED2:       rdata_c = seed2_q;
      OFF_INTR_EN:     rdata_c = {30'h0, intr_en_q};
      OFF_INTR_STATUS: rdata_c = {30'h0, intr_status_q};
      OFF_IP_ID:       rdata_c = IP_ID_VALUE;
      OFF_IP_VERSION:  rdata_c = IP_VERSION_VALUE;
      default:         rdata_c = 32'h0;
    endcase
  end

  // ─────────────────────────── Decode error ───────────────────────────
  logic addr_valid;
  always_comb begin
    addr_valid = (paddr inside {OFF_CTRL, OFF_STATUS, OFF_DATA, OFF_FIFO_LEVEL,
                                OFF_HEALTH, OFF_SEED0, OFF_SEED1, OFF_SEED2,
                                OFF_INTR_EN, OFF_INTR_STATUS,
                                OFF_IP_ID, OFF_IP_VERSION});
  end

  logic wr_to_ro;
  always_comb begin
    wr_to_ro = wr_access && (paddr inside {OFF_STATUS, OFF_DATA, OFF_FIFO_LEVEL,
                                           OFF_HEALTH, OFF_IP_ID, OFF_IP_VERSION});
  end

  // ─────────────────────────── APB outputs ───────────────────────────
  assign prdata  = rd_access ? rdata_c : 32'h0;
  assign pready  = access_phase;
  assign pslverr = access_phase & (~addr_valid | wr_to_ro);

  // ─────────────────────────── Interrupt out ───────────────────────────
  assign irq_o = |(intr_status_q & intr_en_q);

endmodule

// ─────────────────────────────────────────────────────────────────────────────
// 프로젝트 공통 `apb_if` 에 연결하는 얇은 wrapper
// ─────────────────────────────────────────────────────────────────────────────
module trng_apbif (
  input  logic clk,
  input  logic rst_n,
  apb_if.slave s_apb,
  output logic irq_o
);
  trng u_core (
    .clk     (clk),
    .rst_n   (rst_n),
    .paddr   (s_apb.paddr[11:0]),
    .psel    (s_apb.psel),
    .penable (s_apb.penable),
    .pwrite  (s_apb.pwrite),
    .pwdata  (s_apb.pwdata),
    .prdata  (s_apb.prdata),
    .pready  (s_apb.pready),
    .pslverr (s_apb.pslverr),
    .irq_o   (irq_o)
  );
endmodule

`endif // TRNG_SV
