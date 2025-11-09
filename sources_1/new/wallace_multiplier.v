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
// Used as building block for Carry Lookahead Adders
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

// 4-bit Carry Lookahead Adder: Fast addition using carry lookahead logic
// Computes all carries in parallel to reduce propagation delay
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

    // Generate propagate and generate signals for each bit position
    partial_full_adder PFA1 (.in_a(operand_a[0]), .in_b(operand_b[0]), .carry_in(carry_in), .sum_out(sum_out[0]), .propagate(prop[0]), .generate_out(gen[0]));
    partial_full_adder PFA2 (.in_a(operand_a[1]), .in_b(operand_b[1]), .carry_in(carry1),  .sum_out(sum_out[1]), .propagate(prop[1]), .generate_out(gen[1]));
    partial_full_adder PFA3 (.in_a(operand_a[2]), .in_b(operand_b[2]), .carry_in(carry2),  .sum_out(sum_out[2]), .propagate(prop[2]), .generate_out(gen[2]));
    partial_full_adder PFA4 (.in_a(operand_a[3]), .in_b(operand_b[3]), .carry_in(carry3),  .sum_out(sum_out[3]), .propagate(prop[3]), .generate_out(gen[3]));

    // Carry lookahead: Compute carries in parallel using propagate and generate
    assign carry1   = gen[0] | (prop[0] & carry_in);
    assign carry2   = gen[1] | (prop[1] & gen[0]) | (prop[1] & prop[0] & carry_in);
    assign carry3   = gen[2] | (prop[2] & gen[1]) | (prop[2] & prop[1] & gen[0]) | (prop[2] & prop[1] & prop[0] & carry_in);
    assign carry_out = gen[3] | (prop[3] & gen[2]) | (prop[3] & prop[2] & gen[1]) |
                  (prop[3] & prop[2] & prop[1] & gen[0]) |
                  (prop[3] & prop[2] & prop[1] & prop[0] & carry_in);

    // Group propagate and generate for hierarchical CLA construction
    assign prop_group = &prop;
    assign gen_group = gen[3] | (prop[3] & gen[2]) | (prop[3] & prop[2] & gen[1]) |
                     (prop[3] & prop[2] & prop[1] & gen[0]);
endmodule

// 32-bit Carry Lookahead Adder: Built from 8 cascaded 4-bit CLA blocks
// Uses hierarchical carry lookahead for fast 32-bit addition
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

    // Generate 8 instances of 4-bit CLA blocks
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

            // Compute inter-block carry using group propagate and generate
            assign carry_block[idx+1] = gen_group[idx] | (prop_group[idx] & carry_block[idx]);
        end
    endgenerate

    assign carry_out = carry_block[8];
endmodule

// 4-to-2 Compressor: Reduces 4 inputs to 2 outputs (sum and carry)
// Used in Wallace tree to reduce number of partial products efficiently
// Algorithm: Compresses 4 numbers into sum and shifted carry
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
    
    // Combine first three inputs: sum = XOR of all three, carry = majority function
    assign temp_sum1 = xor_12 ^ in3;
    assign temp_carry1 = and_12 | and_13 | and_23;
    
    // Shift carry left for next stage (carry is one position higher)
    assign shifted_carry1 = temp_carry1 << 1;
    
    // Stage 2: Combine with fourth input and shifted carry
    assign temp_sum2 = temp_sum1 ^ in4 ^ shifted_carry1;
    assign temp_carry2 = (temp_sum1 & in4) | (temp_sum1 & shifted_carry1) | (in4 & shifted_carry1);
    
    assign sum_out = temp_sum2;
    assign carry_out = temp_carry2 << 1;
endmodule

// Main Wallace Tree Multiplier Module
// Implements pipelined 16x16 bit multiplication using Wallace tree reduction
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
        // Generate bit-wise products: AND each multiplier bit with each multiplicand bit
        for (row_idx = 0; row_idx < 16; row_idx = row_idx + 1) begin : BIT_PRODUCT_GEN
            for (col_idx = 0; col_idx < 16; col_idx = col_idx + 1) begin : BIT_AND
                assign bit_products[row_idx][col_idx] = multiplicand[col_idx] & multiplier[row_idx];
            end
        end
        
        // Form partial products: Each row is shifted left by its row index
        for (row_idx = 0; row_idx < 16; row_idx = row_idx + 1) begin : PARTIAL_PROD_GEN
            wire [31:0] extended_row;
            wire [15:0] row_bits;
            genvar bit_idx;
            // Concatenate bits into a row
            for (bit_idx = 0; bit_idx < 16; bit_idx = bit_idx + 1) begin : ROW_BITS
                assign row_bits[bit_idx] = bit_products[row_idx][bit_idx];
            end
            assign extended_row = {16'b0, row_bits};
            assign partial_prod[row_idx] = extended_row << row_idx;
        end
    endgenerate

    // Pipeline register: Store partial products for next stage
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
        // Each compressor takes 4 partial products and produces sum + carry
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

    // Pipeline register for level 1 outputs
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

    // Level 2: Compress 8 values (4 sums + 4 carries) into 4 (using 2 compressors)
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

    // Pipeline register for level 2 outputs
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

    // Level 3: Compress 4 values (2 sums + 2 carries) into 2 (using 1 compressor)
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

    // Pipeline register for level 3 outputs
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
