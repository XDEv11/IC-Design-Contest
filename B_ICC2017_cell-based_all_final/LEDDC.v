`timescale 1ns/10ps

module LEDDC( DCK, DAI, DEN, GCK, Vsync, mode, rst, OUT);
input           DCK;
input           DAI;
input           DEN;
input           GCK;
input           Vsync;
input           mode;
input           rst;
output reg [15:0] OUT;
/* my design */
integer i;

reg [15:0] QA;
reg [8:0] AA;
reg CENA;
reg [8:0] AB;
reg [15:0] DB;
reg CENB;
// one sram_256x16 & one sram_512x16
wire [15:0] QA_256;
reg [7:0] AA_256;
reg CENA_256;
reg [7:0] AB_256;
reg [15:0] DB_256;
reg CENB_256;
sram_256x16 SRAM_256(
   .QA (QA_256),
   .AA (AA_256),
   .CLKA (~GCK),
   .CENA (CENA_256),
   .AB (AB_256),
   .DB (DB_256),
   .CLKB (~DCK),
   .CENB (CENB_256)
);
wire [15:0] QA_512;
reg [8:0] AA_512;
reg CENA_512;
reg [8:0] AB_512;
reg [15:0] DB_512;
reg CENB_512;
sram_512x16 SRAM_512(
   .QA (QA_512),
   .AA (AA_512),
   .CLKA (~GCK),
   .CENA (CENA_512),
   .AB (AB_512),
   .DB (DB_512),
   .CLKB (~DCK),
   .CENB (CENB_512)
);
// transform to real output to SRAM
reg [1:0] D_frame_cnt, D_frame_cnt_next;
reg [1:0] G_frame_cnt, G_frame_cnt_next;
always @(*) begin
	// 0 -> 1 -> 2 -> 0 -> ...
	if (D_frame_cnt == 2'd2) D_frame_cnt_next <= 2'd0;
	else D_frame_cnt_next <= D_frame_cnt + 2'd1;
	if (G_frame_cnt == 2'd2) G_frame_cnt_next <= 2'd0;
	else G_frame_cnt_next <= G_frame_cnt + 2'd1;
end
always @(*) begin
	// write
	AB_256 <= 8'hx;
	DB_256 <= 16'hx;
	CENB_256 <= 1'b1; 
	AB_512 <= 9'hx;
	DB_512 <= 16'hx;
	CENB_512 <= 1'b1;
	if (D_frame_cnt == 2'd0) begin // SRAM_512[0:511]
		AB_512 <= AB;
		DB_512 <= DB;
		CENB_512 <= CENB;
	end
	else if (D_frame_cnt == 2'd1) begin // {SRAM_256[0:255], SRAM_512[0:255]}
		if (AB[8] == 1'b0) begin // SRAM_256[0:255]
			AB_256 <= AB[7:0];
			DB_256 <= DB;
			CENB_256 <= CENB;
		end
		else begin // SRAM_512[0:255]
			AB_512 <= {1'b0, AB[7:0]};
			DB_512 <= DB;
			CENB_512 <= CENB;
		end
	end
	else begin // {SRAM_512[256:511], SRAM_256[0:255]}
		if (AB[8] == 1'b0) begin // SRAM_512[256:511]
			AB_512 <= {1'b1, AB[7:0]};
			DB_512 <= DB;
			CENB_512 <= CENB;
		end
		else begin // SRAM_256[0:255]
			AB_256 <= AB[7:0];
			DB_256 <= DB;
			CENB_256 <= CENB;
		end
	end
end
always @(*) begin
	// read
	AA_256 <= 8'hx;
	CENA_256 <= 1'b1;
	AA_512 <= 9'hx;
	CENA_512 <= 1'b1;
	if (G_frame_cnt == 2'd0) begin // SRAM_512[0:511]
		//QA <= QA_512;
		AA_512 <= AA;
		CENA_512 <= CENA;
	end
	else if (G_frame_cnt == 2'd1) begin // {SRAM_256[0:255], SRAM_512[0:255]}
		if (AA[8] == 1'b0) begin // SRAM_256[0:255]
			//QA <= QA_256;
			AA_256 <= AA[7:0];
			CENA_256 <= CENA;
		end
		else begin // SRAM_512[0:255]
			//QA <= QA_512;
			AA_512 <= {1'b0, AA[7:0]};
			CENA_512 <= CENA;
		end
	end
	else begin // {SRAM_512[256:511], SRAM_256[0:255]}
		if (AA[8] == 1'b0) begin // SRAM_512[256:511]
			//QA <= QA_512;
			AA_512 <= {1'b1, AA[7:0]};
			CENA_512 <= CENA;
		end
		else begin // SRAM_256[0:255]
			//QA <= QA_256;
			AA_256 <= AA[7:0];
			CENA_256 <= CENA;
		end
	end
end
reg [15:0] _QA_256, _QA_512; // in order to improve timing
always @(posedge GCK) begin
	_QA_512 <= QA_512;
	_QA_256 <= QA_256;
end
always @(*) begin
	if (G_frame_cnt == 2'd0) begin
		QA <= _QA_512;
	end
	else if (G_frame_cnt == 2'd1) begin // {SRAM_256[0:255], SRAM_512[0:255]}
		if (AA[8] == 1'b0) QA <= _QA_256;
		else QA <= _QA_512;
	end
	else begin // {SRAM_512[256:511], SRAM_256[0:255]}
		if (AA[8] == 1'b0) QA <= _QA_512;
		else QA <= _QA_256;
	end
end

/*  *   *   *   *   *   *   *   *   */
reg [1:0] D_state, D_nxt_state;
localparam D_Init	= 2'd0;
localparam D_Idle	= 2'd1;
localparam D_Read	= 2'd2;
reg [15:0] pixel;
reg [8:0] pixel_cnt;
always @(*) begin // next state logic
	D_nxt_state <= D_state;
	case (D_state)
		D_Init :
			if (DEN) D_nxt_state <= D_Read;
		D_Idle :
			if (DEN) D_nxt_state <= D_Read;
		D_Read :
			if (!DEN) D_nxt_state <= D_Idle;
	endcase
end

always @(posedge DCK or posedge rst) begin // FSM
	if (rst) D_state <= D_Init;
	else D_state <= D_nxt_state;
end

always @(posedge DCK) begin
	CENB <= 1'b1;
	pixel <= {DAI, pixel[15:1]};
	case (D_state)
		D_Init : begin
			pixel_cnt <= 9'h0;
			D_frame_cnt <= 2'b00;
		end
		D_Idle : begin
			if (DEN) begin
				pixel_cnt <= pixel_cnt + 9'd1;
				if (pixel_cnt == 9'h1FF) D_frame_cnt <= D_frame_cnt_next;
			end
		end
		D_Read : begin
			if (!DEN) begin
				CENB <= 1'b0;
				AB <= pixel_cnt;
				DB <= pixel;
			end
		end
	endcase
end

/*  *   *   *   *   *   *   *   *   */
reg [1:0] G_state, G_nxt_state;
localparam G_Idle		= 2'd0;
localparam G_Out_30fps	= 2'd1;
localparam G_Out_60fps	= 2'd2;
localparam G_Next		= 2'd3;

reg [15:0] cur_sl [0:15];
reg [15:0] nxt_sl [0:15];
reg [4:0] sl_cnt;
wire [4:0] sl_cnt_next = sl_cnt + 5'h1;
reg round; // for 60fps
reg [15:0] out_cnt;
wire [15:0] out_cnt_add_1 = out_cnt + 16'h1;

always @(*) begin // next state logic
	G_nxt_state <= G_state;
	case (G_state)
		G_Idle :
			if (mode == 1'b0) G_nxt_state <= G_Out_30fps;
			else G_nxt_state <= G_Out_60fps;
		G_Out_30fps :
			if (out_cnt == 16'hFFFF) G_nxt_state <= G_Next;
		G_Out_60fps :
			if (out_cnt[14:0] == 15'h7FFF) G_nxt_state <= G_Next;
		G_Next :
			if (mode == 1'b0) G_nxt_state <= G_Out_30fps;
			else G_nxt_state <= G_Out_60fps;
	endcase
end

always @(posedge GCK or posedge rst) begin // FSM
	if (rst) G_state <= G_Idle;
	else G_state <= G_nxt_state;
end

always @(posedge GCK) begin
	case (G_state)
		G_Idle : begin
			out_cnt <= 16'h0;
			sl_cnt <= 5'h0;
			G_frame_cnt <= 2'b10;
			if (mode == 1'b0) round <= 1'b1;
			else round <= 1'b0;
		end
		G_Out_30fps : begin
			if (Vsync) begin
				out_cnt <= out_cnt_add_1;
				for (i = 0; i < 16; i = i + 1) OUT[i] <= (cur_sl[i] > out_cnt);
			end
		end
		G_Out_60fps : begin // only use out_cnt[14:0]
			if (Vsync) begin
				out_cnt <= out_cnt_add_1;
				for (i = 0; i < 16; i = i + 1) OUT[i] <= (cur_sl[i] > out_cnt[14:0]);
				if (out_cnt[14:0] == 15'h7FFF && sl_cnt == 5'h1F) round <= ~round;
			end
		end
		G_Next : begin
			for (i = 0; i < 16; i = i + 1)
				if (mode == 1'b0) cur_sl[i] <= nxt_sl[i];
				else begin
					if (round == 1'b0) cur_sl[i] <= (nxt_sl[i] >> 1) + nxt_sl[i][0];
					else cur_sl[i] <= (nxt_sl[i] >> 1);
				end
			sl_cnt <= sl_cnt_next;
			if (sl_cnt == 5'h1E && round == 1'b1) G_frame_cnt <= G_frame_cnt_next;
		end
	endcase
end

// auxiliary FSM to read into next_sl
reg G_aux_state, G_aux_nxt_state;
localparam G_aux_Idle = 1'd0;
localparam G_aux_Read = 1'd1;

reg [4:0] read_cnt;
wire [4:0] read_cnt_add_1 = read_cnt + 5'h1;

always @(*) begin
	G_aux_nxt_state <= G_aux_state;
	case (G_aux_state)
		G_aux_Idle :
			if (G_state == G_Next) G_aux_nxt_state <= G_aux_Read;
		G_aux_Read : 
			if (read_cnt == 5'h11) G_aux_nxt_state <= G_aux_Idle;
	endcase
end

always @(posedge GCK or posedge rst) begin
	if (rst) G_aux_state <= G_aux_Idle;
	else G_aux_state <= G_aux_nxt_state;
end

always @(posedge GCK) begin
	CENA <= 1'b1;
	case (G_aux_state)
		G_aux_Idle : begin
			read_cnt <= 5'h0;
		end
		G_aux_Read : begin
			AA <= {sl_cnt_next, read_cnt[3:0]};
			CENA <= 1'b0;
			for (i = 1; i < 16; i = i + 1) nxt_sl[i - 1] <= nxt_sl[i];
			nxt_sl[15] <= QA;
			read_cnt <= read_cnt_add_1;
		end
	endcase
end

endmodule
