package axi_pkg;

    // AXI4-Lite bus configuration
    parameter int ADDR_WIDTH = 32;
    parameter int DATA_WIDTH = 32;
    parameter int STRB_WIDTH = DATA_WIDTH / 8;

    // Register bank configuration
    parameter int NUM_REGS = 16;
    parameter int REG_ADDR_WIDTH = $clog2(NUM_REGS);

    // AXI response encodings
    parameter logic [1:0] AXI_RESP_OKAY   = 2'b00;
    parameter logic [1:0] AXI_RESP_EXOKAY = 2'b01;
    parameter logic [1:0] AXI_RESP_SLVERR = 2'b10;
    parameter logic [1:0] AXI_RESP_DECERR = 2'b11;

endpackage
