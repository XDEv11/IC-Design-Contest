module TPA(clk, reset_n, 
	   SCL, SDA, 
	   cfg_req, cfg_rdy, cfg_cmd, cfg_addr, cfg_wdata, cfg_rdata);
input 		clk; 
input 		reset_n;
// Two-Wire Protocol slave interface 
input 		SCL;  
inout		SDA;

// Register Protocal Master interface 
input		cfg_req;
output		cfg_rdy;
input		cfg_cmd;
input	[7:0]	cfg_addr;
input	[15:0]	cfg_wdata;
output	[15:0]  cfg_rdata;

reg	[15:0] Register_Spaces	[0:255];

// ===== Coding your RTL below here ================================= 
reg	cfg_rdy;
reg	[15:0] cfg_rdata;

reg [7:0] twp_addr;
reg [15:0] twp_data;
reg twp_read_request;
reg twp_read_finish;
reg twp_write_request;
//reg twp_write_finish;

reg [7:0] rim_addr;
reg [15:0] rim_data;
reg rim_read_request;
//reg rim_read_finish;
reg rim_write_request;
reg rim_write_finish;

reg [7:0] read_addr;
reg [15:0] read_data;
always @(*) begin
	read_addr <= 8'hx;
	twp_read_finish <= 1'b0;
	//rim_read_finish <= 1'b0;
	if (twp_read_request) begin
		read_addr <= twp_addr;
		twp_read_finish <= 1'b1;
	end
	else if (rim_read_request) begin
		read_addr <= rim_addr;
		//rim_read_finish <= 1'b1;
	end
end
always @(*) begin
	read_data <= Register_Spaces[read_addr];
end

reg write_request;
reg [7:0] write_addr;
reg [15:0] write_data;
always @(*) begin
	write_request <= 1'b0;
	write_addr <= 8'hx;
	write_data <= 16'hx;
	//twp_write_finish <= 1'b0;
	rim_write_finish <= 1'b0;
	if (twp_write_request) begin
		write_request <= 1'b1;
		write_addr <= twp_addr;
		write_data <= twp_data;
		//twp_write_finish <= 1'b1;
	end
	else if (rim_write_request) begin
		write_request <= 1'b1;
		write_addr <= rim_addr;
		write_data <= rim_data;
		rim_write_finish <= 1'b1;
	end
end
always @(posedge clk) begin
	if (write_request) Register_Spaces[write_addr] <= write_data;
end

// Two Wire Protocol

reg [3:0] twp_state, twp_nxt_state;
localparam TWP_Idle		= 4'd0;
localparam TWP_Cmd		= 4'd1;
localparam TWP_Addr		= 4'd2;
localparam TWP_Write	= 4'd3;
localparam TWP_Read_s0	= 4'd4;
localparam TWP_Read_s1	= 4'd5;
localparam TWP_Read_s2	= 4'd6;
localparam TWP_Read_s3	= 4'd7;
localparam TWP_Read_s4	= 4'd8;

reg SDA_mine;
reg SDA_flag;
assign SDA = SDA_flag ? SDA_mine : 1'bz;

reg twp_is_writing, twp_is_writing_next;
reg [3:0] twp_cnt;
wire [3:0] twp_cnt_add_1 = twp_cnt + 4'd1;

