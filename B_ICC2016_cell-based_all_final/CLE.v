`timescale 1ns/10ps
module CLE ( clk, reset, rom_q, rom_a, sram_q, sram_a, sram_d, sram_wen, finish);
input         clk;
input         reset;
input  [7:0]  rom_q;
output reg [6:0]  rom_a;
input  [7:0]  sram_q;
output reg [9:0]  sram_a;
output reg [7:0]  sram_d;
output reg        sram_wen;
output reg        finish;
/* my design */
integer i;
reg [2:0] state, nxt_state;
localparam Idle			= 3'd0;
localparam Read			= 3'd1;
localparam Write		= 3'd2;
localparam Write_last	= 3'd3;
localparam Back_Read	= 3'd4;
localparam Back_Write	= 3'd5;
localparam Finish		= 3'd6;

reg is_obj;
reg [7:0] label_cnt;

reg [9:0] addr;
wire first_row = (addr[9:5] == 5'h0);
wire last_row = (addr[9:5] == 5'h1F);
wire first_col = (addr[4:0] == 5'h0);
wire last_col = (addr[4:0] == 5'h1F);
wire [9:0] addr_l = addr - {5'h0, 5'h1};
wire [9:0] addr_ur = addr - {5'h0, 5'h1F};
wire [9:0] addr_r = addr + {5'h0, 5'h1};
reg [7:0] _l, _ul, _u;
wire [7:0] l = (first_col ? 8'h0 : _l);
wire [7:0] ul = (first_row || first_col ? 8'h0 : _ul);
wire [7:0] u = (first_row ? 8'h0 : _u);
wire [7:0] ur = (first_row || last_col ? 8'h0 : sram_q);
wire [7:0] neb_label = (l ? l : (ul ? ul : (u ? u : (ur ? ur : 8'h0))));

reg [9:0] back_addr;
wire [9:0] back_addr_l = back_addr - {5'h0, 5'h1};
reg back_flag;
wire back_first_col = (back_addr[4:0] == 5'h0);
wire back_end = back_first_col && (!back_flag || back_addr[9:5] == 5'h0);

always @(*) begin // next state logic
	nxt_state <= state;
	case (state)
		Idle : nxt_state <= Read;
		Read : nxt_state <= Write;
		Write :
			if (is_obj && neb_label && ur && neb_label != ur) nxt_state <= Back_Read;
			else if (last_row && last_col) nxt_state <= Write_last;
			else nxt_state <= Read;
		Back_Read :
			if (sram_q == _l) nxt_state <= Back_Write;
			else if (back_end) nxt_state <= Read;
		Back_Write : nxt_state <= Back_Read;
		Write_last : nxt_state <= Finish;
	endcase
end

always @(posedge clk/* or posedge reset*/) begin // FSM
	if (reset) state <= Idle;
	else state <= nxt_state;
end

always @(*) begin
	rom_a <= 7'hx;
	case (state)
		Read : rom_a <= addr[9:3];
	endcase
	is_obj <= rom_q[~addr[2:0]];
end

always @(*) begin
	sram_a <= 10'hx;
// synopsys translate_off
	sram_a <= 10'h0; // weird (can't be unknown (x) in functional simulation)
// synopsys translate_on
	sram_d <= 8'hx;
	sram_wen <= 1'b1;
	case (state)
		Read : begin
			sram_a <= addr_ur;
		end
		Write, Write_last : begin
			sram_a <= addr_l;
			sram_d <= _l;
			sram_wen <= 1'b0;
		end
		Back_Read : begin
			sram_a <= back_addr_l;
		end
		Back_Write : begin
			sram_a <= back_addr;
			sram_d <= _u;
			sram_wen <= 1'b0;
		end
	endcase
end

always @(posedge clk) begin
	finish <= 1'b0;
	case (state)
		Idle : begin
			addr <= 10'h0;
			label_cnt <= 8'h1;
		end
		Write : begin
			_ul <= _u;
			_u <= sram_q;
			if (is_obj) begin
				if (neb_label) _l <= neb_label;
				else begin
					_l <= label_cnt;
					label_cnt <= label_cnt + 8'h1;
				end
			end
			else _l <= 8'h0;
			addr <= addr_r;

			back_addr <= addr_l;
			back_flag <= 1'b1;
		end
		Back_Read : begin
			if (sram_q != _l) begin // sram_q is what is written after a write
				back_addr <= back_addr_l;
				if (back_first_col) back_flag <= 1'b0;
				if (back_end) _l <= _u;
			end
		end
		Back_Write : begin
			back_flag <= 1'b1;
		end
		Finish : begin
			finish <= 1'b1;
		end
	endcase
end

endmodule
