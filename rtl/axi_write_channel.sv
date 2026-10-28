
module axi_write_channel #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst_n,

    // AXI Write Address Channel
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,

    // AXI Write Data Channel
    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,

    // AXI Write Response Channel
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,

    // Register bank interface
    output logic                    reg_wr_en,
    output logic [ADDR_WIDTH-1:0]   reg_wr_addr,
    output logic [DATA_WIDTH-1:0]   reg_wr_data,
    output logic [DATA_WIDTH/8-1:0] reg_wr_strb,
    input  logic                    reg_wr_valid_addr
);

    localparam logic [1:0] AXI_RESP_OKAY  = 2'b00;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

    logic [ADDR_WIDTH-1:0]    awaddr_reg;
    logic [DATA_WIDTH-1:0]    wdata_reg;
    logic [DATA_WIDTH/8-1:0]  wstrb_reg;

    logic aw_pending;
    logic w_pending;
    logic response_pending;

    logic aw_handshake;
    logic w_handshake;
    logic write_commit;

    logic [1:0] bresp_reg;

    // Accept one address and one data beat independently.
    assign s_axi_awready = !aw_pending && !response_pending;
    assign s_axi_wready  = !w_pending  && !response_pending;

    assign aw_handshake = s_axi_awvalid && s_axi_awready;
    assign w_handshake  = s_axi_wvalid  && s_axi_wready;

    // Commit when both the address and data are available.
    assign write_commit =
        !response_pending &&
        (aw_pending || aw_handshake) &&
        (w_pending  || w_handshake);

    // Select buffered values or values arriving this cycle.
    always_comb begin
        reg_wr_addr = aw_pending ? awaddr_reg : s_axi_awaddr;
        reg_wr_data = w_pending  ? wdata_reg  : s_axi_wdata;
        reg_wr_strb = w_pending  ? wstrb_reg  : s_axi_wstrb;

        reg_wr_en = write_commit && reg_wr_valid_addr;

        s_axi_bresp = bresp_reg;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awaddr_reg       <= '0;
            wdata_reg        <= '0;
            wstrb_reg        <= '0;
            aw_pending       <= 1'b0;
            w_pending        <= 1'b0;
            response_pending <= 1'b0;
            bresp_reg        <= AXI_RESP_OKAY;
            s_axi_bvalid     <= 1'b0;
        end else begin
            // Capture the address whenever AW handshakes.
            if (aw_handshake) begin
                awaddr_reg <= s_axi_awaddr;
                aw_pending <= 1'b1;
            end

            // Capture write data and strobes independently.
            if (w_handshake) begin
                wdata_reg <= s_axi_wdata;
                wstrb_reg <= s_axi_wstrb;
                w_pending <= 1'b1;
            end

            // Once both parts are available, issue a response.
            if (write_commit) begin
                aw_pending       <= 1'b0;
                w_pending        <= 1'b0;
                response_pending <= 1'b1;
                s_axi_bvalid     <= 1'b1;

                if (reg_wr_valid_addr)
                    bresp_reg <= AXI_RESP_OKAY;
                else
                    bresp_reg <= AXI_RESP_SLVERR;
            end

            // Keep BVALID and BRESP stable until accepted.
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid     <= 1'b0;
                response_pending <= 1'b0;
            end
        end
    end


endmodule
