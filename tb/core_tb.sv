module core_tb;
  logic clk;
  logic rst_n;
  //TODO: fix this mess
  // Memory interface
  logic [31:0] mem_addr1, mem_addr2;
  logic        mem_wr_en;
  logic [31:0] mem_wr_data, mem_wr_addr;
  logic [31:0] mem_rd_data1, mem_rd_data2;
  logic [ 3:0] mem_byte_en;
  
  // Simple instruction memory
  logic [31:0] imem [0:255];
  
  // Simple data memory
  logic [31:0] dmem [0:255];
  
  // Memory reads
  assign mem_rd_data1 = imem[mem_addr1[31:2]];
  assign mem_rd_data2 = dmem[mem_addr2[31:2]];
  
  // Memory writes
  always_ff @(posedge clk) begin
    if (mem_wr_en) begin
      case (mem_byte_en)
        4'b0001: dmem[mem_wr_addr[31:2]][7:0]   <= mem_wr_data[7:0];
        4'b0011: dmem[mem_wr_addr[31:2]][15:0]  <= mem_wr_data[15:0];
        4'b1111: dmem[mem_wr_addr[31:2]]        <= mem_wr_data;
        default: dmem[mem_wr_addr[31:2]]        <= mem_wr_data;
      endcase
    end
  end
  
  // DUT
  core dut (.*);
  
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Test program
  initial begin
    // Initialize memories
    for (int i = 0; i < 256; i++) begin
      imem[i] = 32'h00000013; // NOP (ADDI x0, x0, 0)
      dmem[i] = 32'h00000000;
    end
    
    // Test program
    // 0: ADDI x1, x0, 42      # x1 = 42
    imem[0] = 32'b000000101010_00000_000_00001_0010011;
    
    // 4: ADDI x2, x0, 13      # x2 = 13
    imem[1] = 32'b000000001101_00000_000_00010_0010011;
    
    // 8: ADD x3, x1, x2       # x3 = 42 + 13 = 55
    imem[2] = 32'b0000000_00010_00001_000_00011_0110011;
    
    // 12: SUB x4, x1, x2      # x4 = 42 - 13 = 29
    imem[3] = 32'b0100000_00010_00001_000_00100_0110011;
    
    // 16: SW x3, 0(x0)        # Store x3 (55) to dmem[0]
    imem[4] = 32'b0000000_00011_00000_010_00000_0100011;
    
    // 20: LW x5, 0(x0)        # Load from dmem[0] into x5
    imem[5] = 32'b000000000000_00000_010_00101_0000011;
    
    // 24: ADDI x6, x0, 100    # x6 = 100 (for base address)
    imem[6] = 32'b000001100100_00000_000_00110_0010011;
    
    // 28: SW x4, 0(x6)        # Store x4 (29) to dmem[25] (100/4)
    imem[7] = 32'b0000000_00100_00110_010_00000_0100011;
    
    // 32: LW x7, 0(x6)        # Load from dmem[25] into x7
    imem[8] = 32'b000000000000_00110_010_00111_0000011;
    
    // 36: JAL x8, 8           # Jump forward 8 bytes, save PC+4 to x8
    imem[9] = 32'b0_0000000100_0_00000000_01000_1101111;
    
    // 40: ADDI x9, x0, 99     # Should be skipped
    imem[10] = 32'b000001100011_00000_000_01001_0010011;
    
    // 44: ADDI x10, x0, 77    # x10 = 77 (lands here after JAL)
    imem[11] = 32'b000001001101_00000_000_01010_0010011;
    
    // 48: BEQ x1, x1, 8       # Branch taken (x1 == x1), skip next instr
    imem[12] = 32'b0_000001_00001_00001_000_0100_0_1100011;
    
    // 52: ADDI x11, x0, 88    # Should be skipped
    imem[13] = 32'b000001011000_00000_000_01011_0010011;
    
    // 56: ADDI x12, x0, 66    # x12 = 66
    imem[14] = 32'b000001000010_00000_000_01100_0010011;
    
    // 60: BNE x1, x2, 8       # Branch taken (x1 != x2)
    imem[15] = 32'b0_000001_00010_00001_001_0100_0_1100011;
    
    // 64: ADDI x13, x0, 55    # Should be skipped
    imem[16] = 32'b000000110111_00000_000_01101_0010011;
    
    // 68: LUI x14, 0x12345    # x14 = 0x12345000
    imem[17] = 32'b00010010001101000101_01110_0110111;
    
    // 72: AUIPC x15, 0x100    # x15 = PC + 0x100000 = 72 + 0x100000
    imem[18] = 32'b00000000000100000000_01111_0010111;
    
    // Reset
    rst_n = 0;
    #20;
    rst_n = 1;
    
    // Run for enough cycles
    #400;
    
    // Check results
    $display("\n=== Test Results ===");
    $display("x1  = %d (expected 42)", dut.regfile_inst.registers[1]);
    $display("x2  = %d (expected 13)", dut.regfile_inst.registers[2]);
    $display("x3  = %d (expected 55)", dut.regfile_inst.registers[3]);
    $display("x4  = %d (expected 29)", dut.regfile_inst.registers[4]);
    $display("x5  = %d (expected 55, from mem load)", dut.regfile_inst.registers[5]);
    $display("x6  = %d (expected 100)", dut.regfile_inst.registers[6]);
    $display("x7  = %d (expected 29, from mem load)", dut.regfile_inst.registers[7]);
    $display("x8  = %d (expected 40, return addr from JAL)", dut.regfile_inst.registers[8]);
    $display("x9  = %d (expected 0, skipped by JAL)", dut.regfile_inst.registers[9]);
    $display("x10 = %d (expected 77)", dut.regfile_inst.registers[10]);
    $display("x11 = %d (expected 0, skipped by BEQ)", dut.regfile_inst.registers[11]);
    $display("x12 = %d (expected 66)", dut.regfile_inst.registers[12]);
    $display("x13 = %d (expected 0, skipped by BNE)", dut.regfile_inst.registers[13]);
    $display("x14 = 0x%h (expected 0x12345000)", dut.regfile_inst.registers[14]);
    $display("x15 = 0x%h (expected 0x100048)", dut.regfile_inst.registers[15]);
    $display("\nMemory[0] = %d (expected 55)", dmem[0]);
    $display("Memory[25] = %d (expected 29)", dmem[25]);
    
    $finish;
  end
  
  // Waveform dump (for viewing in GTKWave)
  initial begin
    $dumpfile("logs/core_tb.vcd");
    $dumpvars(0, core_tb);
  end
  
endmodule