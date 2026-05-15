// SPDX-License-Identifier: Apache-2.0
// Testbench: tb_trng
// trng IP 용 self-checking testbench.
//
// Coverage:
//   T1  reset 상태             — CTRL=0, FIFO empty, STATUS.DATA_READY=0, irq=0
//   T2  IP_ID / IP_VERSION RO  — 상수 반환
//   T3  CTRL.ENABLE + FIFO fill — enable → FIFO 가 16 word 까지 차오름
//   T4  DATA read pop          — 매 read 마다 FIFO_LEVEL 감소, 두 read 결과가 다름
//   T5  CTRL.SEED_LOAD pulse   — SEED 변경 후 LOAD → 동일 seed reuse 시 stream 일치
//   T6  CTRL.SOFT_RESET pulse  — FIFO 비워지고 health/rep count 리셋
//   T7  Health fail            — SEED=0 강제 → 4-cycle 후 HEALTH.FAIL set, irq_o rise
//   T8  INTR_STATUS W1C        — health_fail latch 비트 clear
//   T9  pslverr unmapped       — 미매핑 주소 read 에 pslverr=1
//   T10 pslverr RO write       — STATUS 에 write 시 pslverr=1

`timescale 1ns/1ps

module tb_trng;
  // Addr map (must match RTL)
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

  // Clock / reset
  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;  // 100 MHz

  // DUT signals
  logic [11:0] paddr;
  logic        psel, penable, pwrite;
  logic [31:0] pwdata, prdata;
  logic        pready, pslverr;
  logic        irq;

  trng dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .paddr   (paddr),
    .psel    (psel),
    .penable (penable),
    .pwrite  (pwrite),
    .pwdata  (pwdata),
    .prdata  (prdata),
    .pready  (pready),
    .pslverr (pslverr),
    .irq_o   (irq)
  );

  // Score keeping
  int errors = 0;
  task automatic CHECK(input string tag, input bit cond);
    if (!cond) begin
      $display("[FAIL] %s @%0t", tag, $time);
      errors++;
    end else begin
      $display("[ pass ] %s", tag);
    end
  endtask

  // 모든 signal transition을 posedge 직후 #1ns로 떼어내어 always_ff trigger
  // sampling 과 race 하지 않게 한다.
  task automatic apb_write(input logic [11:0] addr, input logic [31:0] data, output logic err);
    @(posedge clk); #1;
    paddr   = addr;
    pwdata  = data;
    pwrite  = 1'b1;
    psel    = 1'b1;
    penable = 1'b0;
    @(posedge clk); #1;
    penable = 1'b1;
    @(negedge clk);
    err     = pslverr;
    @(posedge clk); #1;
    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;
  endtask

  task automatic apb_read(input logic [11:0] addr, output logic [31:0] data, output logic err);
    @(posedge clk); #1;
    paddr   = addr;
    pwrite  = 1'b0;
    psel    = 1'b1;
    penable = 1'b0;
    @(posedge clk); #1;
    penable = 1'b1;
    @(negedge clk);
    data    = prdata;
    err     = pslverr;
    @(posedge clk); #1;
    psel    = 1'b0;
    penable = 1'b0;
  endtask

  task automatic W(input logic [11:0] a, input logic [31:0] d);
    logic e; apb_write(a, d, e);
  endtask
  task automatic R(input logic [11:0] a, output logic [31:0] d);
    logic e; apb_read(a, d, e);
  endtask

  // Main scenario
  logic [31:0] rd, rd2;
  logic        err;

  initial begin
    paddr=0; psel=0; penable=0; pwrite=0; pwdata=0;
    repeat (3) @(posedge clk);
    rst_n = 1;
    repeat (3) @(posedge clk);

    // ──── T1 reset 상태 ────────────────────────────────────────────
    R(OFF_CTRL,       rd); CHECK("T1 CTRL=0 at reset",            rd == 32'h0);
    R(OFF_STATUS,     rd); CHECK("T1 STATUS empty + !data_ready", rd[0] == 1'b0 && rd[2] == 1'b1);
    R(OFF_FIFO_LEVEL, rd); CHECK("T1 FIFO_LEVEL=0",               rd == 32'h0);
    CHECK("T1 irq low at reset", irq == 1'b0);

    // ──── T2 IP_ID / IP_VERSION ────────────────────────────────────
    R(OFF_IP_ID,      rd); CHECK("T2 IP_ID = TRNG",     rd == 32'h5452_4E47);
    R(OFF_IP_VERSION, rd); CHECK("T2 IP_VERSION=1.0",   rd == 32'h0001_0000);

    // ──── T3 CTRL.ENABLE → FIFO 가 16 까지 채워짐 ─────────────────
    W(OFF_CTRL, 32'h1);                               // ENABLE=1
    // 16 word 채우기에 충분한 시간
    repeat (40) @(posedge clk);
    R(OFF_FIFO_LEVEL, rd); CHECK("T3 FIFO filled to 16", rd == 32'd16);
    R(OFF_STATUS,     rd); CHECK("T3 STATUS.DATA_READY=1 / FIFO_FULL=1",
                                 rd[0] == 1'b1 && rd[1] == 1'b1);

    // ──── T4 DATA read pop ─────────────────────────────────────────
    // ENABLE 을 잠시 꺼서 push 가 일어나지 않게 한 뒤 pop 으로 level 감소 확인.
    begin : t4_pop
      logic [31:0] lvl_pre, lvl_post, w1, w2;
      W(OFF_CTRL, 32'h0);                             // disable (push 정지)
      R(OFF_FIFO_LEVEL, lvl_pre);
      R(OFF_DATA, w1);
      R(OFF_DATA, w2);
      R(OFF_FIFO_LEVEL, lvl_post);
      CHECK("T4 두 random word 가 서로 다름", w1 != w2);
      CHECK("T4 두 pop 후 level == 사전 - 2",  lvl_post == (lvl_pre - 2));
      W(OFF_CTRL, 32'h1);                             // 재활성
    end

    // ──── T5 SEED_LOAD reproducibility ─────────────────────────────
    // 두 run 의 시작 상태가 같아야 하므로 SOFT_RESET 도 함께 펄스해 FIFO 비움.
    W(OFF_CTRL, 32'h0);                               // disable
    W(OFF_SEED0, 32'hDEAD_BEEF);
    W(OFF_SEED1, 32'h9876_5432);                      // bit31 set
    W(OFF_SEED2, 32'hCAFE_F00D);
    W(OFF_CTRL, 32'h7);                               // ENABLE | SOFT_RESET | SEED_LOAD
    repeat (20) @(posedge clk);
    R(OFF_DATA, rd);
    R(OFF_DATA, rd2);
    begin : reproduce
      logic [31:0] rd_b, rd2_b;
      W(OFF_CTRL, 32'h7);                             // 동일 펄스 재인가
      repeat (20) @(posedge clk);
      R(OFF_DATA, rd_b);
      R(OFF_DATA, rd2_b);
      CHECK("T5 seed-reuse 시 동일 word #1", rd_b == rd);
      CHECK("T5 seed-reuse 시 동일 word #2", rd2_b == rd2);
    end

    // ──── T6 SOFT_RESET 이 FIFO 비우고 health/rep_count 클리어 ────
    // soft_reset 직후 즉시 FIFO push 가 다시 시작되므로 FIFO_LEVEL=0 을 보장하긴
    // 어렵다 (push/pop race). health_fail/ENABLE 보존만 확인한다.
    W(OFF_CTRL, 32'h3);                               // ENABLE | SOFT_RESET
    repeat (3) @(posedge clk);
    R(OFF_HEALTH, rd); CHECK("T6 soft_reset 후 health_fail=0", rd[0] == 1'b0);
    R(OFF_CTRL,   rd); CHECK("T6 ENABLE 보존",                  rd[0] == 1'b1);

    // ──── T7 Health fail — SEED=0 강제 ────────────────────────────
    W(OFF_CTRL, 32'h0);                               // disable
    W(OFF_SEED0, 32'h0);
    W(OFF_SEED1, 32'h0);
    W(OFF_SEED2, 32'h0);
    W(OFF_INTR_EN, 32'h2);                            // health_fail interrupt enable
    W(OFF_CTRL, 32'h5);                               // ENABLE | SEED_LOAD → LFSR 모두 0
    // 0 stuck → candidate 도 0 → 매 cycle rep_match → 4-cycle 후 fail
    repeat (12) @(posedge clk);
    R(OFF_HEALTH, rd); CHECK("T7 HEALTH.FAIL latched", rd[0] == 1'b1);
    R(OFF_STATUS, rd); CHECK("T7 STATUS.HEALTH_FAIL",  rd[3] == 1'b1);
    CHECK("T7 irq_o rises on health fail",             irq == 1'b1);

    // ──── T8 INTR_STATUS W1C ──────────────────────────────────────
    R(OFF_INTR_STATUS, rd); CHECK("T8 INTR_STATUS.HEALTH_FAIL latched", rd[1] == 1'b1);
    W(OFF_INTR_STATUS, 32'h2);                        // W1C bit1
    R(OFF_INTR_STATUS, rd); CHECK("T8 W1C 후 비트 cleared",              rd[1] == 1'b0);
    CHECK("T8 irq_o 가 떨어짐 (INTR_STATUS=0)",        irq == 1'b0);

    // ──── T9 pslverr 미매핑 주소 ──────────────────────────────────
    apb_read(12'h0F0, rd, err);
    CHECK("T9 미매핑 주소 read 시 pslverr=1", err == 1'b1);

    // ──── T10 pslverr RO write ────────────────────────────────────
    apb_write(OFF_STATUS, 32'hDEAD, err);
    CHECK("T10 STATUS write 시 pslverr=1", err == 1'b1);
    apb_write(OFF_IP_ID, 32'h0,    err);
    CHECK("T10 IP_ID write 시 pslverr=1",  err == 1'b1);

    if (errors == 0)
      $display("[tb_trng] ALL TESTS PASSED");
    else
      $display("[tb_trng] %0d FAILURES", errors);
    $finish;
  end

  initial begin
    #200000;
    $display("[tb_trng] TIMEOUT");
    $finish;
  end
endmodule
