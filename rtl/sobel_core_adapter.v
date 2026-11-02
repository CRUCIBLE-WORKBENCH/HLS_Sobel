module sobel_core_adapter (
    input wire clock,reset_n,start,
    input wire [71:0] pixels,
    output wire done,
    output wire [7:0] result
);
    // Bambu's generated reset is synchronous, active low. Pixel byte 0 is p0.
    sobel3x3 generated_core(.clock(clock),.reset(reset_n),.start_port(start),
        .done_port(done),.return_port(result),
        .p0(pixels[7:0]),.p1(pixels[15:8]),.p2(pixels[23:16]),
        .p3(pixels[31:24]),.p4(pixels[39:32]),.p5(pixels[47:40]),
        .p6(pixels[55:48]),.p7(pixels[63:56]),.p8(pixels[71:64]));
endmodule
