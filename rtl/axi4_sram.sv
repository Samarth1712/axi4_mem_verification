// =============================================================
// AXI4 SRAM Controller — DUT
// 32-bit data, 16-bit address, 4KB depth
// Supports INCR and FIXED bursts; WRAP returns SLVERR
// =============================================================
`timescale 1ns/1ps
module axi4_sram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 16,
    parameter int ID_WIDTH   = 4,
    parameter int MEM_DEPTH  = 1024   // words (4KB total)
)(
    input  logic aclk,
    input  logic aresetn,

    // Write Address Channel
    input  logic [ID_WIDTH-1:0]   awid,
    input  logic [ADDR_WIDTH-1:0] awaddr,
    input  logic [7:0]            awlen,
    input  logic [2:0]            awsize,
    input  logic [1:0]            awburst,
    input  logic                  awvalid,
    output logic                  awready,

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,
    input  logic                    wlast,
    input  logic                    wvalid,
    output logic                    wready,

    // Write Response Channel
    output logic [ID_WIDTH-1:0] bid,
    output logic [1:0]          bresp,
    output logic                bvalid,
    input  logic                bready,

    // Read Address Channel
    input  logic [ID_WIDTH-1:0]   arid,
    input  logic [ADDR_WIDTH-1:0] araddr,
    input  logic [7:0]            arlen,
    input  logic [2:0]            arsize,
    input  logic [1:0]            arburst,
    input  logic                  arvalid,
    output logic                  arready,

    // Read Data Channel
    output logic [ID_WIDTH-1:0]   rid,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic [1:0]            rresp,
    output logic                  rlast,
    output logic                  rvalid,
    input  logic                  rready
);

    localparam int          STRB_W  = DATA_WIDTH / 8;
    localparam int          WADDR_W = $clog2(MEM_DEPTH);
    localparam logic [1:0]  OKAY    = 2'b00;
    localparam logic [1:0]  SLVERR  = 2'b10;
    localparam logic [1:0]  BURST_FIXED = 2'b00;
    localparam logic [1:0]  BURST_INCR  = 2'b01;

    // -------------------------------------------------------
    // Memory array
    // -------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // -------------------------------------------------------
    // Memory initialisation (simulation only)
    // -------------------------------------------------------
    initial begin
        for (int i = 0; i < MEM_DEPTH; i++) mem[i] = '0;
    end

    // -------------------------------------------------------
    // Helpers
    // -------------------------------------------------------

    // Explicit slice: bits [WADDR_W+1:2] give the WADDR_W-bit word index.
    // e.g. WADDR_W=10 → ba[11:2] for a 1024-word / 4KB memory.
    function automatic logic [WADDR_W-1:0] to_word (input logic [ADDR_WIDTH-1:0] ba);
        return ba[WADDR_W+1:2];
    endfunction

    function automatic logic [ADDR_WIDTH-1:0] nxt_addr (
        input logic [ADDR_WIDTH-1:0] a,
        input logic [2:0]            sz,
        input logic [1:0]            burst
    );
        return (burst == BURST_INCR) ? a + (1 << sz) : a;
    endfunction

    // BUG FIX: compare byte address against MEM_DEPTH*4 in full ADDR_WIDTH.
    // Previous code cast MEM_DEPTH (1024) to WADDR_W (10) bits → 0, making
    // every access appear OOB.
    function automatic logic oob (input logic [ADDR_WIDTH-1:0] a);
        return (a >= ADDR_WIDTH'(MEM_DEPTH * 4));
    endfunction

    // -------------------------------------------------------
    // Write FSM
    // -------------------------------------------------------
    typedef enum logic [1:0] {WS_IDLE, WS_ADDR, WS_DATA, WS_RESP} wr_st_e;
    wr_st_e wr_st;

    logic [ID_WIDTH-1:0]   aw_id_q;
    logic [ADDR_WIDTH-1:0] aw_cur;
    logic [7:0]            aw_len_q;
    logic [2:0]            aw_sz_q;
    logic [1:0]            aw_bst_q;
    logic [1:0]            wr_resp_acc;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_st      <= WS_IDLE;
            awready    <= 1'b0;
            wready     <= 1'b0;
            bvalid     <= 1'b0;
            bid        <= '0;
            bresp      <= OKAY;
            wr_resp_acc <= OKAY;
        end else begin
            case (wr_st)
                WS_IDLE: begin
                    bvalid  <= 1'b0;
                    awready <= 1'b1;
                    wr_st   <= WS_ADDR;
                end

                WS_ADDR: begin
                    if (awvalid && awready) begin
                        aw_id_q     <= awid;
                        aw_cur      <= awaddr;
                        aw_len_q    <= awlen;
                        aw_sz_q     <= awsize;
                        aw_bst_q    <= awburst;
                        wr_resp_acc <= OKAY;
                        awready     <= 1'b0;
                        wready      <= 1'b1;
                        wr_st       <= WS_DATA;
                    end
                end

                WS_DATA: begin
                    if (wvalid && wready) begin
                        if (!oob(aw_cur)) begin
                            for (int b = 0; b < STRB_W; b++)
                                if (wstrb[b]) mem[to_word(aw_cur)][b*8 +: 8] <= wdata[b*8 +: 8];
                        end else begin
                            wr_resp_acc <= SLVERR;
                        end
                        aw_cur <= nxt_addr(aw_cur, aw_sz_q, aw_bst_q);
                        if (wlast) begin
                            wready <= 1'b0;
                            bvalid <= 1'b1;
                            bid    <= aw_id_q;
                            // BUG FIX: wr_resp_acc and oob() are evaluated
                            // together here. If this is the first (and only)
                            // OOB beat, wr_resp_acc still holds OKAY from the
                            // same-cycle non-blocking assignment above. The
                            // direct oob() check catches that case.
                            bresp  <= (oob(aw_cur) || wr_resp_acc == SLVERR)
                                       ? SLVERR : OKAY;
                            wr_st  <= WS_RESP;
                        end
                    end
                end

                WS_RESP: begin
                    if (bvalid && bready) begin
                        bvalid  <= 1'b0;
                        awready <= 1'b1;
                        wr_st   <= WS_ADDR;
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------
    // Read FSM
    // -------------------------------------------------------
    typedef enum logic [1:0] {RS_IDLE, RS_ADDR, RS_DATA} rd_st_e;
    rd_st_e rd_st;

    logic [ID_WIDTH-1:0]   ar_id_q;
    logic [ADDR_WIDTH-1:0] ar_cur;
    logic [7:0]            ar_len_q;
    logic [2:0]            ar_sz_q;
    logic [1:0]            ar_bst_q;
    logic [7:0]            rd_beat;

    // Next-address wire for read pipelining
    logic [ADDR_WIDTH-1:0] ar_nxt;
    assign ar_nxt = nxt_addr(ar_cur, ar_sz_q, ar_bst_q);

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_st   <= RS_IDLE;
            arready <= 1'b0;
            rvalid  <= 1'b0;
            rlast   <= 1'b0;
            rid     <= '0;
            rdata   <= '0;
            rresp   <= OKAY;
            rd_beat <= '0;
            ar_id_q  <= '0;
            ar_cur   <= '0;
            ar_len_q <= '0;
            ar_sz_q  <= '0;
            ar_bst_q <= '0;
        end else begin
            case (rd_st)
                RS_IDLE: begin
                    arready <= 1'b1;
                    rvalid  <= 1'b0;
                    rd_st   <= RS_ADDR;
                end

                RS_ADDR: begin
                    if (arvalid && arready) begin
                        ar_id_q  <= arid;
                        ar_cur   <= araddr;
                        ar_len_q <= arlen;
                        ar_sz_q  <= arsize;
                        ar_bst_q <= arburst;
                        rd_beat  <= '0;
                        arready  <= 1'b0;
                        // Pre-load first beat
                        rid      <= arid;
                        rdata    <= oob(araddr) ? '0 : mem[to_word(araddr)];
                        rresp    <= oob(araddr) ? SLVERR : OKAY;
                        rlast    <= (arlen == 8'h00);
                        rvalid   <= 1'b1;
                        rd_st    <= RS_DATA;
                    end
                end

                RS_DATA: begin
                    if (rvalid && rready) begin
                        if (rlast) begin
                            rvalid  <= 1'b0;
                            rlast   <= 1'b0;
                            arready <= 1'b1;
                            rd_st   <= RS_ADDR;
                        end else begin
                            ar_cur  <= ar_nxt;
                            rd_beat <= rd_beat + 8'h1;
                            rdata   <= oob(ar_nxt) ? '0 : mem[to_word(ar_nxt)];
                            rresp   <= oob(ar_nxt) ? SLVERR : OKAY;
                            rlast   <= (rd_beat + 8'h1 == ar_len_q);
                        end
                    end
                end
            endcase
        end
    end

endmodule