always @(*) begin
	twp_nxt_state <= twp_state;
	case (twp_state)
		TWP_Idle :
			if (SDA == 1'b0) twp_nxt_state <= TWP_Cmd;
		TWP_Cmd : twp_nxt_state <= TWP_Addr;
		TWP_Addr :
			if (twp_cnt[2:0] == 3'd7) begin
				if (twp_is_writing) twp_nxt_state <= TWP_Write;
				else twp_nxt_state <= TWP_Read_s0;
			end
		TWP_Write :
			if (twp_cnt == 4'd15) twp_nxt_state <= TWP_Idle;
		TWP_Read_s0 : twp_nxt_state <= TWP_Read_s1;
		TWP_Read_s1 : twp_nxt_state <= TWP_Read_s2;
		TWP_Read_s2 : twp_nxt_state <= TWP_Read_s3;
		TWP_Read_s3 :
			if (twp_cnt == 4'd15) twp_nxt_state <= TWP_Read_s4;
		TWP_Read_s4 : twp_nxt_state <= TWP_Idle;
	endcase
end

always @(posedge clk/* or negedge reset_n*/) begin
	if (!reset_n) twp_state <= TWP_Idle;
	else twp_state <= twp_nxt_state;
end

always @(*) begin
	twp_is_writing_next <= twp_is_writing;
	case (twp_state)
		TWP_Idle : twp_is_writing_next <= 1'b0;
		TWP_Cmd : twp_is_writing_next <= SDA;
	endcase
end

always @(posedge clk) begin
	twp_is_writing <= twp_is_writing_next;
	twp_read_request <= 1'b0;
	twp_write_request <= 1'b0;
	SDA_flag <= 1'b0;
	case (twp_state)
		TWP_Cmd : begin
			twp_cnt <= 4'd0;
		end
		TWP_Addr : begin
			twp_addr <= {SDA, twp_addr[7:1]};
			twp_cnt[2:0] <= twp_cnt_add_1[2:0];
		end
		TWP_Write : begin
			twp_data <= {SDA, twp_data[15:1]};
			twp_cnt <= twp_cnt_add_1;
			if (twp_cnt == 4'd15) twp_write_request <= 1'b1;
		end
		TWP_Read_s0 : begin
			twp_read_request <= 1'b1;
		end
		TWP_Read_s1 : begin
			if (twp_read_finish) twp_data <= read_data;
			else twp_read_request <= 1'b1;
			SDA_flag <= 1'b1;
			SDA_mine <= 1'b1;
		end
		TWP_Read_s2 : begin
			if (twp_read_finish) twp_data <= read_data;
			SDA_flag <= 1'b1;
			SDA_mine <= 1'b0;
		end
		TWP_Read_s3 : begin
			SDA_flag <= 1'b1;
			SDA_mine <= twp_data[0];
			twp_data[14:0] <= twp_data[15:1];
			twp_cnt <= twp_cnt_add_1;
		end
		TWP_Read_s4 : begin
			SDA_flag <= 1'b1;
			SDA_mine <= 1'b1;
		end
	endcase
end

// Register Interface Master

reg [1:0] rim_state, rim_nxt_state;
localparam RIM_Idle		= 2'd0;
localparam RIM_Read		= 2'd1;
localparam RIM_Write	= 2'd2;

always @(*) begin // next state logic
	rim_nxt_state <= rim_state;
	case (rim_state)
		RIM_Idle :
			if (cfg_req) begin
				if (cfg_cmd == 1'b0) rim_nxt_state <= RIM_Read;
				else rim_nxt_state <= RIM_Write;
			end
		RIM_Read : rim_nxt_state <= RIM_Idle;
		RIM_Write :
			if (!twp_is_writing_next) rim_nxt_state <= RIM_Idle;
	endcase
end

always @(posedge clk/* or negedge reset_n*/) begin
	if (!reset_n) rim_state <= RIM_Idle;
	else rim_state <= rim_nxt_state;
end

always @(posedge clk) begin
	rim_read_request <= 1'b0;
	rim_write_request <= 1'b0;
	cfg_rdy <= 1'b0;
	case (rim_state)
		RIM_Idle : begin
			rim_addr <= cfg_addr;
			rim_data <= cfg_wdata;
			if (cfg_req) begin
				cfg_rdy <= 1'b1;
				if (cfg_cmd == 1'b0) rim_read_request <= 1'b1;
			end
		end
		RIM_Read : begin
			cfg_rdy <= 1'b1;
			cfg_rdata <= read_data;
		end
		RIM_Write : begin
			cfg_rdy <= 1'b1;
			if (!twp_is_writing_next) rim_write_request <= 1'b1;
		end
	endcase
end

endmodule
