# Wallace Tree and Array Multiplier Sources

This repository contains a 16-bit Wallace Tree multiplier (pipelined), an array multiplier that uses carry look-ahead adders, and a testbench used to verify the designs. The full source code for each module is included below for easy reference.

---

## File: sim_1/TestBenchVectors/tb_multiplier.v

```verilog
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

```

---

## File: source_Array_Wallace/new/array_multiplier_cla.v

```verilog
// ============================================================================
// 16-bit Array Multiplier using Carry Look-Ahead Adders
// ============================================================================
// Architecture: Combinational multiplier
//   Step 1: Generate 16 partial products (one per multiplier bit)
//   Step 2: Accumulate partial products sequentially using 32-bit CLA adders
//   Result: 32-bit product available after combinational delay
// ============================================================================

// 4-bit Carry Look-Ahead Adder
module cla_4bit (
	input  [3:0] a,
	input  [3:0] b,
	input        cin,
	output [3:0] sum,
	output       cout
);
	wire [3:0] p, g;
	wire [4:0] c;

	assign p = a ^ b;
	assign g = a & b;

	// Carry lookahead: Compute all carries in parallel
	assign c[0] = cin;
	assign c[1] = g[0] | (p[0] & c[0]);
	assign c[2] = g[1] | (p[1] & c[1]);
	assign c[3] = g[2] | (p[2] & c[2]);
	assign c[4] = g[3] | (p[3] & c[3]);

	assign sum  = p ^ c[3:0];
	assign cout = c[4];
endmodule

module cla_32bit (
	input  [31:0] a,
	input  [31:0] b,
	input         cin,
	output [31:0] sum,
	output        cout
);
	wire [7:0] carry;
	genvar i;

	generate
		for (i = 0; i < 8; i = i + 1) begin: CLA_BLOCK
			cla_4bit cla_inst (
				.a   (a[i*4 +: 4]),
				.b   (b[i*4 +: 4]),
				.cin (i == 0 ? cin : carry[i-1]),
				.sum (sum[i*4 +: 4]),
				.cout(carry[i])
			);
		end
	endgenerate

	assign cout = carry[7];
endmodule

// Main Array Multiplier Module
module array_multiplier_cla (
	input  [15:0] a,
	input  [15:0] b,
	output [31:0] product
);

	wire [31:0] partial [15:0];
	wire [31:0] sum_stage [15:0];
	genvar i;

    
	generate
		for (i = 0; i < 16; i = i + 1) begin : PARTIALS
			assign partial[i] = b[i] ? ({16'b0, a} << i) : 32'b0;
		end
	endgenerate

    
	assign sum_stage[0] = partial[0];

	generate
		for (i = 1; i < 16; i = i + 1) begin : SUM_LOOP
			wire cout_unused;
			cla_32bit cla_add(
				.a   (sum_stage[i-1]),
				.b   (partial[i]),
				.cin (1'b0),
				.sum (sum_stage[i]),
				.cout(cout_unused)
			);
		end
	endgenerate

	assign product = sum_stage[15];

endmodule

```

---

## File: source_Array_Wallace/new/wallace_multiplier.v

