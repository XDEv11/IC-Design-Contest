# GPSDC README

1. 因為 GPSDC.v 裡面有多個 module，請加上參數指定 top module。

> read_file -format verilog GPSDC.v -autoread -top GPSDC

2. 雖然查表記憶體沒有延遲，但因為 .sdc 檔沒有正確設定，建議輸出（`*_ADDR`），與輸入（`*_DATA`）間要有 Flip-flops，不然就會變成輸出有差不多一個 cycle 可以運用，然後它以為資料進來也有一個 cycle 可以運算，但實際上它們是同個 cycle，就可能會有 timing violation 。（或是參考 2018 決賽 RFILE 的設定方式，但比賽可能不允許變更 .sdc 檔）

3. testbench 100 行的部分不知道為什麼要在正緣後 1 ns 才檢查 `Valid`，所以最好在讓 `Valid` 前多個 Flip-flop，不然 gate-level simulation 可能會出問題。

