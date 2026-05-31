`timescale 1ns / 1ps

import axi_vip_pkg::*;
import axi_test_axi_vip_0_0_pkg::*;

module axi_tb;

    logic clk   = 0;
    logic rst_n = 0;
    logic uart_tx;

    always #8.62 clk = ~clk; // ~58 MHz

    // ── Output dir ──
    localparam string OUT_DIR = "/home/luki/Projekty/cpu/latest_run";

    // ── Flat AXI wires (matched to VIP's port set) ──
    // Read Address
    wire [35:0] axi_araddr;
    wire [ 7:0] axi_arlen;
    wire [ 2:0] axi_arsize;
    wire [ 1:0] axi_arburst;
    wire [ 0:0] axi_arlock;
    wire [ 3:0] axi_arcache;
    wire [ 2:0] axi_arprot;
    wire [ 3:0] axi_arqos;
    wire        axi_arvalid;
    wire        axi_arready;
    // Read Data
    wire [127:0] axi_rdata;
    wire [ 1:0] axi_rresp;
    wire        axi_rvalid;
    wire        axi_rlast;
    wire        axi_rready;
    // Write Address
    wire [35:0] axi_awaddr;
    wire [ 7:0] axi_awlen;
    wire [ 2:0] axi_awsize;
    wire [ 1:0] axi_awburst;
    wire [ 0:0] axi_awlock;
    wire [ 3:0] axi_awcache;
    wire [ 2:0] axi_awprot;
    wire [ 3:0] axi_awqos;
    wire        axi_awvalid;
    wire        axi_awready;
    // Write Data
    wire [127:0] axi_wdata;
    wire [ 15:0] axi_wstrb;
    wire        axi_wlast;
    wire        axi_wvalid;
    wire        axi_wready;
    // Write Response
    wire [ 1:0] axi_bresp;
    wire        axi_bvalid;
    wire        axi_bready;

    // ── DUT ──
    // Signals top_wrapper drives but VIP doesn't accept (no ID/user on VIP)
    wire [5:0] dummy_arid, dummy_awid;
    wire       dummy_aruser, dummy_awuser;

    top_wrapper dut (
        .clk             (clk),
        .rst_n           (rst_n),
        // AR
        .m_axi_araddr    (axi_araddr),
        .m_axi_arlen     (axi_arlen),
        .m_axi_arsize    (axi_arsize),
        .m_axi_arburst   (axi_arburst),
        .m_axi_arlock    (axi_arlock),
        .m_axi_arcache   (axi_arcache),
        .m_axi_arprot    (axi_arprot),
        .m_axi_arvalid   (axi_arvalid),
        .m_axi_arready   (axi_arready),
        .m_axi_arid      (dummy_arid),
        .m_axi_arqos     (axi_arqos),
        .m_axi_aruser    (dummy_aruser),
        // R
        .m_axi_rdata     (axi_rdata),
        .m_axi_rresp     (axi_rresp),
        .m_axi_rvalid    (axi_rvalid),
        .m_axi_rlast     (axi_rlast),
        .m_axi_rready    (axi_rready),
        .m_axi_rid       (6'b0),
        // AW
        .m_axi_awaddr    (axi_awaddr),
        .m_axi_awlen     (axi_awlen),
        .m_axi_awsize    (axi_awsize),
        .m_axi_awburst   (axi_awburst),
        .m_axi_awlock    (axi_awlock),
        .m_axi_awcache   (axi_awcache),
        .m_axi_awprot    (axi_awprot),
        .m_axi_awvalid   (axi_awvalid),
        .m_axi_awready   (axi_awready),
        .m_axi_awid      (dummy_awid),
        .m_axi_awqos     (axi_awqos),
        .m_axi_awuser    (dummy_awuser),
        // W
        .m_axi_wdata     (axi_wdata),
        .m_axi_wstrb     (axi_wstrb),
        .m_axi_wlast     (axi_wlast),
        .m_axi_wvalid    (axi_wvalid),
        .m_axi_wready    (axi_wready),
        // B
        .m_axi_bresp     (axi_bresp),
        .m_axi_bvalid    (axi_bvalid),
        .m_axi_bready    (axi_bready),
        .m_axi_bid       (6'b0)
    );

    // ── AXI VIP (slave mode) ──
    axi_test_wrapper vip_inst (
        .aclk_0             (clk),
        .aresetn_0          (rst_n),
        // AR
        .S_AXI_0_araddr     (axi_araddr),
        .S_AXI_0_arlen      (axi_arlen),
        .S_AXI_0_arsize     (axi_arsize),
        .S_AXI_0_arburst    (axi_arburst),
        .S_AXI_0_arlock     (axi_arlock),
        .S_AXI_0_arcache    (axi_arcache),
        .S_AXI_0_arprot     (axi_arprot),
        .S_AXI_0_arqos      (axi_arqos),
        .S_AXI_0_arregion   (4'b0),
        .S_AXI_0_arvalid    (axi_arvalid),
        .S_AXI_0_arready    (axi_arready),
        // R
        .S_AXI_0_rdata      (axi_rdata),
        .S_AXI_0_rresp      (axi_rresp),
        .S_AXI_0_rvalid     (axi_rvalid),
        .S_AXI_0_rlast      (axi_rlast),
        .S_AXI_0_rready     (axi_rready),
        // AW
        .S_AXI_0_awaddr     (axi_awaddr),
        .S_AXI_0_awlen      (axi_awlen),
        .S_AXI_0_awsize     (axi_awsize),
        .S_AXI_0_awburst    (axi_awburst),
        .S_AXI_0_awlock     (axi_awlock),
        .S_AXI_0_awcache    (axi_awcache),
        .S_AXI_0_awprot     (axi_awprot),
        .S_AXI_0_awqos      (axi_awqos),
        .S_AXI_0_awregion   (4'b0),
        .S_AXI_0_awvalid    (axi_awvalid),
        .S_AXI_0_awready    (axi_awready),
        // W
        .S_AXI_0_wdata      (axi_wdata),
        .S_AXI_0_wstrb      (axi_wstrb),
        .S_AXI_0_wlast      (axi_wlast),
        .S_AXI_0_wvalid     (axi_wvalid),
        .S_AXI_0_wready     (axi_wready),
        // B
        .S_AXI_0_bresp      (axi_bresp),
        .S_AXI_0_bvalid     (axi_bvalid),
        .S_AXI_0_bready     (axi_bready)
    );


    localparam logic [31:0] TOHOST_ADDR = 32'h8001_2200;
    localparam logic [31:0] SIG_BEGIN = 32'h8000_b250;
    localparam logic [31:0] SIG_END   = 32'h8000_b840;
    wire [31:0] cpu_addr = dut.top_inst.axi_m.addr_d;
    wire [31:0] cpu_wdata = dut.top_inst.axi_m.wr_data;
    wire        cpu_we    = dut.top_inst.axi_m.wr_en;
    wire [3:0]   cpu_be = dut.top_inst.axi_m.byte_en;
    logic [7:0] shadow [logic [31:0]];

    logic [31:0] exec_instr;
    logic [31:0] exec_pc;

    logic [31:0] mem_instr;
    logic [31:0] mem_pc;

    assign exec_instr = dut.top_inst.cpu.exec_stage.in_ctrl_signals.instr;
    assign exec_pc = dut.top_inst.cpu.exec_stage.in_ctrl_signals.pc;

    assign mem_instr = dut.top_inst.cpu.mem_stage.in_ctrl_signals.instr;
    assign mem_pc = dut.top_inst.cpu.mem_stage.in_ctrl_signals.pc;

    // ── VIP slave memory agent ──
    axi_test_axi_vip_0_0_slv_mem_t slv_agent;

    task automatic load_hex(input string filename, input logic [35:0] base_addr);
        int fd, rc;
        logic [31:0] word;
        logic [31:0] rom [$];   // queue — grows automatically
        logic [127:0] chunk;

        fd = $fopen(filename, "r");
        if (!fd) $fatal(1, "[TB] Cannot open %s", filename);

        forever begin
            rc = $fscanf(fd, "%h", word);
            if (rc != 1) break;      // EOF or parse error — done
            rom.push_back(word);
        end
        $fclose(fd);
        $display("[TB] Loaded %0d words from %s", rom.size(), filename);

        // Pack 4 words per 128-bit line and backdoor-write
        for (int i = 0; i < rom.size(); i += 4) begin
            chunk = '0;
            for (int b = 0; b < 4 && (i+b) < rom.size(); b++)
                chunk[b*32 +: 32] = rom[i+b];
            slv_agent.mem_model.backdoor_memory_write(
                base_addr + i*4, chunk, 16'hFFFF);
        end
    endtask

    task automatic dump_signature(input string filename);
      int fd = $fopen(filename, "w");
      if (!fd) $fatal(1, "cannot open %s", filename);
      for (logic [31:0] a = SIG_BEGIN; a < SIG_END; a += 4) begin
        logic [31:0] w;
        for (int b = 0; b < 4; b++)
          w[b*8 +: 8] = shadow.exists(a + b) ? shadow[a + b] : 8'h00;
        $fwrite(fd, "%08x\n", w);
      end
      $fclose(fd);
      $display("[TB] signature dumped to %s (%0d words)",
               filename, (SIG_END - SIG_BEGIN) / 4);
    endtask

    // ── Debug: PC trace ──
    int          trace_fd;
    logic [31:0] last_unique_pc;
    int          inst_cnt;
    int          hb_cnt;

    initial begin
        void'($system($sformatf("mkdir -p %s", OUT_DIR)));
        trace_fd = $fopen({OUT_DIR, "/trace.log"}, "w");
        if (!trace_fd) $fatal(1, "[TB] cannot open %s/trace.log", OUT_DIR);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_unique_pc <= '0;
            inst_cnt       <= 0;
            hb_cnt         <= 0;
        end else begin
            // Per-instruction trace
            if (mem_pc != last_unique_pc && mem_pc != 0) begin
                $fwrite(trace_fd, "%0t  PC=%08h  INSTR=%08h\n",
                        $time, mem_pc, mem_instr);
                last_unique_pc <= mem_pc;
                inst_cnt       <= inst_cnt + 1;
            end

            // Heartbeat — also flushes the trace so it's tail-able
            hb_cnt <= hb_cnt + 1;
            if (hb_cnt == 50_000) begin
                // $display("[%0t] hb: mem_pc=%08h instr=%08h retired=%0d",
                //          $time, mem_pc, mem_instr, inst_cnt);
                $fflush(trace_fd);
                hb_cnt <= 0;
            end
        end
    end

    initial begin
        slv_agent = new("slv_agent", vip_inst.axi_test_i.axi_vip_0.inst.IF);
        slv_agent.start_slave();

        // Spoof uart ready to write
        slv_agent.mem_model.backdoor_memory_write_4byte(32'h10000014, 32'h00000060, 4'hF);

        load_hex("/home/luki/Projekty/cpu/code/build/program.hex", 36'h8_4000_0000);
        // load_hex("/home/luki/Projekty/cpu/code/zephyr.hex", 36'h8_4000_0000);
        // load_hex("/home/luki/Projekty/cpu/code/coremark/build/coremark.hex", 36'h8_4000_0000);
        // load_hex("/home/luki/Projekty/cpu/logs/arch/I-add-00/I-add-00.hex", 36'h8_4000_0000);

        // Reset
        rst_n = 0;
        #500;
        rst_n = 1;
        $display("[TB] Reset released at %0t", $time);

        // 4 words x 4 bytes x ~87us/byte = ~1.4ms
        #1_000_000;

        $display("[TB] Simulation finished at %0t", $time);
        $finish;
    end


    // ── Tohost handler ──
    logic finish_pending;
    initial finish_pending = 1'b0;

    always_ff @(posedge clk) begin
      if (cpu_we && cpu_addr == TOHOST_ADDR) begin
        $display("[%0t] tohost <= 0x%08h (PC=0x%08h)", $time, cpu_wdata, mem_pc);
        case (cpu_wdata)
          32'd1: begin
            $display("==== TEST PASSED ====\n");
            dump_signature({OUT_DIR, "/DUT.signature"});
            finish_pending <= 1'b1;
          end
          32'd3: begin
            $display("==== TEST FAILED ====\n");
            finish_pending <= 1'b1;
          end
          32'd0: ;
          default: $display("[TB] tohost unexpected: 0x%08h", cpu_wdata);
        endcase
      end
    end

    // Drain UART output before $finish
    initial begin
      wait (finish_pending);
      #10ms;
      $finish;
    end

    always @(posedge clk) begin
      if (cpu_we && cpu_addr != TOHOST_ADDR) begin
        for (int b = 0; b < 4; b++)
          if (cpu_be[b])
            shadow[(cpu_addr & ~32'h3) + b] = cpu_wdata[b*8 +: 8];
      end
    end

    // ── Catch-all flush/close on any sim end ──
    final begin
        if (trace_fd) begin
            $fflush(trace_fd);
            $fclose(trace_fd);
        end
        $display("[TB] final: %0d instructions retired, last_pc=0x%08h",
                 inst_cnt, last_unique_pc);

        $display("Backdoor read @ 0x10000000 = 0x%08X", slv_agent.mem_model.backdoor_memory_read(32'h1000_0000));
        $display("Backdoor read @ 0x10000010 = 0x%08X", slv_agent.mem_model.backdoor_memory_read(32'h1000_0010));
    end

    //── Monitor AXI reads ──
    // always @(posedge clk) begin
    //     if (axi_arvalid && axi_arready)
    //         $display("[AXI] AR: addr=0x%08h @ %0t", axi_araddr, $time);
    //     if (axi_rvalid && axi_rready)
    //         $display("[AXI]  R: data=0x%032h resp=%0d @ %0t", axi_rdata, axi_rresp, $time);
    //     if (axi_awvalid && axi_awready)
    //             $display("[AXI] AW: addr=0x%09h len=%0d @ %0t",
    //                         axi_awaddr, axi_awlen, $time);
    //     if (axi_wvalid && axi_wready)
    //         $display("[AXI]  W: data=0x%032h strb=%0h last=%0b @ %0t",
    //                     axi_wdata, axi_wstrb, axi_wlast, $time);
    //     if (axi_bvalid && axi_bready)
    //         $display("[AXI]  B: resp=%0d @ %0t", axi_bresp, $time);
    // end


    logic [35:0] last_awaddr;

    always @(posedge clk) begin
        if (axi_awvalid && axi_awready)
            last_awaddr <= axi_awaddr;
    end

    always @(posedge clk) begin
        if (axi_wvalid && axi_wready && last_awaddr == 36'h0_1000_0000) begin
            automatic logic [7:0] ch;
            casez (axi_wstrb)
                16'b????_????_????_???1: ch = axi_wdata[7:0];
                16'b????_????_????_??10: ch = axi_wdata[15:8];
                16'b????_????_????_?100: ch = axi_wdata[23:16];
                16'b????_????_????_1000: ch = axi_wdata[31:24];
                default:                 ch = axi_wdata[7:0];
            endcase
            if (ch >= 8'h20 && ch <= 8'h7E || ch == 8'h0A || ch == 8'h0D)
                $write("%c", ch);
        end
    end

    // MMIO only (addr < 0x8000_0000)
    // always @(posedge clk) begin
    //     if (axi_arvalid && axi_arready && axi_araddr < 36'h8_0000_0000)
    //         $display("[MMIO] AR: addr=0x%08h @ %0t", axi_araddr, $time);
    //     if (axi_rvalid && axi_rready && /* latch addr */ 1) // see note
    //         ; // harder to filter R — see note below
    //     if (axi_awvalid && axi_awready && axi_awaddr < 36'h8_0000_0000)
    //         $display("[MMIO] AW: addr=0x%08h len=%0d @ %0t", axi_awaddr, axi_awlen, $time);
    //     if (axi_wvalid && axi_wready && axi_awaddr < 36'h8_0000_0000)
    //         $display("[MMIO]  W: data=0x%032h strb=%04h @ %0t", axi_wdata, axi_wstrb, $time);
    //     if (axi_bvalid && axi_bready)
    //         ; // B has no addr, skip or always print
    // end



endmodule
