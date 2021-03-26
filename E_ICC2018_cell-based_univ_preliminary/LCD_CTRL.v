module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input clk;
input reset;
input [3:0] cmd;
input cmd_valid;
input [7:0] IROM_Q;
output IROM_rd;
output [5:0] IROM_A;
output IRAM_valid;
output [7:0] IRAM_D;
output [5:0] IRAM_A;
output busy;
output done;

// my design //
reg IRAM_valid;
reg [7:0] IRAM_D;
reg [5:0] IRAM_A;
reg busy;
reg done;
reg [2:0] state, nxt_state;
localparam Idle		= 3'd0;
localparam Load		= 3'd1;
localparam Exe		= 3'd2;
localparam Write	= 3'd3;
localparam Finish	= 3'd4;

reg [7:0] data [0:63];
reg [5:0] pos;
wire [2:0] pos_x	= pos[2:0];
wire [2:0] pos_y	= pos[5:3];
wire [5:0] pos_l	= pos - {3'h0, 3'h1};
wire [5:0] pos_r	= pos + {3'h0, 3'h1};
wire [5:0] pos_u	= pos - {3'h1, 3'h0};
wire [5:0] pos_d	= pos + {3'h1, 3'h0};
wire [5:0] pos_rd	= pos + {3'h1, 3'h1};
wire [7:0] data_pos_ = data[pos];
wire [7:0] data_pos_r_ = data[pos_r];
wire [7:0] data_pos_d_ = data[pos_d];
wire [7:0] data_pos_rd_ = data[pos_rd];
wire last_pos = (pos == {3'h7, 3'h7});

wire [9:0] sum = data_pos_ + data_pos_r_ + data_pos_d_ + data_pos_rd_;
wire [7:0] avg = sum[9:2];
wire [7:0] _mn1 = (data_pos_ <= data_pos_r_ ? data_pos_ : data_pos_r_);
wire [7:0] _mn2 = (data_pos_d_ <= data_pos_rd_ ? data_pos_d_ : data_pos_rd_);
wire [7:0] mn = (_mn1 <= _mn2 ? _mn1 : _mn2);
wire [7:0] _mx1 = (data_pos_ > data_pos_r_ ? data_pos_ : data_pos_r_);
wire [7:0] _mx2 = (data_pos_d_ > data_pos_rd_ ? data_pos_d_ : data_pos_rd_);
wire [7:0] mx = (_mx1 > _mx2 ? _mx1 : _mx2);

always @(*) begin // next state logic
	nxt_state = state;
	case (state)
		Idle : nxt_state = Load;
		Load :
			if (last_pos) nxt_state = Exe;
		Exe :
			if (cmd_valid && cmd == 4'd0) nxt_state = Write;
		Write :
			if (last_pos) nxt_state = Finish;
	endcase
end

always @(posedge clk/* or posedge reset*/) begin // FSM
	if (reset) state <= Idle;
	else state <= nxt_state;
end

assign IROM_rd = 1'b1;
assign IROM_A = pos;
always @(posedge clk) begin
	IRAM_valid <= 1'b0;
	IRAM_A <= 6'hx;
	IRAM_D <= 8'hx;
	busy <= 1'b1;
	done <= 1'b0;
	case (state)
		Idle : begin
			pos <= 6'd0;
		end
		Load : begin
			data[pos] <= IROM_Q;
			pos <= pos_r;
			if (last_pos) pos <= {3'h3, 3'h3};
		end
		Exe : begin
			busy <= 1'b0;
			if (cmd_valid) begin
				case(cmd)
					4'd0 : begin // write
						pos <= {3'h0, 3'h0};
						busy <= 1'b1;
					end
					4'd1 : begin // shift up
						if (pos_y != 3'h0) pos <= pos_u;
					end
					4'd2 : begin // shift down
						if (pos_y != 3'h6) pos <= pos_d;
					end
					4'd3 : begin // shift left
						if (pos_x != 3'h0) pos <= pos_l;
						end
					4'd4 : begin // shift right
						if (pos_x != 3'h6) pos <= pos_r;
					end	
					4'd5 : begin // mx
						data[pos]		<= mx;
						data[pos_r]		<= mx;
						data[pos_d]		<= mx;
						data[pos_rd]	<= mx;
					end
					4'd6 : begin // mn
						data[pos]		<= mn;
						data[pos_r]		<= mn;
						data[pos_d]		<= mn;
						data[pos_rd]	<= mn;
					end
					4'd7 : begin // average
						data[pos]		<= avg;
						data[pos_r]		<= avg;
						data[pos_d]		<= avg;
						data[pos_rd]	<= avg;
					end
					4'd8 : begin // counterclockwise rotation
						data[pos_d]		<= data_pos_;
						data[pos]		<= data_pos_r_;
						data[pos_r]		<= data_pos_rd_;
						data[pos_rd]	<= data_pos_d_;
					end
					4'd9 : begin // clockwise rotation
						data[pos_r]		<= data_pos_;
						data[pos_rd]	<= data_pos_r_;
						data[pos_d]		<= data_pos_rd_;
						data[pos]		<= data_pos_d_;
					end
					4'd10 : begin // mirror x
						data[pos]		<= data_pos_d_;
						data[pos_d]		<= data_pos_;
						data[pos_r]		<= data_pos_rd_;
						data[pos_rd]	<= data_pos_r_;
					end
					4'd11 : begin // mirror y
						data[pos]		<= data_pos_r_;
						data[pos_r]		<= data_pos_;
						data[pos_d]		<= data_pos_rd_;
						data[pos_rd]	<= data_pos_d_;
					end
				endcase
			end
		end
		Write : begin
			IRAM_valid <= 1'b1;
			IRAM_A <= pos;
			IRAM_D <= data_pos_;
			pos <= pos_r;
		end
		Finish : begin
			busy <= 1'b0;
			done <= 1'b1;
		end
	endcase
end

endmodule
