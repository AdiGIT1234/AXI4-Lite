
module axi4_lite_slave #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_REGS   = 16
) (
    input  logic                   clk,
    input  logic                   rst_n,

    // AXI Write Address Channel
    input  logic [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  logic                   s_axi_awvalid,
    output logic                   s_axi_awready,

    // AXI Write Data Channel
    input  logic [DATA_WIDTH-1:0]  s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                   s_axi_wvalid,
    output logic                   s_axi_wready,

    // AXI Write Response Channel
    output logic [1:0]             s_axi_bresp,
    output logic                   s_axi_bvalid,
    input  logic                   s_axi_bready,

    // AXI Read Address Channel
    input  logic [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  logic                   s_axi_arvalid,
    output logic                   s_axi_arready,

    // AXI Read Data Channel
    output logic [DATA_WIDTH-1:0]  s_axi_rdata,
    output logic [1:0]             s_axi_rresp,
    output logic                   s_axi_rvalid,
    input  logic                   s_axi_rready
);

    // Internal register-bank write signals
    logic                   reg_wr_en;
    logic [ADDR_WIDTH-1:0]  reg_wr_addr;
    logic [DATA_WIDTH-1:0]  reg_wr_data;
    logic [DATA_WIDTH/8-1:0] reg_wr_strb;
    logic                   reg_wr_valid_addr;

    // Internal register-bank read signals
    logic                   reg_rd_en;
    logic [ADDR_WIDTH-1:0]  reg_rd_addr;
    logic [DATA_WIDTH-1:0]  reg_rd_data;
    logic                   reg_rd_valid_addr;

    // AXI write channel
    axi_write_channel #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_write_channel (
        .clk                 (clk),
        .rst_n               (rst_n),

        .s_axi_awaddr        (s_axi_awaddr),
        .s_axi_awvalid       (s_axi_awvalid),
        .s_axi_awready       (s_axi_awready),

        .s_axi_wdata         (s_axi_wdata),
        .s_axi_wstrb         (s_axi_wstrb),
        .s_axi_wvalid        (s_axi_wvalid),
        .s_axi_wready        (s_axi_wready),

        .s_axi_bresp         (s_axi_bresp),
        .s_axi_bvalid        (s_axi_bvalid),
        .s_axi_bready        (s_axi_bready),

        .reg_wr_en           (reg_wr_en),
        .reg_wr_addr         (reg_wr_addr),
        .reg_wr_data         (reg_wr_data),
        .reg_wr_strb         (reg_wr_strb),
        .reg_wr_valid_addr   (reg_wr_valid_addr)
    );

    // AXI read channel
    axi_read_channel #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_read_channel (
        .clk                 (clk),
        .rst_n               (rst_n),

        .s_axi_araddr        (s_axi_araddr),
        .s_axi_arvalid       (s_axi_arvalid),
        .s_axi_arready       (s_axi_arready),

        .s_axi_rdata         (s_axi_rdata),
        .s_axi_rresp         (s_axi_rresp),
        .s_axi_rvalid        (s_axi_rvalid),
        .s_axi_rready        (s_axi_rready),

        .reg_rd_en           (reg_rd_en),
        .reg_rd_addr         (reg_rd_addr),
        .reg_rd_data         (reg_rd_data),
        .reg_rd_valid_addr   (reg_rd_valid_addr)
    );

    // Shared register bank with independent read and write ports
    register_bank #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_REGS   (NUM_REGS)
    ) u_register_bank (
        .clk             (clk),
        .rst_n           (rst_n),

        .wr_en           (reg_wr_en),
        .wr_addr         (reg_wr_addr),
        .wr_data         (reg_wr_data),
        .wr_strb         (reg_wr_strb),

        .rd_en           (reg_rd_en),
        .rd_addr         (reg_rd_addr),
        .rd_data         (reg_rd_data),

        .wr_valid_addr   (reg_wr_valid_addr),
        .rd_valid_addr   (reg_rd_valid_addr)
    );

endmodule