```verilog
// ============================================================================
// 16-bit Pipelined Wallace Tree Multiplier
// ============================================================================
// Architecture: 3-stage pipeline
//   Stage 1: Partial product generation (16 partial products)
//   Stage 2: Wallace tree reduction using 4-to-2 compressors (3 levels)
//   Stage 3: Final addition using 32-bit CLA
// Pipeline depth: 6 clock cycles total
// ============================================================================

// Partial Full Adder: Computes sum and generates propagate/generate signals
module partial_full_adder (
	input  wire in_a,
	input  wire in_b,
	input  wire carry_in,
	output wire sum_out,
	output wire propagate,
	output wire generate_out
);
	assign sum_out = in_a ^ in_b ^ carry_in;
	assign propagate = in_a ^ in_b;
	assign generate_out = in_a & in_b;
endmodule

// 4-bit Carry Lookahead Adder: 
module carry_look_ahead_4bit (
	input  wire [3:0] operand_a,
	input  wire [3:0] operand_b,
	input  wire       carry_in,
	output wire [3:0] sum_out,
	output wire       carry_out,
	output wire       prop_group,
	output wire       gen_group
);
	wire [3:0] prop, gen;
	wire carry1, carry2, carry3;

	partial_full_adder PFA1 (.in_a(operand_a[0]), .in_b(operand_b[0]), .carry_in(carry_in), .sum_out(sum_out[0]), .propagate(prop[0]), .generate_out(gen[0]));
	partial_full_adder PFA2 (.in_a(operand_a[1]), .in_b(operand_b[1]), .carry_in(carry1),  .sum_out(sum_out[1]), .propagate(prop[1]), .generate_out(gen[1]));
	partial_full_adder PFA3 (.in_a(operand_a[2]), .in_b(operand_b[2]), .carry_in(carry2),  .sum_out(sum_out[2]), .propagate(prop[2]), .generate_out(gen[2]));
	partial_full_adder PFA4 (.in_a(operand_a[3]), .in_b(operand_b[3]), .carry_in(carry3),  .sum_out(sum_out[3]), .propagate(prop[3]), .generate_out(gen[3]));

	assign carry1   = gen[0] | (prop[0] & carry_in);
	assign carry2   = gen[1] | (prop[1] & gen[0]) | (prop[1] & prop[0] & carry_in);
	assign carry3   = gen[2] | (prop[2] & gen[1]) | (prop[2] & prop[1] & gen[0]) | (prop[2] & prop[1] & prop[0] & carry_in);
	assign carry_out = gen[3] | (prop[3] & gen[2]) | (prop[3] & prop[2] & gen[1]) |
				  (prop[3] & prop[2] & prop[1] & gen[0]) |
				  (prop[3] & prop[2] & prop[1] & prop[0] & carry_in);

	assign prop_group = &prop;
	assign gen_group = gen[3] | (prop[3] & gen[2]) | (prop[3] & prop[2] & gen[1]) |
					 (prop[3] & prop[2] & prop[1] & gen[0]);
endmodule


module carry_look_ahead_32bit (
	input  wire [31:0] input_a,
	input  wire [31:0] input_b,
	input  wire        carry_in,
	output wire [31:0] sum_out,
	output wire        carry_out
);
	wire [7:0] prop_group, gen_group;
	wire [8:0] carry_block;
	assign carry_block[0] = carry_in;

	genvar idx;
	generate
		for (idx = 0; idx < 8; idx = idx + 1) begin : CLA_4BIT_GEN
			carry_look_ahead_4bit CLA4 (
				.operand_a(input_a[(idx*4)+3 : (idx*4)]),
				.operand_b(input_b[(idx*4)+3 : (idx*4)]),
				.carry_in(carry_block[idx]),
				.sum_out(sum_out[(idx*4)+3 : (idx*4)]),
				.carry_out(),
				.prop_group(prop_group[idx]),
				.gen_group(gen_group[idx])
			);

			assign carry_block[idx+1] = gen_group[idx] | (prop_group[idx] & carry_block[idx]);
		end
	endgenerate

	assign carry_out = carry_block[8];
endmodule


module compressor_4to2(
	input  wire [31:0] in1,
	input  wire [31:0] in2,
	input  wire [31:0] in3,
	input  wire [31:0] in4,
	output wire [31:0] sum_out,
	output wire [31:0] carry_out
);
	wire [31:0] xor_12;
	wire [31:0] and_12, and_13, and_23;
	wire [31:0] temp_sum1, temp_carry1;
	wire [31:0] shifted_carry1;
	wire [31:0] temp_sum2, temp_carry2;
    
	// Stage 1: Process first two inputs
	assign xor_12 = in1 ^ in2;
	assign and_12 = in1 & in2;
	assign and_13 = in1 & in3;
	assign and_23 = in2 & in3;
    
	assign temp_sum1 = xor_12 ^ in3;
	assign temp_carry1 = and_12 | and_13 | and_23;
    
	assign shifted_carry1 = temp_carry1 << 1;
    
	assign temp_sum2 = temp_sum1 ^ in4 ^ shifted_carry1;
	assign temp_carry2 = (temp_sum1 & in4) | (temp_sum1 & shifted_carry1) | (in4 & shifted_carry1);
    
	assign sum_out = temp_sum2;
	assign carry_out = temp_carry2 << 1;
endmodule

// Main Wallace Tree Multiplier Module
module wallace_multiplier_16bit(
	input  wire        clk,
	input  wire        rst,
	input  wire [15:0] multiplicand,
	input  wire [15:0] multiplier,
	output reg  [31:0] result
);
	// ========================================================================
	// STAGE 1: Partial Product Generation
	// ========================================================================
	// Generate 16 partial products by ANDing each multiplier bit with
	// multiplicand and shifting appropriately
	wire bit_products [15:0][15:0];
	wire [31:0] partial_prod [15:0];
    
	genvar row_idx, col_idx;
	generate
		for (row_idx = 0; row_idx < 16; row_idx = row_idx + 1) begin : BIT_PRODUCT_GEN
			for (col_idx = 0; col_idx < 16; col_idx = col_idx + 1) begin : BIT_AND
				assign bit_products[row_idx][col_idx] = multiplicand[col_idx] & multiplier[row_idx];
			end
		end
        
		for (row_idx = 0; row_idx < 16; row_idx = row_idx + 1) begin : PARTIAL_PROD_GEN
			wire [31:0] extended_row;
			wire [15:0] row_bits;
			genvar bit_idx;
			for (bit_idx = 0; bit_idx < 16; bit_idx = bit_idx + 1) begin : ROW_BITS
				assign row_bits[bit_idx] = bit_products[row_idx][bit_idx];
			end
			assign extended_row = {16'b0, row_bits};
			assign partial_prod[row_idx] = extended_row << row_idx;
		end
	endgenerate

	reg [31:0] partial_prod_reg [15:0];
	integer reg_idx;
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			for (reg_idx = 0; reg_idx < 16; reg_idx = reg_idx + 1)
				partial_prod_reg[reg_idx] <= 32'd0;
		end else begin
			for (reg_idx = 0; reg_idx < 16; reg_idx = reg_idx + 1)
				partial_prod_reg[reg_idx] <= partial_prod[reg_idx];
		end
	end

	// ========================================================================
	// STAGE 2: Wallace Tree Reduction (3 levels of compression)
	// ========================================================================
	// Level 1: Compress 16 partial products into 8 (using 4 compressors)
	wire [31:0] stage1_sum [3:0];
	wire [31:0] stage1_carry [3:0];

	genvar comp_idx;
	generate
		for (comp_idx = 0; comp_idx < 4; comp_idx = comp_idx + 1) begin : LEVEL1_COMPRESS
			compressor_4to2 comp_l1 (
				.in1(partial_prod_reg[comp_idx*4]),
				.in2(partial_prod_reg[comp_idx*4+1]),
				.in3(partial_prod_reg[comp_idx*4+2]),
				.in4(partial_prod_reg[comp_idx*4+3]),
				.sum_out(stage1_sum[comp_idx]),
				.carry_out(stage1_carry[comp_idx])
			);
		end
	endgenerate

	reg [31:0] stage1_sum_reg [3:0];
	reg [31:0] stage1_carry_reg [3:0];
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			for (reg_idx = 0; reg_idx < 4; reg_idx = reg_idx + 1) begin
				stage1_sum_reg[reg_idx] <= 32'd0;
				stage1_carry_reg[reg_idx] <= 32'd0;
			end
		end else begin
			for (reg_idx = 0; reg_idx < 4; reg_idx = reg_idx + 1) begin
				stage1_sum_reg[reg_idx] <= stage1_sum[reg_idx];
				stage1_carry_reg[reg_idx] <= stage1_carry[reg_idx];
			end
		end
	end

	wire [31:0] stage2_sum [1:0];
	wire [31:0] stage2_carry [1:0];

	compressor_4to2 comp_l2_0 (
		.in1(stage1_sum_reg[0]),
		.in2(stage1_carry_reg[0]),
		.in3(stage1_sum_reg[1]),
		.in4(stage1_carry_reg[1]),
		.sum_out(stage2_sum[0]),
		.carry_out(stage2_carry[0])
	);

	compressor_4to2 comp_l2_1 (
		.in1(stage1_sum_reg[2]),
		.in2(stage1_carry_reg[2]),
		.in3(stage1_sum_reg[3]),
		.in4(stage1_carry_reg[3]),
		.sum_out(stage2_sum[1]),
		.carry_out(stage2_carry[1])
	);

	reg [31:0] stage2_sum_reg [1:0];
	reg [31:0] stage2_carry_reg [1:0];
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			stage2_sum_reg[0] <= 32'd0;
			stage2_sum_reg[1] <= 32'd0;
			stage2_carry_reg[0] <= 32'd0;
			stage2_carry_reg[1] <= 32'd0;
		end else begin
			stage2_sum_reg[0] <= stage2_sum[0];
			stage2_sum_reg[1] <= stage2_sum[1];
			stage2_carry_reg[0] <= stage2_carry[0];
			stage2_carry_reg[1] <= stage2_carry[1];
		end
	end

	wire [31:0] stage3_sum;
	wire [31:0] stage3_carry;
	compressor_4to2 comp_l3 (
		.in1(stage2_sum_reg[0]),
		.in2(stage2_carry_reg[0]),
		.in3(stage2_sum_reg[1]),
		.in4(stage2_carry_reg[1]),
		.sum_out(stage3_sum),
		.carry_out(stage3_carry)
	);

	reg [31:0] stage3_sum_reg;
	reg [31:0] stage3_carry_reg;
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			stage3_sum_reg <= 32'd0;
			stage3_carry_reg <= 32'd0;
		end else begin
			stage3_sum_reg <= stage3_sum;
			stage3_carry_reg <= stage3_carry;
		end
	end

	// ========================================================================
	// STAGE 3: Final Addition
	// ========================================================================
	// Add the final sum and carry using 32-bit CLA to get the product
	wire [31:0] final_output;

	carry_look_ahead_32bit cla_final (
		.input_a(stage3_sum_reg),
		.input_b(stage3_carry_reg),
		.carry_in(1'b0),
		.sum_out(final_output),
		.carry_out()
	);
    
	// Pipeline register for final result
	always @(posedge clk or posedge rst) begin
		if (rst)
			result <= 32'd0;
		else
			result <= final_output;
	end
endmodule

```

---

If you'd like, I can also add a small README section explaining how to run the testbench in your simulator, or include the original file headers/credits. Let me know which you'd prefer next.
