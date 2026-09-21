module FIFO_d (clock, reset, write_en, read_en, data_in, data_out, full, empty);
    parameter size = 8;
    input clock, reset, write_en, read_en;
    input [size - 1:0] data_in;
    output reg full, empty;
    output reg [size - 1:0] data_out;

    reg [size - 1:0] memory_array [0:size - 1];
    reg [$clog2(size):0] write_pointer, read_pointer;

    always @(posedge clock or negedge reset)
    begin
        if (!reset)
        begin
            write_pointer <= 0;
            read_pointer <= 0;
        end
        else
        begin
            if (write_en && !full)
            begin
                memory_array[write_pointer[$clog2(size) - 1:0]] <= data_in;
                write_pointer <= write_pointer + 1;
            end
            if (read_en && !empty)
            begin
                data_out <= memory_array[read_pointer[$clog2(size) - 1:0]];
                read_pointer <= read_pointer + 1;
            end
        end
    end

    always @ (*)
    begin
        if (read_pointer == write_pointer)
            empty = 1;
        else
            empty = 0;
        if ((read_pointer[$clog2(size) - 1:0] == write_pointer[$clog2(size) - 1:0]) && (read_pointer[$clog2(size)] != write_pointer[$clog2(size)]))
            full = 1;
        else
            full = 0;
    end
endmodule