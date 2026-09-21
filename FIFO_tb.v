module FIFO_tb;
    parameter n = 8;
    reg clk, rst, wrt_en, rd_en;
    reg [n - 1:0] ip;
    wire f, e;
    wire [n - 1:0] op;

    //Variables for self-checking testbench
    reg exp_f, exp_e;
    reg [n-1:0] exp_op;
    reg [n - 1:0] array [0:n - 1];
    reg [$clog2(n):0] wrt_pointer, rd_pointer;
    integer errors = 0;
    integer i = 0;
    integer j = 0;

    FIFO_d FIFO (.clock(clk), .reset(rst), .write_en(wrt_en), .read_en(rd_en), .data_in(ip), .data_out(op), .full(f), .empty(e));

    initial
    begin
        clk = 1'b0;
        forever
        begin
            #5;
            clk = ~clk;
        end
    end

    initial
    begin
        $dumpfile ("FIFO.vcd");
        $dumpvars (0, FIFO_tb);

        //Directed Stimulus
        rst = 1'b1;
        #10;
        rst = 1'b0;
        #10;
        rst = 1'b1;

        //write logic
        for (i = 0; i < 10; i = i + 1)
        begin
            wrt_en = 1'b1;
            rd_en = 1'b0;
            ip = i;
            @ (posedge clk);
            #1;                 //Prevent race condition
            $display ("i = %0d, ip = %b, exp_op = %b, op=%b, write_pointer = %0d, wrt_pointer = %0d, exp_f = %0d, full = %0d", i, ip, exp_op, op, FIFO.write_pointer, wrt_pointer, exp_f, f);
        end

        $display("Before read phase: rd_pointer = %0d, array[0] = %b, array[1] = %b", rd_pointer, array[0], array[1]);

        //read logic
        for (j = 0; j < 10; j = j + 1)
        begin
            wrt_en = 1'b0;
            rd_en = 1'b1;
            @ (posedge clk);
            #1;                 //Prevent race condition
            $display ("j = %0d, exp_op = %b, op = %b, read_pointer = %0d, rd_pointer = %0d, exp_e = %b, e = %b", j, exp_op, op, FIFO.read_pointer, rd_pointer, exp_e, e);
        end

        #100;

        //Condition for determining whether the all the test cases passed or not
        if (errors > 0)
            $display ("Not Pass, No. of errors = %0d", errors);
        else
            $display ("Pass, No. of errors = %0d", errors);

        $finish;
    end

    //Self-checking testbench
    always @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            wrt_pointer <= 0;
            rd_pointer <= 0;
        end
        else
        begin
            if (wrt_en && !exp_f)
            begin
                array[wrt_pointer[$clog2(n) - 1:0]] <= ip;
                wrt_pointer <= wrt_pointer + 1;
            end
            if (rd_en && !exp_e)
            begin
                exp_op <= array[rd_pointer[$clog2(n) - 1:0]];
                rd_pointer <= rd_pointer + 1;
            end
        end
    end

    always @ (*)
    begin
        if (rd_pointer == wrt_pointer)
            exp_e = 1;
        else
            exp_e = 0;
        if ((rd_pointer[$clog2(n) - 1:0] == wrt_pointer[$clog2(n) - 1:0]) && (rd_pointer[$clog2(n)] != wrt_pointer[$clog2(n)]))
            exp_f = 1;
        else
            exp_f = 0;
    end

    //Comparing the exp_op with the actual output from the DUT
    always @ (negedge clk)
    begin
        if (exp_op !== op || exp_e !== e || exp_f !== f)
        begin
            errors = errors + 1;
            //$display ("mismatch at t = %0t, exp_op = %b, op = %b, exp_e = %b, e = %b, exp_f = %b, f = %b", $time, exp_op, op, exp_e, e, exp_f, f);
        end
    end
endmodule