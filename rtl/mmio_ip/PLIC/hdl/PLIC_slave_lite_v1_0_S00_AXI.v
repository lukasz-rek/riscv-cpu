`timescale 1 ns / 1 ps

	module PLIC_slave_lite_v1_0_S00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 26
	)
	(
		// Users to add ports here
		output wire meip,
		output wire seip,
		input wire uart_isr,
		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid.
		input wire  S_AXI_AWVALID,
		// Write address ready.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave)
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes.
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid.
		input wire  S_AXI_WVALID,
		// Write ready.
		output wire  S_AXI_WREADY,
		// Write response.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid.
		output wire  S_AXI_BVALID,
		// Response ready.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid.
		input wire  S_AXI_ARVALID,
		// Read address ready.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid.
		output wire  S_AXI_RVALID,
		// Read ready.
		input wire  S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	//------------------------------------------------
	//-- PLIC register storage (single source = UART = source ID 1)
	//------------------------------------------------
	reg [C_S_AXI_DATA_WIDTH-1:0]	isr_source_1_prio;        // priority for source 1 (UART)
	reg [C_S_AXI_DATA_WIDTH-1:0]	isr_pending_bits;          // pending[31:0], bit1 = UART
	reg [C_S_AXI_DATA_WIDTH-1:0]	isr_enable_context_0;      // enable[31:0], ctx0 (M / MEIP)
	reg [C_S_AXI_DATA_WIDTH-1:0]	isr_enable_context_1;      // enable[31:0], ctx1 (S / SEIP)
	reg [C_S_AXI_DATA_WIDTH-1:0]	isr_thres_context_0;       // priority threshold, ctx0 (M)
	reg [C_S_AXI_DATA_WIDTH-1:0]	isr_thres_context_1;       // priority threshold, ctx1 (S)
	reg [C_S_AXI_DATA_WIDTH-1:0]	isr_claim_compl_context_0; // claim/complete, ctx0 (M)
	reg [C_S_AXI_DATA_WIDTH-1:0]	isr_claim_compl_context_1; // claim/complete, ctx1 (S)

	integer	 byte_index;

	localparam [C_S_AXI_ADDR_WIDTH-1:0] ISR_SOURCE_1_PRIO_ADDR         = 26'h000004; // UART priority
	localparam [C_S_AXI_ADDR_WIDTH-1:0] ISR_PENDING_BITS_ADDR          = 26'h001000; // pending[31:0], bit1 = UART
	localparam [C_S_AXI_ADDR_WIDTH-1:0] ISR_ENABLE_CONTEXT_0_ADDR      = 26'h002000; // enable, ctx0 (M/MEIP)
	localparam [C_S_AXI_ADDR_WIDTH-1:0] ISR_ENABLE_CONTEXT_1_ADDR      = 26'h002080; // enable, ctx1 (S/SEIP)
	localparam [C_S_AXI_ADDR_WIDTH-1:0] ISR_THRES_CONTEXT_0_ADDR       = 26'h200000; // threshold, ctx0 (M)
	localparam [C_S_AXI_ADDR_WIDTH-1:0] ISR_CLAIM_COMPL_CONTEXT_0_ADDR = 26'h200004; // claim/complete, ctx0 (M)
	localparam [C_S_AXI_ADDR_WIDTH-1:0] ISR_THRES_CONTEXT_1_ADDR       = 26'h201000; // threshold, ctx1 (S)
	localparam [C_S_AXI_ADDR_WIDTH-1:0] ISR_CLAIM_COMPL_CONTEXT_1_ADDR = 26'h201004; // claim/complete, ctx1 (S)

	// FIX: continuously-evaluated "does this context currently see source 1 as
	// pending, enabled, and above its threshold" - used both to drive
	// meip/seip/claim every cycle (so they can deassert again) and to gate
	// the claim side-effect below.
	wire ctx0_irq = isr_pending_bits[1] && isr_enable_context_0[1] && (isr_source_1_prio > isr_thres_context_0);
	wire ctx1_irq = isr_pending_bits[1] && isr_enable_context_1[1] && (isr_source_1_prio > isr_thres_context_1);

	// I/O Connections assignments
	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;

	 //state machine varibles
	 reg [1:0] state_write;
	 reg [1:0] state_read;
	 //State machine local parameters
	 localparam Idle = 2'b00,Raddr = 2'b10,Rdata = 2'b11 ,Waddr = 2'b10,Wdata = 2'b11;

	// Implement Write state machine
	// Outstanding write transactions are not supported by the slave i.e., master should assert bready to receive response on or before it starts sending the new transaction
	always @(posedge S_AXI_ACLK)
	  begin
	     if (S_AXI_ARESETN == 1'b0)
	       begin
	         axi_awready <= 0;
	         axi_wready <= 0;
	         axi_bvalid <= 0;
	         axi_bresp <= 0;
	         axi_awaddr <= 0;
	         state_write <= Idle;
	       end
	     else
	       begin
	         case(state_write)
	           Idle:
	             begin
	               if(S_AXI_ARESETN == 1'b1)
	                 begin
	                   axi_awready <= 1'b1;
	                   axi_wready <= 1'b1;
	                   state_write <= Waddr;
	                 end
	               else state_write <= state_write;
	             end
	           Waddr:        //At this state, slave is ready to receive address along with corresponding control signals and first data packet. Response valid is also handled at this state
	             begin
	               if (S_AXI_AWVALID && S_AXI_AWREADY)
	                  begin
	                    axi_awaddr <= S_AXI_AWADDR;
	                    if(S_AXI_WVALID)
	                      begin
	                        axi_awready <= 1'b1;
	                        state_write <= Waddr;
	                        axi_bvalid <= 1'b1;
	                      end
	                    else
	                      begin
	                        axi_awready <= 1'b0;
	                        state_write <= Wdata;
	                        if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
	                      end
	                  end
	               else
	                  begin
	                    state_write <= state_write;
	                    if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
	                   end
	             end
	          Wdata:        //At this state, slave is ready to receive the data packets until the number of transfers is equal to burst length
	             begin
	               if (S_AXI_WVALID)
	                 begin
	                   state_write <= Waddr;
	                   axi_bvalid <= 1'b1;
	                   axi_awready <= 1'b1;
	                 end
	                else
	                 begin
	                   state_write <= state_write;
	                   if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
	                 end
	             end
	          endcase
	        end
	      end

	// Implement memory mapped register select and write logic generation
	// isr_pending_bits, isr_claim_compl_context_0/1, meip_q and seip_q are
	// NOT reset here - they're owned (incl. reset) by the gateway/output
	// block below, to avoid two always-blocks driving the same bits.
	reg meip_q;
	reg seip_q;
	assign meip = meip_q;
	assign seip = seip_q;
	reg uart_claimed;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
            isr_source_1_prio <= 32'b0;
			isr_enable_context_0 <= 32'b0;
			isr_enable_context_1 <= 32'b0;
			isr_thres_context_0 <= 32'b0;
			isr_thres_context_1 <= 32'b0;
			uart_claimed <= 0;
	    end
	  else begin
	    if (S_AXI_WVALID)
	      begin
	        case ( (S_AXI_AWVALID) ? S_AXI_AWADDR : axi_awaddr )
	          ISR_SOURCE_1_PRIO_ADDR:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                isr_source_1_prio[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	          ISR_ENABLE_CONTEXT_0_ADDR:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                isr_enable_context_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	          ISR_ENABLE_CONTEXT_1_ADDR:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                isr_enable_context_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	          // FIX (#4): thresholds are now writable.
	          ISR_THRES_CONTEXT_0_ADDR:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                isr_thres_context_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	          ISR_THRES_CONTEXT_1_ADDR:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                isr_thres_context_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	          // complete (ctx0 / M-mode)
			  ISR_CLAIM_COMPL_CONTEXT_0_ADDR:
                    if ( S_AXI_WSTRB[0] == 1 && S_AXI_WDATA == 32'b1) begin
                        uart_claimed <= 0;
                end
	          // FIX (#3): complete (ctx1 / S-mode) was previously unhandled,
	          // so an S-mode-only config could never re-arm after the first IRQ.
			  ISR_CLAIM_COMPL_CONTEXT_1_ADDR:
                    if ( S_AXI_WSTRB[0] == 1 && S_AXI_WDATA == 32'b1) begin
                        uart_claimed <= 0;
                end
	          default : ;
	        endcase
	      end
	    // FIX (#2): use S_AXI_ARADDR (the address being presented THIS cycle)
	    // instead of axi_araddr (a register updated by the read FSM in a
	    // separate always block on the same edge, so it was one transaction
	    // stale). Also gated on isr_claim_compl_context_X != 0 so a claim
	    // read when nothing is pending can't spuriously latch uart_claimed
	    // and permanently mask a future interrupt.
	    else if (S_AXI_ARVALID && S_AXI_ARREADY
	                  && ((S_AXI_ARADDR == ISR_CLAIM_COMPL_CONTEXT_0_ADDR && isr_claim_compl_context_0 != 32'b0) ||
	                      (S_AXI_ARADDR == ISR_CLAIM_COMPL_CONTEXT_1_ADDR && isr_claim_compl_context_1 != 32'b0))) begin
	          uart_claimed <= 1;
	      end
	  end
	end

	// Implement read state machine
	  always @(posedge S_AXI_ACLK)
	    begin
	      if (S_AXI_ARESETN == 1'b0)
	        begin
	         //asserting initial values to all 0's during reset
	         axi_arready <= 1'b0;
	         axi_rvalid <= 1'b0;
	         axi_rresp <= 1'b0;
	         state_read <= Idle;
	        end
	      else
	        begin
	          case(state_read)
	            Idle:     //Initial state inidicating reset is done and ready to receive read/write transactions
	              begin
	                if (S_AXI_ARESETN == 1'b1)
	                  begin
	                    state_read <= Raddr;
	                    axi_arready <= 1'b1;
	                  end
	                else state_read <= state_read;
	              end
	            Raddr:        //At this state, slave is ready to receive address along with corresponding control signals
	              begin
	                if (S_AXI_ARVALID && S_AXI_ARREADY)
	                  begin
	                    state_read <= Rdata;
	                    axi_araddr <= S_AXI_ARADDR;
	                    axi_rvalid <= 1'b1;
	                    axi_arready <= 1'b0;
	                  end
	                else state_read <= state_read;
	              end
	            Rdata:        //At this state, slave is ready to send the data packets until the number of transfers is equal to burst length
	              begin
	                if (S_AXI_RVALID && S_AXI_RREADY)
	                  begin
	                    axi_rvalid <= 1'b0;
	                    axi_arready <= 1'b1;
	                    state_read <= Raddr;
	                  end
	                else state_read <= state_read;
	              end
	           endcase
	          end
	    end

	// Implement memory mapped register select and read logic generation
	reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_read_data;
	always @(*) begin
    case(axi_araddr)
        ISR_SOURCE_1_PRIO_ADDR:           axi_read_data = isr_source_1_prio;
        ISR_PENDING_BITS_ADDR:            axi_read_data = isr_pending_bits;
        ISR_ENABLE_CONTEXT_0_ADDR:        axi_read_data = isr_enable_context_0;
        ISR_ENABLE_CONTEXT_1_ADDR:        axi_read_data = isr_enable_context_1;
        ISR_THRES_CONTEXT_0_ADDR:         axi_read_data = isr_thres_context_0;
        ISR_THRES_CONTEXT_1_ADDR:         axi_read_data = isr_thres_context_1;
        ISR_CLAIM_COMPL_CONTEXT_0_ADDR:   axi_read_data = isr_claim_compl_context_0;
        ISR_CLAIM_COMPL_CONTEXT_1_ADDR:   axi_read_data = isr_claim_compl_context_1;
        default: axi_read_data = {C_S_AXI_DATA_WIDTH{1'b0}};
    endcase
end
	assign S_AXI_RDATA = axi_read_data;

	// Gateway + per-context interrupt output / claim register.
	// FIX (#1): meip_q/seip_q/claim_compl_* are now driven EVERY cycle from
	// ctx0_irq/ctx1_irq (combinational), not just set-and-latched inside an
	// if with no else. This lets them deassert again once uart_claimed
	// clears isr_pending_bits[1] - previously they stayed stuck at 1
	// forever after the first interrupt, and claim() never returned 0,
	// which would hang any standard claim-loop (Linux/Zephyr PLIC drivers).
	always @(posedge S_AXI_ACLK) begin
	    if (S_AXI_ARESETN == 1'b0) begin
			meip_q <= 0;
			seip_q <= 0;
			isr_pending_bits <= 32'b0;
			isr_claim_compl_context_0 <= 32'b0;
			isr_claim_compl_context_1 <= 32'b0;
		end else begin
            // gateway: pending while UART asserts and not yet claimed.
            // re-arms automatically once uart_claimed clears (in the
            // other always block) if uart_isr is still high.
            isr_pending_bits[1] <= uart_isr && !uart_claimed;

            meip_q                     <= ctx0_irq;
            seip_q                     <= ctx1_irq;
            isr_claim_compl_context_0  <= ctx0_irq ? 32'd1 : 32'd0;
            isr_claim_compl_context_1  <= ctx1_irq ? 32'd1 : 32'd0;
	    end
	end
	// User logic ends

	endmodule
