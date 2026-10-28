
module axi_read_channel #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // AXI Read Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,

    // AXI Read Data Channel
    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready,

    // Register-bank read interface
    output logic                  reg_rd_en,
    output logic [ADDR_WIDTH-1:0] reg_rd_addr,
    input  logic [DATA_WIDTH-1:0] reg_rd_data,
    input  logic                  reg_rd_valid_addr
);

    localparam logic [1:0] AXI_RESP_OKAY  = 2'b00;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

    logic [DATA_WIDTH-1:0] rdata_reg;
    logic [1:0]            rresp_reg;

    logic ar_handshake;

    // Permit one outstanding read transaction.
    assign s_axi_arready = !s_axi_rvalid;

    assign ar_handshake =
        s_axi_arvalid && s_axi_arready;

    // Drive the register bank for the accepted address.
    assign reg_rd_en   = ar_handshake;
    assign reg_rd_addr = s_axi_araddr;

    // Keep the response stable until the master accepts it.
    assign s_axi_rdata = rdata_reg;
    assign s_axi_rresp = rresp_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_reg    <= '0;
            rresp_reg    <= AXI_RESP_OKAY;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (ar_handshake) begin
                s_axi_rvalid <= 1'b1;

                if (reg_rd_valid_addr) begin
                    rdata_reg <= reg_rd_data;
                    rresp_reg <= AXI_RESP_OKAY;
                end else begin
                    rdata_reg <= '0;
                    rresp_reg <= AXI_RESP_SLVERR;
                end
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
