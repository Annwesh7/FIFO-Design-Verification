class Transaction;
    bit [7:0] ip;
    bit       wrt_en;
    bit       rd_en;

    logic [7:0] op;
    logic       f;
    logic       e;

    function new (bit [7:0] ip, bit wrt_en, bit rd_en);
        this.ip = ip;
        this.wrt_en = wrt_en;
        this.rd_en = rd_en;
    endfunction

    function void display (string tag = "");
        $display ("ip = %b, op = %b, wrt_en = %0d, rd_en = %0d, f = %0d, e = %0d", this.ip, this.op, this.wrt_en, this.rd_en, this.f, this.e);
    endfunction
endclass

class Generator;
    int num_transactions;
    mailbox m;

    function new (int num_transactions, mailbox m);
        this.num_transactions = num_transactions;
        this.m = m;
    endfunction

    task run()
        Transaction t;
        for (int i = 0; i < num_transactions; i++)
        begin
            t = new (.write_en(1'b1), .read_en(1'b0), .ip(i));
            m.put(t);
        end
    endtask
endclass

class Driver;
    mailbox m;
    int num_transactions;

    function new (mailbox m, int num_transactions);
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
        clock = 1'b0;
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

    //Reset function
    task reset()
        rst = 1'b1;
        #10;
        rst = 1'b0;
        #10;
        rst = 1'b1;
    endtask

    initial
    begin
        $dumpfile ("FIFO_sv.vcd");
        $dumpvars (0, FIFO_tb_sv);

        mailbox m = new();
        Generator gen = new (10, m);
        Driver drv = new (m, 10);

        Transaction t;

        reset();

        gen.run();

        for (int k = 0; k < 10; k++)
        begin
            drv.m.get(t);
            $display ("Driver");
            drive_transaction(t);
        end

        #100;
        $finish;
    end
endmodule

class Monitor;
endclass

class Scoreboard;
endclass