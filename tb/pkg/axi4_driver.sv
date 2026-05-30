// =============================================================
// AXI4 UVM Driver
// Drives sequence items onto the AXI4 interface via clocking block
// =============================================================
class axi4_driver extends uvm_driver #(axi4_seq_item);
    `uvm_component_utils(axi4_driver)

    virtual axi4_if.DRIVER vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual axi4_if.DRIVER)::get(this, "", "vif", vif))
            `uvm_fatal("CFG", "axi4_driver: vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        axi4_seq_item item;
        // Idle all master outputs
        drive_idle();
        // Wait for reset release
        @(posedge vif.aclk iff vif.aresetn);
        repeat(2) @(vif.driver_cb);

        forever begin
            seq_item_port.get_next_item(item);
            `uvm_info("DRV", $sformatf("Driving: %s", item.convert2string()), UVM_MEDIUM)
            if (item.is_write)
                drive_write(item);
            else
                drive_read(item);
            seq_item_port.item_done();
        end
    endtask

    // -----------------------------------------------------------
    // Drive idle (all valids low)
    // -----------------------------------------------------------
    task drive_idle();
        vif.driver_cb.awvalid <= 0;
        vif.driver_cb.wvalid  <= 0;
        vif.driver_cb.bready  <= 0;
        vif.driver_cb.arvalid <= 0;
        vif.driver_cb.rready  <= 0;
        vif.driver_cb.awid    <= 0;
        vif.driver_cb.awaddr  <= 0;
        vif.driver_cb.awlen   <= 0;
        vif.driver_cb.awsize  <= 0;
        vif.driver_cb.awburst <= 0;
        vif.driver_cb.wdata   <= 0;
        vif.driver_cb.wstrb   <= 0;
        vif.driver_cb.wlast   <= 0;
        vif.driver_cb.arid    <= 0;
        vif.driver_cb.araddr  <= 0;
        vif.driver_cb.arlen   <= 0;
        vif.driver_cb.arsize  <= 0;
        vif.driver_cb.arburst <= 0;
    endtask

    // -----------------------------------------------------------
    // Write transaction: AW + W channels, then wait B
    // -----------------------------------------------------------
    task drive_write(axi4_seq_item item);
        // --- Write Address Channel ---
        vif.driver_cb.awid    <= item.id;
        vif.driver_cb.awaddr  <= item.addr;
        vif.driver_cb.awlen   <= item.burst_len;
        vif.driver_cb.awsize  <= item.burst_size;
        vif.driver_cb.awburst <= item.burst_type;
        vif.driver_cb.awvalid <= 1;
        @(vif.driver_cb iff vif.driver_cb.awready);
        vif.driver_cb.awvalid <= 0;

        // --- Write Data Channel ---
        for (int i = 0; i <= item.burst_len; i++) begin
            vif.driver_cb.wdata  <= item.wdata[i];
            vif.driver_cb.wstrb  <= item.wstrb[i];
            vif.driver_cb.wlast  <= (i == item.burst_len);
            vif.driver_cb.wvalid <= 1;
            @(vif.driver_cb iff vif.driver_cb.wready);
        end
        vif.driver_cb.wvalid <= 0;
        vif.driver_cb.wlast  <= 0;

        // --- Write Response ---
        vif.driver_cb.bready <= 1;
        @(vif.driver_cb iff vif.driver_cb.bvalid);
        item.bresp = vif.driver_cb.bresp;
        @(vif.driver_cb);
        vif.driver_cb.bready <= 0;
    endtask

    // -----------------------------------------------------------
    // Read transaction: AR channel, then collect R beats
    // -----------------------------------------------------------
    task drive_read(axi4_seq_item item);
        item.rdata = new[item.burst_len + 1];
        item.rresp = new[item.burst_len + 1];

        // --- Read Address Channel ---
        vif.driver_cb.arid    <= item.id;
        vif.driver_cb.araddr  <= item.addr;
        vif.driver_cb.arlen   <= item.burst_len;
        vif.driver_cb.arsize  <= item.burst_size;
        vif.driver_cb.arburst <= item.burst_type;
        vif.driver_cb.arvalid <= 1;
        @(vif.driver_cb iff vif.driver_cb.arready);
        vif.driver_cb.arvalid <= 0;

        // --- Read Data Channel ---
        vif.driver_cb.rready <= 1;
        for (int i = 0; i <= item.burst_len; i++) begin
            @(vif.driver_cb iff vif.driver_cb.rvalid);
            item.rdata[i] = vif.driver_cb.rdata;
            item.rresp[i] = vif.driver_cb.rresp;
        end
        @(vif.driver_cb);
        vif.driver_cb.rready <= 0;
    endtask

endclass : axi4_driver
