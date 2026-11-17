class AXI_Transaction;
    //Slave side stimulus
    rand logic [7:0] ip;        //data to push in the FIFO
    rand logic [7:0] s_tdelay;  //delay before asserting s_tvalid for handshake with s_tready

    //Master side stimulus
    rand logic [7:0] m_tdelay;        //delay to hold m_tready low before handshake with m_tvalid

    //Observation
    logic [7:0] op;             //output of wrapper seen by the monitor

    //Constraints
    //Declaring a range for the delays because any random delay would create long "no action" periods
    constraint s_tdelay_range {s_tdelay inside {[0:3]};}
    constraint m_tdelay_range {m_tdelay inside {[0:3]};}
endclass

class AXI_Generator;
    int num_transactions;
    mailbox #(AXI_Transaction) g2md;
    mailbox #(AXI_Transaction) g2sd;

    function new (int num_transactions, mailbox #(AXI_Transaction) g2md, mailbox #(AXI_Transaction) g2sd);
        this.num_transactions = num_transactions;
        this.g2md = g2md;
        this.g2sd = g2sd;
    endfunction

    task run();
        AXI_Transaction t;

        for (int i = 0; i < num_transactions; i++)
        begin
            t = new ();
            if (t.randomize ())
            begin
                g2md.put(t);
                g2sd.put(t);
            end
            else
                $display ("Randomization Failed at transaction %0d", i);
        end
    endtask
endclass

class AXI_SlaveDriver;
    int num_transactions;
    mailbox #(AXI_Transaction) g2sd;

    function new (int num_transactions, mailbox #(AXI_Transaction) g2sd);
    this.num_transactions = num_transactions;
    this.g2sd = g2sd;
    endfunction

    task run ();
    AXI_Transaction t;

    for (int i = 0; i < num_transactions; i++)
    begin
        g2sd.get(t);
        
        //Idle phase
        s_tvalid = 0;
        repeat (t.s_tdelay) @ (posedge clk);

        //Offer phase
        s_tvalid = 1;
        s_tdata = t.ip;

        //Hold until handshake phase
        do @ (posedge clk);
        while (!s_tready);

        //Release phase
        s_tvalid = 0;
        s_tdata = 0;
    end
    endtask
endclass

class AXI_MasterDriver;
    int num_transactions;
    mailbox #(AXI_Transaction) g2md;

    function new (int num_transactions, mailbox #(AXI_Transaction) g2md);
    this.num_transactions = num_transactions;
    this.g2md = g2md;
    endfunction

    task run ();
    AXI_Transaction t;

    for (int i = 0; i < num_transactions; i++)
    begin
        g2md.get(t);

        //Backpressure phase to create intentional stalls making the FIFO to fill up and exercise m_tvalid stability
        m_tready = 0;
        repeat (t.m_tdelay) @ (posedge clk);

        //Handshake phase
        m_tready = 1;
        do @ (posedge clk);
        while (!m_tvalid);

        //Release phase
        m_tready = 0;
    end
    endtask
endclass

class AXI_Monitor;
endclass

class AXI_Scoreboard;
endclass