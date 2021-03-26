# RFILE README

1. 因為 RFILE.v 裡面有多個 module，請加上參數指定 top module。

> read_file -format verilog RFILE.v -autoread -top RFILE

2. 因為查表記憶體沒有延遲，輸出（`exp*`）前又有 Flip-flops，所以輸入（`value*`）進來後有接近一個 cycle 的時間可以做運用，設定如下（假設 cycle 為 5ns）。

> set cycle 5.0
> create_clock -name clk -period $cycle   [get_ports  clk];#Modify period by yourself
> set_input_delay -max 1.0 -clock clk [get_ports  value*];#Modify value  by yourself
> set_input_delay -min 0.0 -clock clk [get_ports  value*];#Modify value  by yourself
> set_output_delay -max [expr $cycle-1.0] -clock clk [get_ports  exp*];#Modify value  by yourself
> set_output_delay -min 0.0 -clock clk [get_ports  exp*];#Modify value  by yourself

3. 相關數學式推倒如下。

> $(x_a-x_t)^2+(y_a-y_t)^2=(d_a)^2$
> 
> $(x_b-x_t)^2+(y_b-y_t)^2=(d_b)^2$
> 
> $(x_c-x_t)^2+(y_c-y_t)^2=(d_c)^2$
> 
> =>
> 
> $(x_a)^2-2x_ax_t+(x_t)^2+(y_a)^2-2y_ay_t+(y_t)^2=(d_a)^2$
> 
> $(x_b)^2-2x_bx_t+(x_t)^2+(y_b)^2-2y_by_t+(y_t)^2=(d_b)^2$
> 
> $(x_c)^2-2x_cx_t+(x_t)^2+(y_c)^2-2y_cy_t+(y_t)^2=(d_c)^2$
> 
> =>
> 
> $(x_a)^2+(y_a)^2-(d_a)^2-(x_b)^2-(y_b)^2+(d_b)^2=2(x_a-x_b)x_t+2(y_a-y_b)y_t$
> 
> $(x_a)^2+(y_a)^2-(d_a)^2-(x_c)^2-(y_c)^2+(d_c)^2=2(x_a-x_c)x_t+2(y_a-y_c)y_t$

---
> 
> $t_1=t_2x_t+t_3y_t$
> 
> $t_4=t_5x_t+t_6y_t$
> 
> =>
> 
> $t_6t_1=t_6t_2x_t+t_6t_3y_t$
> 
> $t_3t_4=t_3t_5x_t+t_3t_6y_t$
> 
> ( $t_5t_1=t_5t_2x_t+t_5t_3y_t$ )
> 
> ( $t_2t_4=t_2t_5x_t+t_2t_6y_t$ )
> 
> =>
> 
> $x=(t_6t_1-t_3t_4)/(t_6t_2-t_3t_5)$
> 
> ( $y=(t_2t_4-t_5t_1)/(t_2t_6-t_5t_3)$ )

