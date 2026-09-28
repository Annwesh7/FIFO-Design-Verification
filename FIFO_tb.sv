class Transaction;
    bit [7:0] ip;
    bit       wrt_en;
    bit       rd_en;

    logic [7:0] op;
    logic       f;
    logic       e;

    function new (bit [7:0] ip = 0, bit wrt_en = 0, bit rd_en = 0);
        this.ip = ip;
        this.wrt_en = wrt_en;
        this.rd_en = rd_en;
    endfunction

    function void display (string tag = "");        //for labelling each display call by "Driver" or "Monitor"
        $display ("ip = %b, op = %b, wrt_en = %0d, rd_en = %0d, f = %0d, e = %0d", this.ip, this.op, this.wrt_en, this.rd_en, this.f, this.e);
    endfunction
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

        //For writing to the FIFO
        for (int i = 0; i < num_transactions/2; i++)
        begin
            t = new (.wrt_en(1'b1), .rd_en(1'b0), .ip(i));
            m.put(t);
        end

        //For reading from the FIFO
        for (int b = 0; b < num_transactions/2; b++)
        begin
            t = new (.wrt_en(1'b0), .rd_en(1'b1));
            m.put(t);
        end
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
            t.display("Driver");
        end
    endtask
endclass

class Monitor;
    mailbox #(Transaction) m2s;
    int num_transactions;

    function new (mailbox #(Transaction) m2s, int num_transactions);
        this.m2s = m2s;
        this.num_transactions = num_transactions;
    endfunction

    /*
    task run();
        Transaction t;
        for (int k = 0; k < num_transactions; k++)
        begin
            @ (posedge clk);
            #1;
            t = new();
            capture_transaction(t);
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
    bit [n - 1:0] exp_op;
    bit [7:0] ref_fifo[$];
    integer errors = 0;

    function new (int num_transactions, mailbox #(Transaction) m2s);
        this.num_transactions = num_transactions;
        this.m2s = m2s;
    endfunction

    task run();
        Transaction t;
        for (int l = 0; l < num_transactions; l++)
        begin
            m2s.get(t);
            if (t.wrt_en && ref_fifo.size() < n)
                ref_fifo.push_back(t.ip);
            if (t.rd_en && ref_fifo.size() > 0)
            begin
                exp_op = ref_fifo.pop_front();
                if (exp_op !== t.op)
                begin
                    $display ("mismatch: expected = %b, got = %b at time t = %0t", exp_op, t.op, $time);
                    errors = errors + 1;
                end
            end

            exp_e = (ref_fifo.size() == 0);
            exp_f = (ref_fifo.size() == n);
            if (exp_e !== t.e || exp_f !== t.f)
                errors = errors + 1;
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
        @ (posedge clk);
        #1;
    endtask

    //Capturing output(transactions) from the DUT
    task capture_transaction (Transaction t);
        t.ip = ip;
        t.wrt_en = wrt_en;
        t.rd_en = rd_en;
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

    initial
    begin
        //Declarations
        mailbox #(Transaction) m;
        mailbox #(Transaction) m2s;
        Generator gen;
        Driver drv;
        Monitor mn;
        Scoreboard sb;

        //Initializing objects
        m = new ();
        m2s = new ();
        gen = new (20,m);
        drv = new (m, 20);
        mn = new (m2s, 20);
        sb = new (20,m2s);
        
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
                    t.display ("Driver");
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
                    #1;
                    t_monitor = new ();
                    capture_transaction (t_monitor);
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

        #100;
        $finish;
    end
endmodule