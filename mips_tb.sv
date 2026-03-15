module tb_processor;

    reg        clk1, clk2;
    reg  [4:0] num;
    wire [4:0] result;

    process p (
        .clk1(clk1),
        .clk2(clk2),
        .num(num),
        .result(result)
    );

    initial clk1 = 0;
    always #10 clk1 = ~clk1;

    initial begin clk2 = 0; #5; forever #10 clk2 = ~clk2; end

    task run_test;
        input [4:0] n;
        input [4:0] expected;
        begin
            num = n;
            @(posedge clk1); #1;
            repeat(80) @(posedge clk1);
            #1;
            $display("--- debug r[1]=%0d r[2]=%0d r[3]=%0d r[4]=%0d ---",
                p.r[1], p.r[2], p.r[3], p.r[4]);
            $display("sqrt(%0d) = %0d  (expected %0d) %s",
                n, result, expected,
                (result == expected) ? "PASS" : "FAIL");
        end
    endtask

    initial begin
        $dumpfile("processor.vcd");
        $dumpvars(0, tb_processor);

        run_test(16, 4);
        run_test(9,  3);
        run_test(4,  2);
        run_test(1,  1);

        $finish;
    end

endmodule