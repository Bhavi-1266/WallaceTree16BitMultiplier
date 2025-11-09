// ============================================================================
// 16-bit Array Multiplier using Carry Look-Ahead Adders
// ============================================================================
// Architecture: Combinational multiplier
//   Step 1: Generate 16 partial products (one per multiplier bit)
//   Step 2: Accumulate partial products sequentially using 32-bit CLA adders
//   Result: 32-bit product available after combinational delay
// ============================================================================

// 4-bit Carry Look-Ahead Adder
// Computes sum and carry using propagate (p) and generate (g) signals
// All carries computed in parallel for fast addition
module cla_4bit (
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);
    wire [3:0] p, g;
    wire [4:0] c;

    // Propagate: p[i] = 1 if a[i] XOR b[i] can propagate carry
    // Generate: g[i] = 1 if a[i] AND b[i] will generate carry
    assign p = a ^ b;
    assign g = a & b;

    // Carry lookahead: Compute all carries in parallel
    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & c[1]);
    assign c[3] = g[2] | (p[2] & c[2]);
    assign c[4] = g[3] | (p[3] & c[3]);

    // Sum = propagate XOR carry, output carry
    assign sum  = p ^ c[3:0];
    assign cout = c[4];
endmodule

// 32-bit Carry Look-Ahead Adder
// Built from 8 cascaded 4-bit CLA blocks
// Each block processes 4 bits and passes carry to next block
module cla_32bit (
    input  [31:0] a,
    input  [31:0] b,
    input         cin,
    output [31:0] sum,
    output        cout
);
    wire [7:0] carry;
    genvar i;

    // Generate 8 instances of 4-bit CLA blocks
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
// Multiplies two 16-bit numbers using array of partial products
// Each partial product is accumulated using CLA adders
module array_multiplier_cla (
    input  [15:0] a,
    input  [15:0] b,
    output [31:0] product
);

    wire [31:0] partial [15:0];
    wire [31:0] sum_stage [15:0];
    genvar i;

    // Generate 16 partial products
    // For each bit of multiplier b[i]:
    //   If b[i] = 1: partial product = multiplicand a shifted left by i positions
    //   If b[i] = 0: partial product = 0
    generate
        for (i = 0; i < 16; i = i + 1) begin : PARTIALS
            assign partial[i] = b[i] ? ({16'b0, a} << i) : 32'b0;
        end
    endgenerate

    // Accumulate partial products sequentially
    // sum_stage[0] = partial[0]
    // sum_stage[1] = sum_stage[0] + partial[1]
    // sum_stage[2] = sum_stage[1] + partial[2]
    // ...
    // sum_stage[15] = final product
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
