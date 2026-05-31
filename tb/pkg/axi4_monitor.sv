// =============================================================
// AXI4 UVM Monitor
// Passively observes the bus and broadcasts completed transactions
// =============================================================
class axi4_monitor extends uvm_monitor;
    `uvm_component_utils(axi4_monitor)

    virtual axi4_if.MONITOR vif;

    // Analysis port — connects to scoreboard and coverage
    uvm_analysis_port #(axi4_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual axi4_if.MONITOR)::get(this, "", "vif", vif))
            `uvm_fatal("CFG", "axi4_monitor: vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.aclk iff vif.aresetn);
        // join_none: parent returns immediately; UVM phase controller
        // kills both threads when all objections are dropped.
        // join (blocking) would prevent the phase from ending cleanly.
        fork
            monitor_write();
            monitor_read();
        join_none
    endtask

    // -----------------------------------------------------------
    // Capture a completed write transaction
    // -----------------------------------------------------------
    task monitor_write();
        forever begin
            axi4_seq_item item;
            item          = axi4_seq_item::type_id::create("mon_wr");
            item.is_write = 1;

            // Capture AW channel
            @(vif.monitor_cb iff (vif.monitor_cb.awvalid && vif.monitor_cb.awready));
            item.id         = vif.monitor_cb.awid;
            item.addr       = vif.monitor_cb.awaddr;
            item.burst_len  = vif.monitor_cb.awlen;
            item.burst_size = vif.monitor_cb.awsize;
            item.burst_type = burst_t'(vif.monitor_cb.awburst);

            // Capture W beats
            item.wdata = new[item.burst_len + 1];
            item.wstrb = new[item.burst_len + 1];
            for (int i = 0; i <= item.burst_len; i++) begin
                @(vif.monitor_cb iff (vif.monitor_cb.wvalid && vif.monitor_cb.wready));
                item.wdata[i] = vif.monitor_cb.wdata;
                item.wstrb[i] = vif.monitor_cb.wstrb;
            end

            // Capture B channel
            @(vif.monitor_cb iff (vif.monitor_cb.bvalid && vif.monitor_cb.bready));
            item.bresp = vif.monitor_cb.bresp;

            `uvm_info("MON", $sformatf("Write observed: %s bresp=%0h",
                item.convert2string(), item.bresp), UVM_HIGH)
            ap.write(item);
        end
    endtask

    // -----------------------------------------------------------
    // Capture a completed read transaction
    // -----------------------------------------------------------
    task monitor_read();
        forever begin
            axi4_seq_item item;
            item          = axi4_seq_item::type_id::create("mon_rd");
            item.is_write = 0;

            // Capture AR channel
            @(vif.monitor_cb iff (vif.monitor_cb.arvalid && vif.monitor_cb.arready));
            item.id         = vif.monitor_cb.arid;
            item.addr       = vif.monitor_cb.araddr;
            item.burst_len  = vif.monitor_cb.arlen;
            item.burst_size = vif.monitor_cb.arsize;
            item.burst_type = burst_t'(vif.monitor_cb.arburst);

            // Capture R beats
            item.rdata = new[item.burst_len + 1];
            item.rresp = new[item.burst_len + 1];
            for (int i = 0; i <= item.burst_len; i++) begin
                @(vif.monitor_cb iff (vif.monitor_cb.rvalid && vif.monitor_cb.rready));
                item.rdata[i] = vif.monitor_cb.rdata;
                item.rresp[i] = vif.monitor_cb.rresp;
            end

            `uvm_info("MON", $sformatf("Read observed: %s rdata[0]=%0h",
                item.convert2string(), item.rdata[0]), UVM_HIGH)
            ap.write(item);
        end
    endtask

endclass : axi4_monitor
