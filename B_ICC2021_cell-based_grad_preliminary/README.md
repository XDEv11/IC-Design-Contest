# geofence README

1. 因為有使用到 DesignWare Library，進行 functional simulation 的時候請加上下列參數（或是直接把相關檔案抓到當前目錄）。

> ncverilog ... -y $SYNOPSYS/dw/sim_ver +libext+.v +incdir+$SYNOPSYS/dw/sim_ver

