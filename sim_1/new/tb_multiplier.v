`timescale 1ns / 1ps

module tb_multiplier;

    reg  [15:0] a, b;
    wire [31:0] product;
    reg  [31:0] expected;

    // ============================================================
    // CHANGE THIS LINE TO SWITCH BETWEEN DESIGNS
    // ------------------------------------------------------------
    array_multiplier_cla DUT (.a(a), .b(b), .product(product));
    // wallace_multiplier   DUT (.a(a), .b(b), .product(product));
    // ============================================================


    // Task to apply test vectors
    task apply_test;
        input [15:0] A;
        input [15:0] B;
    begin
        a = A;
        b = B;
        expected = A * B;   // golden reference model (behavioral)

        #10; // allow time for output to settle

        if (product !== expected)
            $display("❌ FAIL  | A = %6d  B = %6d  | Expected = %10d  Got = %10d",
                      A, B, expected, product);
        else
            $display("✅ PASS  | A = %6d  B = %6d  | Product  = %10d (0x%h)",
                      A, B, product, product);
    end
    endtask



    initial begin
        $display("\n========== MULTIPLIER TESTBENCH START ==========\n");

        // -------- EXACTLY 15 TEST CASES --------
        apply_test(16'd0,       16'd0);      // 1
        apply_test(16'd1,       16'd1);      // 2
        apply_test(16'd3,       16'd7);      // 3
        apply_test(16'd10,      16'd20);     // 4
        apply_test(16'd15,      16'd15);     // 5
        apply_test(16'd25,      16'd40);     // 6
        apply_test(16'd100,     16'd200);    // 7
        apply_test(16'd255,     16'd255);    // 8
        apply_test(16'd999,     16'd111);    // 9
        apply_test(16'd1234,    16'd5678);   // 10
        apply_test(16'd32767,   16'd2);      // 11 (near max positive)
        apply_test(16'hFFFF,    16'd1);      // 12 (max * 1)
        apply_test(16'hFFFF,    16'hFFFF);   // 13 (max * max)
        apply_test(16'd5555,    16'd3333);   // 14
        apply_test(16'd42,      16'd73);     // 15

        $display("\n========== TESTBENCH COMPLETE ==========\n");
        $stop;
    end
endmodule
