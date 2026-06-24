// =============================================================
// AXI4 Interface + SVA Protocol Assertions
// =============================================================
`timescale 1ns/1ps
interface axi4_if #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 16,
    parameter int ID_WIDTH   = 4
)(
    input logic aclk,
    input logic aresetn
);

    localparam int STRB_W = DATA_WIDTH / 8;

    // Write Address Channel
    logic [ID_WIDTH-1:0]   awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;
    logic [2:0]            awsize;
    logic [1:0]            awburst;
    logic                  awvalid;
    logic                  awready;

    // Write Data Channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [STRB_W-1:0]     wstrb;
    logic                  wlast;
    logic                  wvalid;
    logic                  wready;

    // Write Response Channel
    logic [ID_WIDTH-1:0] bid;
    logic [1:0]          bresp;
    logic                bvalid;
    logic                bready;

    // Read Address Channel
    logic [ID_WIDTH-1:0]   arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic                  arvalid;
    logic                  arready;

    // Read Data Channel
    logic [ID_WIDTH-1:0]   rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rlast;
    logic                  rvalid;
    logic                  rready;

    // -----------------------------------------------------------
    // Clocking blocks (UVM driver and monitor use these)
    // -----------------------------------------------------------
    clocking driver_cb @(posedge aclk);
        default input #1step output #1;
        // Master drives these
        output awid, awaddr, awlen, awsize, awburst, awvalid;
        output wdata, wstrb, wlast, wvalid;
        output bready;
        output arid, araddr, arlen, arsize, arburst, arvalid;
        output rready;
        // Master reads these
        input  awready;
        input  wready;
        input  bid, bresp, bvalid;
        input  arready;
        input  rid, rdata, rresp, rlast, rvalid;
    endclocking

    clocking monitor_cb @(posedge aclk);
        default input #1step;
        input awid, awaddr, awlen, awsize, awburst, awvalid, awready;
        input wdata, wstrb, wlast, wvalid, wready;
        input bid, bresp, bvalid, bready;
        input arid, araddr, arlen, arsize, arburst, arvalid, arready;
        input rid, rdata, rresp, rlast, rvalid, rready;
    endclocking

    modport DRIVER  (clocking driver_cb,  input aclk, aresetn);
    modport MONITOR (clocking monitor_cb, input aclk, aresetn);

    // -----------------------------------------------------------
    // SVA — AXI4 Protocol Assertions
    // -----------------------------------------------------------

    // --- Reset: all valid signals must be deasserted ---
    property p_reset_awvalid;
        @(posedge aclk) !aresetn |-> !awvalid;
    endproperty

    property p_reset_wvalid;
        @(posedge aclk) !aresetn |-> !wvalid;
    endproperty

    property p_reset_arvalid;
        @(posedge aclk) !aresetn |-> !arvalid;
    endproperty

    property p_reset_bvalid;
        @(posedge aclk) !aresetn |-> !bvalid;
    endproperty

    property p_reset_rvalid;
        @(posedge aclk) !aresetn |-> !rvalid;
    endproperty

    // --- Handshake stability: valid must not drop until ready ---
    // AXI4 spec: once asserted, VALID stays high until READY seen

    property p_awvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> awvalid;
    endproperty

    property p_awaddr_stable;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> $stable(awaddr);
    endproperty

    property p_awid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> $stable(awid);
    endproperty

    property p_awlen_stable;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> $stable(awlen);
    endproperty

    property p_wvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> wvalid;
    endproperty

    property p_wdata_stable;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> $stable(wdata);
    endproperty

    property p_wstrb_stable;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> $stable(wstrb);
    endproperty

    property p_wlast_stable;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> $stable(wlast);
    endproperty

    property p_arvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> arvalid;
    endproperty

    property p_araddr_stable;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> $stable(araddr);
    endproperty

    property p_bvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> bvalid;
    endproperty

    property p_bresp_stable;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> $stable(bresp);
    endproperty

    property p_rvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> rvalid;
    endproperty

    property p_rdata_stable;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> $stable(rdata);
    endproperty

    property p_rlast_stable;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> $stable(rlast);
    endproperty

    // --- RESP values must be valid (only 00=OKAY and 10=SLVERR used) ---
    property p_bresp_valid;
        @(posedge aclk) disable iff (!aresetn)
        bvalid |-> bresp inside {2'b00, 2'b10};
    endproperty

    property p_rresp_valid;
        @(posedge aclk) disable iff (!aresetn)
        rvalid |-> rresp inside {2'b00, 2'b10};
    endproperty

    // --- WSTRB: must not have X/Z ---
    property p_wstrb_no_x;
        @(posedge aclk) disable iff (!aresetn)
        wvalid |-> !$isunknown(wstrb);
    endproperty

    // --- No X on valid address when AWVALID ---
    property p_awaddr_no_x;
        @(posedge aclk) disable iff (!aresetn)
        awvalid |-> !$isunknown(awaddr);
    endproperty

    property p_araddr_no_x;
        @(posedge aclk) disable iff (!aresetn)
        arvalid |-> !$isunknown(araddr);
    endproperty

    // --- Burst type must be FIXED or INCR (WRAP not supported) ---
    property p_awburst_legal;
        @(posedge aclk) disable iff (!aresetn)
        awvalid |-> awburst inside {2'b00, 2'b01};
    endproperty

    property p_arburst_legal;
        @(posedge aclk) disable iff (!aresetn)
        arvalid |-> arburst inside {2'b00, 2'b01};
    endproperty

    // --- Size must not exceed bus width (max 2 for 32-bit bus) ---
    property p_awsize_legal;
        @(posedge aclk) disable iff (!aresetn)
        awvalid |-> awsize <= 3'h2;
    endproperty

    property p_arsize_legal;
        @(posedge aclk) disable iff (!aresetn)
        arvalid |-> arsize <= 3'h2;
    endproperty

    // --- Bind assertions ---
    a_reset_awvalid  : assert property (p_reset_awvalid)  else $error("SVA FAIL: awvalid not deasserted during reset");
    a_reset_wvalid   : assert property (p_reset_wvalid)   else $error("SVA FAIL: wvalid not deasserted during reset");
    a_reset_arvalid  : assert property (p_reset_arvalid)  else $error("SVA FAIL: arvalid not deasserted during reset");
    a_reset_bvalid   : assert property (p_reset_bvalid)   else $error("SVA FAIL: bvalid not deasserted during reset");
    a_reset_rvalid   : assert property (p_reset_rvalid)   else $error("SVA FAIL: rvalid not deasserted during reset");

    a_awvalid_stable : assert property (p_awvalid_stable) else $error("SVA FAIL: awvalid dropped before awready");
    a_awaddr_stable  : assert property (p_awaddr_stable)  else $error("SVA FAIL: awaddr changed before handshake");
    a_awid_stable    : assert property (p_awid_stable)    else $error("SVA FAIL: awid changed before handshake");
    a_awlen_stable   : assert property (p_awlen_stable)   else $error("SVA FAIL: awlen changed before handshake");

    a_wvalid_stable  : assert property (p_wvalid_stable)  else $error("SVA FAIL: wvalid dropped before wready");
    a_wdata_stable   : assert property (p_wdata_stable)   else $error("SVA FAIL: wdata changed before handshake");
    a_wstrb_stable   : assert property (p_wstrb_stable)   else $error("SVA FAIL: wstrb changed before handshake");
    a_wlast_stable   : assert property (p_wlast_stable)   else $error("SVA FAIL: wlast changed before handshake");

    a_arvalid_stable : assert property (p_arvalid_stable) else $error("SVA FAIL: arvalid dropped before arready");
    a_araddr_stable  : assert property (p_araddr_stable)  else $error("SVA FAIL: araddr changed before handshake");

    a_bvalid_stable  : assert property (p_bvalid_stable)  else $error("SVA FAIL: bvalid dropped before bready");
    a_bresp_stable   : assert property (p_bresp_stable)   else $error("SVA FAIL: bresp changed before bready");

    a_rvalid_stable  : assert property (p_rvalid_stable)  else $error("SVA FAIL: rvalid dropped before rready");
    a_rdata_stable   : assert property (p_rdata_stable)   else $error("SVA FAIL: rdata changed before rready");
    a_rlast_stable   : assert property (p_rlast_stable)   else $error("SVA FAIL: rlast changed before rready");

    a_bresp_valid    : assert property (p_bresp_valid)    else $error("SVA FAIL: illegal bresp value");
    a_rresp_valid    : assert property (p_rresp_valid)    else $error("SVA FAIL: illegal rresp value");
    a_wstrb_no_x     : assert property (p_wstrb_no_x)     else $error("SVA FAIL: X/Z on wstrb during wvalid");
    a_awaddr_no_x    : assert property (p_awaddr_no_x)    else $error("SVA FAIL: X/Z on awaddr during awvalid");
    a_araddr_no_x    : assert property (p_araddr_no_x)    else $error("SVA FAIL: X/Z on araddr during arvalid");
    a_awburst_legal  : assert property (p_awburst_legal)  else $error("SVA FAIL: unsupported awburst type");
    a_arburst_legal  : assert property (p_arburst_legal)  else $error("SVA FAIL: unsupported arburst type");
    a_awsize_legal   : assert property (p_awsize_legal)   else $error("SVA FAIL: awsize exceeds bus width");
    a_arsize_legal   : assert property (p_arsize_legal)   else $error("SVA FAIL: arsize exceeds bus width");

    // Coverage for assertion firing (good to have in coverage DB)
    c_awvalid_stable : cover property (p_awvalid_stable);
    c_wvalid_stable  : cover property (p_wvalid_stable);
    c_arvalid_stable : cover property (p_arvalid_stable);
    c_bvalid_stable  : cover property (p_bvalid_stable);
    c_rvalid_stable  : cover property (p_rvalid_stable);

endinterface
