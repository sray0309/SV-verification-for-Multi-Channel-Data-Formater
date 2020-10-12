`include "param_def.v"

package mcdf_pkg;

    import chnl_pkg::*;
    import reg_pkg::*;
    import fmt_pkg::*;
    import rpt_pkg::*;

    typedef struct packed{
        bit[2:0] len;
        bit[1:0] prio;
        bit en;
        bit[7:0] avail;
    } mcdf_reg_t;

    typedef enum {RW_LEN, RW_PRIO, RW_EN, RD_AVAIL} mcdf_field_t;

    class mcdf_refmod;
        local virtual mcdf_intf intf;
        local string name;
        mcdf_reg_t regs[3];
        mailbox #(reg_trans) reg_mb;
        mailbox #(mon_data_t) in_mbs[3];
        mailbox #(fmt_trans) out_mbs[3];

        function new(string name="mcdf_refmod");
            this.name = name;
            foreach (this.out_mbs[i]) this.out_mbs[i] = new();
        endfunction

        task run();
            fork
                do_reset();
                this.do_reg_update();
                do_packet(0);
                do_packet(1);
                do_packet(2);
            join
        endtask

        task do_reg_update();
            reg_trans t;
            forever begin
                this.reg_mb.get(t);
                if (t.addr[7:4] == 0 && t.cmd = `WRITE) begin
                    this.regs[t.addr[3:2]].en = t.data[0];
                    this.regs[t.addr[3:2]].prio = t.data[2:1];
                    this.regs[t.addr[3:2]].len = t.data[5:3];
                end
                else if(t.addr[7:4] == 1 && t.cmd = `READ) begin
                    this.regs[t.addr[3:2]].avail = t.data[7:0];
                end
            end
        endtask

        task do_packet(int id);
            fmt_trans ot;
            mon_data_t it;
            forever begin
                this.in_mbs[id].peek(it);
                ot = new();
                ot.length = 4 << (this.get_field_value(id, RW_LEN) & 'b11);
                ot.data = new[ot.length];
                ot.ch_id = id;
                foreach(ot.data[m]) begin
                    this.in_mbs[id].get(it);
                    ot.data[m] = it.data;
                end
                this.out_mbs[id].put(ot);
            end
        endtask

        function int get_field_value(int id, mcdf_field_t f);
            case(f)
                RW_LEN: return regs[id].len;
                RW_PRIO: return regs[id].prio;
                RW_EN: return regs[id].en;
                RW_AVAIL: return regs[id].avail;
            endcase
        endfunction

    endclass


endpackage