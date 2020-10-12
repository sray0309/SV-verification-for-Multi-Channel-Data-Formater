package chnl_pkg;

class chnl_trans;
    rand bit [31:0]  data[];
    rand int         ch_id;
    rand int         pkt_id;
    rand int         data_nidles;
    rand int         pkt_nidles;
    bit              rsp;

    constraint cstr{
        soft data.size inside {[4:32]};
        foreach (data[i]) data[i] == 'hc000_0000 + (this.ch_id << 24) + (this.pkt_id << 8) +i;
        soft ch_id == 0;
        soft pkt_id == 0;
        soft data_nidles inside {[0:2]};
        soft pkt_nidles inside {[1:10]};
    };

    function chnl_trans clone();
        chnl_trans c = new();
        c.data = this.data;
        c.ch_id = this.ch_id;
        c.pkt_id = this.pkt_id;
        c.data_nidles = this.data_nidles;
        c.pkt_nidles = this.pkt_nidles;
        c.rsp = this.rsp;
        return c;
    endfunction

    function string sprint();
        string s;
        s = {s, $sformatf("=======================================\n")};
        s = {s, $sformatf("chnl_trans object content is as below: \n")};
        foreach(data[i]) s = {s, $sformatf("data[%0d] = %8x \n", i, this.data[i])};
        s = {s, $sformatf("ch_id = %0d: \n", this.ch_id)};
        s = {s, $sformatf("pkt_id = %0d: \n", this.pkt_id)};
        s = {s, $sformatf("data_nidles = %0d: \n", this.data_nidles)};
        s = {s, $sformatf("pkt_nidles = %0d: \n", this.pkt_nidles)};
        s = {s, $sformatf("rsp = %0d: \n", this.rsp)};
        s = {s, $sformatf("=======================================\n")};
        return s;
    endfunction
endclass: chnl_trans

class chnl_driver;
    local string name;
    local virtual chnl_intf intf;
    mailbox #(chnl_trans) req_mb;
    mailbox #(chnl_trans) rsp_mb;

    function new(string name = "chnl_driver");
        this.name = name;
    endfunction

    function void set_interface(virtual chnl_intf intf);
        if(intf == null)
            $error("interface handle is NULL, please check if target interface has been intantiated");
        else this.intf = intf;
    endfunction

    task do_reset();
        forever begin
        @(negedge intf.rstn);
            intf.ch_valid <= 0;
            intf.ch_data <= 0;
        end
    endtask:do_reset

    task do_drive();
        chnl_trans rsp, req;
        @(posedge intf.rstn);
        forever begin
            this.req_mb.get(req);
            this.chnl_write(req);
            rsp = req.clone();
            rsp.rsp=1;
            this.rsp_mb.put(rsp);
        end
    endtask:do_drive

    task chnl_write(input chnl_trans t);
        foreach (t.data[i]) begin
            @(posedge intf.clk);
            intf.drv_ck.ch_valid <= 1;
            intf.drv_ck.ch_data <= t.data[i];
            @(negedge intf.clk);
            wait(intf.drv_ck.ch_ready === 'b1);
            $display("%0t channel driver [%s] sent data %x", $time, name, t.data[i]);
            repeat(t.data_nidles) this.chnl_idle();
        end
        repeat (t.pkt_nidles) this.chnl_idle();
    endtask:chnl_write

    task chnl_idle();
        @(posedge intf.clk);
        intf.drv_ck.ch_valid <= 0;
        intf.drv_ck.ch_data <= 'b0;
    endtask:chnl_idle

    task run();
        fork
            this.do_reset();
            this.do_drive();
        join
    endtask:run

endclass:chnl_driver

class chnl_generator;
    rand bit pkt_id = 0;
    rand bit ch_id = -1;
    rand bit data_nidles = -1;
    rand bit pkt_nidles = -1;
    rand bit data_size = -1;
    rand bit ntrans = 10;

    constraint cstr{
        soft pkt_id == 0;
        soft ch_id == -1;
        soft data_nidles == -1;
        soft pkt_nidles == -1;
        soft data_size == -1;
        soft ntrans == 10;
    };
 
    mailbox #(chnl_trans) req_mb;
    mailbox #(chnl_trans) rsp_mb;

    function new();
        req_mb = new();
        rsp_mb = new();
    endfunction

    task start();
        repeat(ntrans) send_tran();
    endtask:start

    task send_tran();
        chnl_trans req, rsp;
        req=new();
        assert (req.randomize() with {
            local::ch_id >= 0 -> ch_id == local::ch_id;
            local::pkt_id >= 0 -> pkt_id == local::pkt_id;
            local::data_nidles >= 0 -> data_nidles == local::data_nidles;
            local::pkt_nidles >= 0 -> pkt_nidles == local::pkt_nidles;
            local::data_size >= 0 -> data.size() == local::data_size;
        })
        else $fatal("[RNDFAIL] channel packet randomization failure!");

    endtask:send_tran

endclass: chnl_generator

typedef struct packed {
    bit [31:0] data;
    bit [1:0]  id;
} mon_data_t;

class chnl_monitor;
    local string name;
    local virtual chnl_intf intf;
    mailbox #(mon_data_t) mon_mb;

    function new(string name="chnl_moniter");
        this.name = name;
    endfunction

    function set_interface(virtual chnl_intf intf);
        this.intf = intf;
    endfunction

    task mon_trans;
        mon_data_t m;
        forever begin
            @(posedge intf.clk iff (intf.mon_ck.ch_ready===1'b1 && intf.mon_ck.ch_valid===1'b1))
            m.data = intf.mon_ck.ch_data;
            mon_mb.put(m);
            $display("%0t %s monitored channle data %8x", $time, this.name, m.data);
        end
    endtask

    task run;
        this.mon_trans();
    endtask

endclass: chnl_monitor

class chnl_agent;
    local string name;
    chnl_driver driver;
    chnl_monitor monitor;
    local virtual chnl_intf intf;

    function new(string name="chnl_agent");
        this.name = name;
        this.driver = new({name,".driver"});
        this.monitor = new({name,".monitor"});
    endfunction

    function void set_interface(virtual chnl_intf intf);
        this.intf = intf;
        this.driver.set_interface(intf);
        this.monitor.set_interface(intf);
    endfunction

    task run();
        fork
            this.driver.run();
            this.monitor.run();
        join
    endtask

endclass: chnl_agent

endpackage