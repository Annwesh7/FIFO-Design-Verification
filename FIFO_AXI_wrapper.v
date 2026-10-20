module FIFO_AXI_wrapper (clock, reset, s_tready, s_tvalid, s_tdata, m_tready, m_tvalid, m_tdata);
    parameter size = 8;
    input clock, reset;

    //AXI-Stream Master
    input m_tready;
    output [size - 1:0] m_tdata;
    output m_tvalid;

    //AXI-Stream Slave
    input s_tvalid;
    input [size - 1:0] s_tdata;
    output s_tready;

    wire read_en, write_en, full, empty;
    wire [size - 1:0] data_in;
    wire [size - 1:0] data_out;

    //For First Word Fall Through
    reg fwft_valid_bit;
    reg [size - 1:0] fwft_data;
    reg read_in_flight;

    assign s_tready = !full;
    assign data_in = s_tdata;
    assign write_en = s_tready && s_tvalid;

    assign m_tvalid = fwft_valid_bit;
    assign m_tdata = fwft_data;
    assign read_en = !read_in_flight && !empty && (!fwft_valid_bit || m_tready);

    FIFO_d FIFO_2 (.clock(clock), .reset(reset), .read_en(read_en), .write_en(write_en), .data_in(data_in), .full(full), .empty(empty), .data_out(data_out));

    always @ (posedge clock or negedge reset)
    begin
        if (!reset)
        begin
            fwft_valid_bit <= 0;
            fwft_data <= 0;
            read_in_flight <= 0;
        end
        else
        begin
            read_in_flight <= read_en;

            if (read_in_flight)
            begin
                fwft_data <= data_out;
                fwft_valid_bit <= 1;
            end
            else if (fwft_valid_bit && m_tready)
            begin
                fwft_valid_bit <= 0;
            end
        end
    end
endmodule