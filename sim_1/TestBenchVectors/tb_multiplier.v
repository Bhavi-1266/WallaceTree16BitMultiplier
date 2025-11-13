`timescale 1ns / 1ps

// Testbench for 16-bit multipliers (Wallace Tree and Array Multiplier)
module wallace_multiplier_16bit_tb;
  reg clock;
  reg reset;
  reg [15:0] operand_a, operand_b;
  wire [31:0] result_wallace;
  wire [31:0] result_array;

  integer total_tests;
  integer passed_tests;
  integer failed_tests;


  wallace_multiplier_16bit uut_wallace (
    .clk(clock),
    .rst(reset),
    .multiplicand(operand_a),
    .multiplier(operand_b),
    .result(result_wallace)
  );

  // Array Multiplier: Combinational design, no clock/reset needed
  // Uncomment to test array multiplier instead:
  // array_multiplier_cla uut_array (
  //   .a(operand_a),
  //   .b(operand_b),
  //   .product(result_array)
  // );

  // Clock generation: 10ns period (100 MHz)
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  task test_mult;
    input [15:0] val_a;
    input [15:0] val_b;
    input use_wallace;
    reg [31:0] expected_result;
    reg [31:0] actual_result;
    begin
      total_tests = total_tests + 1;
      expected_result = val_a * val_b;
      
      @(posedge clock);
      operand_a <= val_a;
      operand_b <= val_b;
      
      if (use_wallace) begin
        repeat(6) @(posedge clock);
        actual_result = result_wallace;
      end else begin
        #10;
        actual_result = result_array;
      end
      
      if (actual_result === expected_result) begin
        $display("PASS: %d x %d = %d", val_a, val_b, actual_result);
        passed_tests = passed_tests + 1;
      end else begin
        $display("FAIL: %d x %d = %d (expected %d)", val_a, val_b, actual_result, expected_result);
        failed_tests = failed_tests + 1;
      end
    end
  endtask

  // Main test sequence
  initial begin
    total_tests = 0;
    passed_tests = 0;
    failed_tests = 0;
    reset = 1;
    operand_a = 0;
    operand_b = 0;
    
    #100;
    reset = 0;
    #100;
    
    $display("Starting Multiplier Tests...");
    $display("Testing Wallace Tree Multiplier (pipelined)...\n");
    
    // Test cases covering edge cases and various ranges
    test_mult(16'd0, 16'd0, 1);           // Zero case
    test_mult(16'd1, 16'd1, 1);           // Minimum non-zero
    test_mult(16'd3, 16'd7, 1);           // Small values
    test_mult(16'd50, 16'd200, 1);        // Medium values
    test_mult(16'd128, 16'd255, 1);       // Power of 2 and max byte
    test_mult(16'd500, 16'd2000, 1);      // Larger values
    test_mult(16'd2000, 16'd3000, 1);     // Different pair
    test_mult(16'd25000, 16'd50000, 1);  // Large values
    test_mult(16'd65535, 16'd1, 1);       // Max with 1
    test_mult(16'd65535, 16'd65535, 1);   // Max x Max
    test_mult(16'd42, 16'd17, 1);         // Additional test
    test_mult(16'd1024, 16'd4096, 1);     // Power of 2 values
    test_mult(16'd12345, 16'd54321, 1);   // Additional large test
    
    // Uncomment  to test Array Multiplier (combinational)
    // $display("\nTesting Array Multiplier (combinational)...\n");
    // test_mult(16'd0, 16'd0, 0);
    // test_mult(16'd1, 16'd1, 0);
    // test_mult(16'd3, 16'd7, 0);
    // test_mult(16'd50, 16'd200, 0);
    // test_mult(16'd128, 16'd255, 0);
    // test_mult(16'd500, 16'd2000, 0);
    // test_mult(16'd2000, 16'd3000, 0);
    // test_mult(16'd25000, 16'd50000, 0);
    // test_mult(16'd65535, 16'd1, 0);
    // test_mult(16'd65535, 16'd65535, 0);
    // test_mult(16'd42, 16'd17, 0);
    // test_mult(16'd1024, 16'd4096, 0);
    // test_mult(16'd12345, 16'd54321, 0);
    
    // Print test summary
    $display("\nTest Summary:");
    $display("Total:  %0d", total_tests);
    $display("Passed: %0d", passed_tests);
    $display("Failed: %0d", failed_tests);
    
    if (failed_tests == 0) begin
      $display("ALL TESTS PASSED!");
    end else begin
      $display("SOME TESTS FAILED!");
    end
    
    #100;
    $finish;
  end
endmodule
