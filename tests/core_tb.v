`timescale 1ns/1ps
module core_tb;
reg clock=0,reset_n=0,start=0;
reg [71:0] pixels=0;
wire done;
wire [7:0] result;
`include "vector_count.vh"
reg [79:0] vectors[0:VECTOR_COUNT-1];
integer i,cycles,maximum_cycles=0;
always #10 clock=~clock;
sobel_core_adapter dut(clock,reset_n,start,pixels,done,result);
initial begin
    if($test$plusargs("BAD_EXPECTED"))$readmemh("reference/corrupt_expected.mem",vectors);
    else $readmemh("reference/vectors.mem",vectors);
    repeat(3)@(negedge clock);reset_n=1;
    for(i=0;i<VECTOR_COUNT;i=i+1)begin
        @(negedge clock);pixels=vectors[i][71:0];start=1;
        @(posedge clock);#1;cycles=1;
        @(negedge clock);start=0;
        while(done !== 1'b1 && cycles<100)begin @(posedge clock);#1;cycles=cycles+1;end
        if(done !== 1'b1)$fatal(1,"SOBEL_CORE_TIMEOUT vector=%0d",i);
        if(result !== vectors[i][79:72])$fatal(1,"SOBEL_CORE_MISMATCH vector=%0d expected=%0d got=%0d",i,vectors[i][79:72],result);
        if(cycles>maximum_cycles)maximum_cycles=cycles;
        @(negedge clock);
    end
    $display("SOBEL_GENERATED_CORE_PASS vectors=%0d max_cycles=%0d",VECTOR_COUNT,maximum_cycles);$finish;
end
initial begin #20000000;$fatal(1,"TEST_TIMEOUT");end
endmodule
