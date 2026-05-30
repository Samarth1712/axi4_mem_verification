// =============================================================
// Top-level Testbench
// Instantiates DUT, interface, clock gen, UVM kickoff
// =============================================================
`timescale 1ns/1ps

// Pull in UVM and the package before the module
import uvm_pkg::*;
`include "uvm_macros.svh"
import axi4_pkg::*;

// Include all TB classes (kept as `includes for Xcelium compatibility)
`include "axi4_driver.sv"
`include "axi4_monitor.sv"
`include "axi4_scoreboard.sv"
`include "axi4_agent_env.sv"
`include "axi4_sequences.sv"
`include "axi4_tests.sv"

module tb_top;

    // -----------------------------------------------------------
    // Clock and reset
    // -----------------------------------------------------------
    logic aclk    = 0;
    logic aresetn = 0;

    always #5 aclk = ~aclk;   // 100 MHz

    initial begin
        aresetn = 0;
        repeat(10) @(posedge aclk);
        aresetn = 1;
    end

    // -----------------------------------------------------------
    // Interface
    // -----------------------------------------------------------
    axi4_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH  (ID_WIDTH)
    ) axi_if (
        .aclk   (aclk),
        .aresetn(aresetn)
    );

    // -----------------------------------------------------------
    // DUT
    // -----------------------------------------------------------
    axi4_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH  (ID_WIDTH),
        .MEM_DEPTH (MEM_DEPTH)
    ) dut (
        .aclk    (aclk),
        .aresetn (aresetn),

        .awid    (axi_if.awid),
        .awaddr  (axi_if.awaddr),
        .awlen   (axi_if.awlen),
        .awsize  (axi_if.awsize),
        .awburst (axi_if.awburst),
        .awvalid (axi_if.awvalid),
        .awready (axi_if.awready),

        .wdata   (axi_if.wdata),
        .wstrb   (axi_if.wstrb),
        .wlast   (axi_if.wlast),
        .wvalid  (axi_if.wvalid),
        .wready  (axi_if.wready),

        .bid     (axi_if.bid),
        .bresp   (axi_if.bresp),
        .bvalid  (axi_if.bvalid),
        .bready  (axi_if.bready),

        .arid    (axi_if.arid),
        .araddr  (axi_if.araddr),
        .arlen   (axi_if.arlen),
        .arsize  (axi_if.arsize),
        .arburst (axi_if.arburst),
        .arvalid (axi_if.arvalid),
        .arready (axi_if.arready),

        .rid     (axi_if.rid),
        .rdata   (axi_if.rdata),
        .rresp   (axi_if.rresp),
        .rlast   (axi_if.rlast),
        .rvalid  (axi_if.rvalid),
        .rready  (axi_if.rready)
    );

    // -----------------------------------------------------------
    // UVM config_db: push interface to driver and monitor
    // -----------------------------------------------------------
    initial begin
        uvm_config_db #(virtual axi4_if.DRIVER) ::set(
            null, "uvm_test_top.env.agent.driver",    "vif", axi_if);
        uvm_config_db #(virtual axi4_if.MONITOR)::set(
            null, "uvm_test_top.env.agent.monitor",   "vif", axi_if);
        run_test();   // test name passed via +UVM_TESTNAME
    end

    // -----------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------
    initial begin
        $shm_open("waves.shm");
        $shm_probe("AS");
    end

    // -----------------------------------------------------------
    // Timeout watchdog
    // -----------------------------------------------------------
    initial begin
        #2_000_000;
        `uvm_fatal("TIMEOUT", "Simulation timeout — possible hang")
    end

endmodule
