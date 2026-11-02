`timescale 1ns/1ps
module apb_tb;
reg clock=0,reset_n=0,psel=0,penable=0,pwrite=0;
reg [7:0] addr=0;
reg [31:0] wdata=0;
wire ready,err;
wire [31:0] rdata;
reg [31:0] value;
`include "vector_count.vh"
reg [79:0] vectors[0:VECTOR_COUNT-1];
integer i,polls,checks=0,maximum_polls=0;
always #10 clock=~clock;
sobel_apb dut(.pclk(clock),.preset_n(reset_n),.psel(psel),.penable(penable),
    .pwrite(pwrite),.paddr(addr),.pwdata(wdata),.pready(ready),.pslverr(err),.prdata(rdata));
task access;
input wr;
input [7:0] address;
input [31:0] data;
input expected_error;
begin
    @(negedge clock);psel=1;penable=0;pwrite=wr;addr=address;wdata=data;
    @(negedge clock);penable=1;#1;
    checks=checks+1;
    if(ready !== 1'b1 || err !== expected_error)$fatal(1,"SOBEL_APB_RESPONSE vector=%0d addr=%h ready=%b err=%b",i,address,ready,err);
    @(posedge clock);#1;value=rdata;
    @(negedge clock);psel=0;penable=0;pwrite=0;
end
endtask
task check_value;
input [31:0] expected;
begin
    checks=checks+1;
    if(value !== expected)$fatal(1,"SOBEL_APB_MISMATCH vector=%0d expected=%0d got=%0d",i,expected,value);
end
endtask
initial begin
    if($test$plusargs("BAD_EXPECTED"))$readmemh("reference/corrupt_expected.mem",vectors);
    else $readmemh("reference/vectors.mem",vectors);
    repeat(3)@(negedge clock);reset_n=1;
    access(0,4,0,0);check_value(0);
    access(0,8,0,0);check_value(0);
    access(1,4,32'hffffffff,1);
    access(1,8,32'hffffffff,1);
    access(0,8'h0c,0,1);
    access(1,8'h11,32'hffffffff,1);
    // Setup alone cannot modify a pixel register.
    @(negedge clock);psel=1;penable=0;pwrite=1;addr=8'h10;wdata=32'hffffffff;
    repeat(3)@(negedge clock);psel=0;pwrite=0;
    access(0,8'h10,0,0);check_value(0);
    // Start, status and result transfers with PSEL held high and no idle cycle.
    // The generated combinational core finishes before the next legal ACCESS.
    @(negedge clock);psel=1;penable=0;pwrite=1;addr=0;wdata=1;
    @(negedge clock);penable=1;#1;
    if(err !== 0)$fatal(1,"SOBEL_APB_CONSECUTIVE_START");
    @(posedge clock);#1;
    if(dut.busy !== 1 || dut.done !== 0)$fatal(1,"SOBEL_APB_START_STATE");
    @(negedge clock);penable=0;pwrite=0;addr=4;
    @(negedge clock);penable=1;
    @(posedge clock);#1;
    if(err !== 0 || rdata !== 2)$fatal(1,"SOBEL_APB_CONSECUTIVE_STATUS");
    @(negedge clock);penable=0;addr=8;
    @(negedge clock);penable=1;
    @(posedge clock);#1;
    if(err !== 0 || rdata !== 0)$fatal(1,"SOBEL_APB_CONSECUTIVE_RESULT");
    @(negedge clock);psel=0;penable=0;
    checks=checks+4;
    for(i=0;i<VECTOR_COUNT;i=i+1)begin
        access(1,8'h10,vectors[i][31:0],0);
        access(0,8'h10,0,0);check_value(vectors[i][31:0]);
        access(1,8'h14,vectors[i][63:32],0);
        access(0,8'h14,0,0);check_value(vectors[i][63:32]);
        access(1,8'h18,{24'b0,vectors[i][71:64]},0);
        access(0,8'h18,0,0);check_value({24'b0,vectors[i][71:64]});
        access(1,0,1,0);
        polls=0;value=0;
        while(value[1] !== 1'b1 && polls<100)begin access(0,4,0,0);polls=polls+1;end
        if(value[1] !== 1'b1 || value[0] !== 1'b0)$fatal(1,"SOBEL_APB_TIMEOUT vector=%0d status=%h",i,value);
        if(polls>maximum_polls)maximum_polls=polls;
        access(0,8,0,0);check_value({24'b0,vectors[i][79:72]});
    end
    reset_n=0;repeat(2)@(negedge clock);reset_n=1;
    access(0,4,0,0);check_value(0);access(0,8,0,0);check_value(0);
    $display("SOBEL_APB_PASS vectors=%0d checks=%0d max_polls=%0d",VECTOR_COUNT,checks,maximum_polls);$finish;
end
initial begin #50000000;$fatal(1,"TEST_TIMEOUT");end
endmodule
