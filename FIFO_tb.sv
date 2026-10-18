class Transaction;
    rand bit [7:0] ip;          //For randomizing the values
    rand bit       wrt_en;      //For randomizing the values
    rand bit       rd_en;       //For randomizing the values
    rand bit       rst;         //For asserting reset in the middle of the operation

    logic [7:0] op;
    logic       f;
    logic       e;

    function new (bit [7:0] ip = 0, bit wrt_en = 0, bit rd_en = 0, bit rst = 1);
        this.ip = ip;
        this.wrt_en = wrt_en;
        this.rd_en = rd_en;
        this.rst = rst;
    endfunction

    function void display (string tag = "");        //for labelling each display call by "Driver" or "Monitor"
        $display ("ip = %b, op = %b, rst = %0d, wrt_en = %0d, rd_en = %0d, f = %0d, e = %0d", this.ip, this.op, this.rst, this.wrt_en, this.rd_en, this.f, this.e);
    endfunction

    //Constraints
    constraint c1 {wrt_en dist {0 := 30, 1 := 70};
                    rd_en dist {0 := 70, 1 := 30};}
    //constraint c2 {!(wrt_en && rd_en);}
    constraint c3 {rst dist {0 := 5, 1 := 95};}
endclass

class Generator;
    int num_transactions;
    mailbox #(Transaction) m;

    function new (int num_transactions, mailbox #(Transaction) m);
        this.num_transactions = num_transactions;
        this.m = m;
    endfunction

    task run();
        Transaction t;

        for (int i = 0; i < num_transactions; i++)
        begin
            t = new();
            if (t.randomize())
                m.put(t);
            else
                $display ("Randomization failed");
        end

        /*
        //For reading from the FIFO
        for (int b = 0; b < num_transactions/2; b++)
        begin
            t = new (.wrt_en(1'b0), .rd_en(1'b1));
            m.put(t);
        end
        */
    endtask
endclass

class Driver;
    mailbox #(Transaction) m;
    int num_transactions;

    function new (mailbox #(Transaction) m, int num_transactions);
        this.m = m;
        this.num_transactions = num_transactions;
    endfunction

    task run();
        Transaction t;
        for (int j = 0; j < num_transactions; j++)
        begin
            m.get(t);
            //t.display("Driver");
        end
    endtask
endclass

class Monitor;
    mailbox #(Transaction) m2s;
    int num_transactions;
    //Variables for covergroup
    bit [7:0] cp_occupancy;
    bit [1:0] cp_operation;
    bit       cp_boundary;
    bit       cp_reset;
    bit       cp_wrt_en;        //for write when full
    bit       cp_rd_en;         //for read when empty
    bit       cp_f;             //for the iff condition on write when full
    bit       cp_e;             //for the iff condition on read when empty
    //enum bit [1:0] {idle, read, write, simul_rw} operation;

    covergroup cg;
        occupancy: coverpoint cp_occupancy {
            bins empty = {0};
            bins partial = {[1:7]};
            bins full = {8};
        }

        operation_type: coverpoint cp_operation {
            bins idle = {2'b00};
            bins read = {2'b01};
            bins write = {2'b10};
            bins simultaneous_rw = {2'b11};
        }
        //boundary_conditions: coverpoint cp_boundary {}
        write_when_full: coverpoint cp_wrt_en iff (cp_f){
            bins hit = {1};
        }
        read_when_empty: coverpoint cp_rd_en iff (cp_e){
            bins hit = {1};
        }
        reset_coverage: coverpoint cp_reset {
            bins active = {0};      //active low
            bins inactive = {1};
        }


        occupancy_operation_cross: cross occupancy, operation_type;
        reset_occupancy_cross: cross reset_coverage, occupancy;
    endgroup

    function new (mailbox #(Transaction) m2s, int num_transactions);
        this.m2s = m2s;
        this.num_transactions = num_transactions;
        cg = new();
    endfunction

    /*
    //Commented out until virtual interfaces are used
    task run();
        Transaction t;

        for (int k = 0; k < num_transactions; k++)
        begin
            @ (posedge clk);
            #1;
            t = new();
            capture_transaction(t);

            if (t.e && !t.f)
                cp_occupancy = 0;
            else if (t.f && !t.e)
                cp_occupancy = 8;
            else
                cp_occupancy = 1;
            
            cp_operation = {t.wrt_en, t.rd_en};
            cp_reset = t.rst;
            cg.sample();
        
            m2s.put(t);
            t.display("Monitor");
        end
    endtask
    */
endclass

class Scoreboard;
    int num_transactions;
    mailbox #(Transaction) m2s;

    //Variables for reference model
    parameter n = 8;
    logic exp_f, exp_e;
    //bit [n - 1:0] exp_op;
    bit [n - 1:0] ref_fifo[$];
    integer errors = 0;
    bit [n - 1:0] exp_op_pending;
    bit pending = 0;

    function new (int num_transactions, mailbox #(Transaction) m2s);
        this.num_transactions = num_transactions;
        this.m2s = m2s;
    endfunction

    task run();
        Transaction t;

        //$display("SB starting, initial queue_size=%0d", ref_fifo.size());
        
        for (int l = 0; l < num_transactions; l++)
        begin
            m2s.get(t);
            //$display("SB got: rd_en=%0d t.op=%b  pending=%0d exp_op_pending=%b  queue_size=%0d", t.rd_en, t.op, pending, exp_op_pending, ref_fifo.size());

            //Check if reset is asserted or not in the middle of the operation
            if (!t.rst)
            begin
                pending = 0;
                exp_op_pending = 0;
                exp_f = 0;
                exp_e = 1;
                ref_fifo = {};
            end
            else
            begin
                int size_at_start = ref_fifo.size();    //Both branches refer the pre-cycle state

                //Check for X/Z values on flags (e/f)
                if ($isunknown(t.e) || $isunknown(t.f))
                begin
                    errors++;
                    $display ("X/Z on flags: e = %b f = %b", t.e, t.f);
                end

                /*
                //Check for X/Z values in output when rd_en = 1 and FIFO is not empty
                if (t.rd_en && !t.e && $isunknown(t.op))
                begin
                    errors++;
                    $display ("X/Z in output: op = %b", t.op);
                end
                */

                //Check if a pending value is there or not
                if (pending)
                begin
                    if (exp_op_pending !== t.op)
                    begin
                        errors++;
                        $display ("mismatch: expected = %b, got = %b", exp_op_pending, t.op);
                    end
                    pending = 0;
                end

                exp_e = (size_at_start == 0);
                exp_f = (size_at_start == n);
                if (exp_e !== t.e || exp_f !== t.f)
                begin
                    errors++;
                    $display("flag mismatch: exp_e=%b e=%b  exp_f=%b f=%b  queue_size=%0d", exp_e, t.e, exp_f, t.f, ref_fifo.size());
                end
            
                if (t.wrt_en && size_at_start < n)
                    ref_fifo.push_back(t.ip);
            
                if (t.rd_en && size_at_start > 0)
                begin
                    exp_op_pending = ref_fifo.pop_front();
                    pending = 1;
                    //$display("SB popped: new exp_op_pending=%b, new queue_size=%0d", exp_op_pending, ref_fifo.size());
                end
            end
        end
    endtask

    task report();
        if (errors > 0)
            $display ("Not Pass, no. of errors = %0d", errors);
        else
            $display ("Pass, no. of errors = %0d", errors);
    endtask
endclass

module FIFO_tb_sv;
    parameter n = 8;
    logic clk, rst, wrt_en, rd_en;
    logic [n - 1:0] ip;
    logic f, e;
    logic [n - 1:0] op;

    FIFO_d FIFO (.clock(clk), .reset(rst), .write_en(wrt_en), .read_en(rd_en), .data_in(ip), .data_out(op), .full(f), .empty(e));

    //Generating clock
    initial
    begin
        clk = 1'b0;
        forever
        begin
            #5;
            clk = ~clk;
        end
    end

    //Driving transactions into the DUT pins
    task drive_transaction(Transaction t);
        ip = t.ip;
        wrt_en = t.wrt_en;
        rd_en = t.rd_en;
        rst = t.rst;        //For asserting reset in the middle of the operation
        @ (posedge clk);
        #1;
    endtask

    //Capturing output(transactions) from the DUT
    task capture_transaction (Transaction t);
        t.ip = ip;
        t.wrt_en = wrt_en;
        t.rd_en = rd_en;
        t.rst = rst;        //For the monitor to capture that reset has been asserted
        t.op = op;
        t.e = e;
        t.f = f;
    endtask

    //Reset function
    task reset();
        rst = 1'b1;
        #10;
        rst = 1'b0;
        #10;
        rst = 1'b1;
    endtask

    //Assertions
    //Property1: The empty and full flags should be mutually exclusive, they cannot be 1 simultaneously
    property flags_mutually_exclusive;
        @ (posedge clk) disable iff (!rst) !(f && e);
    endproperty

    flag_mutual_check: assert property (flags_mutually_exclusive)
    else
        $error ("The flags are not mutually exclusive");

    /*
    The above assertion has a benign bug. Both f and e store an unknown value X for the first few iterations.
    When the condition is checked, both e and f turn out to be equal and as a result the assertion fails and
    the error message is displayed. Once reset is asserted, e = 1 and f= 0 and from that point onwards the
    the assertion's condition behaves properly i.e. e and f cannot be 1 at the same instant.
    */

    //Property2: No write should happen when f = 1
    property no_write_when_full;
        @ (posedge clk) disable iff (!rst) (((f) && (wrt_en) && ($past(rst))) |=> $stable(FIFO.write_pointer));
    endproperty

    no_writes_when_full_check: assert property (no_write_when_full)
    else
        $error ("Write happened when FIFO is full");

    //Property 3: No read should happen when e = 1
    property no_read_when_empty;
        @ (posedge clk) disable iff (!rst) (((e) && (rd_en) && ($past(rst))) |=> ($stable(op) && $stable(FIFO.read_pointer)));
    endproperty

    no_reads_when_empty_check: assert property (no_read_when_empty)
    else
        $error ("Read happened when FIFO is empty");

    //Property 4: A read produces the correct output the next cycle
    property correct_output;
        @ (posedge clk) disable iff (!rst) (((rd_en) && (!e) && ($past(rst))) |=> op == FIFO.memory_array[$past(FIFO.read_pointer[$clog2(n) - 1:0])]);
    endproperty

    correct_outputs_check: assert property (correct_output)
    else
        $error ("The output is not correct");

    //Property 5: Pointer increment happens correctly
    property read_pointer_increment;
        @ (posedge clk) disable iff (!rst) (((rd_en) && (!e) && ($past(rst))) |=> FIFO.read_pointer == $past(FIFO.read_pointer) + 4'd1);
    endproperty

    read_pointer_increment_check: assert property (read_pointer_increment)
    else
        $error ("The read pointer is not incrementing correctly");

    property write_pointer_increment;
        @ (posedge clk) disable iff (!rst) (((wrt_en) && (!f) && ($past(rst))) |=> FIFO.write_pointer == $past(FIFO.write_pointer) + 4'd1);
    endproperty

    wrtite_pointer_increment_check: assert property (write_pointer_increment)
    else
        $error ("The write pointer is not incrementing correctly");
    
    //Property 6: Flags update correctly after a write or read
    property empty_flag_update;
        @ (posedge clk) disable iff (!rst) (((rd_en) && (!e) && (!wrt_en) && (FIFO.write_pointer - FIFO.read_pointer == 4'd1) && ($past(rst))) |=> (e == 1'b1));
    endproperty

    empty_flag_update_check: assert property (empty_flag_update)
    else
        $error ("Empty flag did not assert after reading the last item");

    property full_flag_update;
        @ (posedge clk) disable iff (!rst) (((wrt_en) && (!f) && (!rd_en) && (FIFO.write_pointer - FIFO.read_pointer == 4'd7) && ($past(rst))) |=> (f == 1'b1));
    endproperty

    full_flag_update_check: assert property (full_flag_update)
    else
        $error ("Full flag did not assert after writing the last input");

    initial
    begin
        //Declarations
        mailbox #(Transaction) m;
        mailbox #(Transaction) m2s;
        Generator gen;
        Driver drv;
        Monitor mn;
        Scoreboard sb;

        //For regression suite
        int seed = 1;

        //Initializing SV random generator with this seed
        $srandom (seed);

        $display ("Running with seed = %d", seed);

        //Initializing objects
        m = new ();
        m2s = new ();
        gen = new (1500,m);
        drv = new (m, 1500);
        mn = new (m2s, 1500);
        sb = new (1500,m2s);
        
        $dumpfile ("FIFO_sv.vcd");
        $dumpvars (0, FIFO_tb_sv);

        reset();

        fork
            //Thread for Generator
            gen.run();

            //Thread for Driver
            begin    
                for (int k = 0; k < drv.num_transactions; k++)
                begin
                    Transaction t;
                    drv.m.get(t);
                    //t.display ("Driver");
                    drive_transaction(t);
                end
            end
            /*
            drv.run();
            */

            //Thread for Monitor
            begin
                Transaction t_monitor;
                for (int a = 0; a < mn.num_transactions; a++)
                begin
                    @ (posedge clk);
                    t_monitor = new ();
                    capture_transaction (t_monitor);
                    //Computing coverge sampling variables
                    if (t_monitor.e && !t_monitor.f)
                        mn.cp_occupancy = 0;
                    else if (t_monitor.f && !t_monitor.e)
                        mn.cp_occupancy = 8;
                    else
                        mn.cp_occupancy = 1;
                    
                    mn.cp_operation = {t_monitor.wrt_en, t_monitor.rd_en};
                    mn.cp_reset = t_monitor.rst;

                    mn.cp_wrt_en = t_monitor.wrt_en;
                    mn.cp_rd_en = t_monitor.rd_en;
                    mn.cp_f = t_monitor.f;
                    mn.cp_e = t_monitor.e;

                    mn.cg.sample();

                    mn.m2s.put (t_monitor);
                    t_monitor.display ("Monitor");
                end
            end
            /*
            mn.run();
            */

            //Thread for Scoreboard
            sb.run();
        join

        sb.report();
        $display ("Coverage: %0.2f%%", mn.cg.get_coverage());

        #100;
        $finish;
    end
endmodule