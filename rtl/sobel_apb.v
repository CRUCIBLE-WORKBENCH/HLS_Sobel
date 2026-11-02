module sobel_apb (
    input wire pclk,preset_n,psel,penable,pwrite,
    input wire [7:0] paddr,
    input wire [31:0] pwdata,
    output wire pready,
    output wire pslverr,
    output reg [31:0] prdata
);
    reg [31:0] pixels0,pixels1,pixels2;
    reg busy,done,start;
    reg [7:0] result;
    wire core_done;
    wire [7:0] core_result;
    wire access=psel && penable;
    wire pixel_addr=(paddr==8'h10 || paddr==8'h14 || paddr==8'h18);
    wire valid_addr=(paddr==0 || paddr==4 || paddr==8 || pixel_addr);
    assign pready=1;
    assign pslverr=access && (!valid_addr ||
        (pwrite && (paddr==4 || paddr==8 || (busy && (pixel_addr || (paddr==0 && pwdata[0]))))));
    always @* begin
        case(paddr)
            0: prdata=0;
            4: prdata={30'b0,done,busy};
            8: prdata={24'b0,result};
            8'h10: prdata=pixels0;
            8'h14: prdata=pixels1;
            8'h18: prdata=pixels2;
            default: prdata=0;
        endcase
    end
    always @(posedge pclk or negedge preset_n) begin
        if(!preset_n) begin
            pixels0<=0;pixels1<=0;pixels2<=0;busy<=0;done<=0;start<=0;result<=0;
        end else begin
            start<=0;
            if(busy && core_done) begin result<=core_result;busy<=0;done<=1;end
            if(access && pwrite && !pslverr) begin
                case(paddr)
                    0: if(pwdata[0]) begin start<=1;busy<=1;done<=0;end
                    8'h10:pixels0<=pwdata;
                    8'h14:pixels1<=pwdata;
                    8'h18:pixels2<=pwdata;
                    default:begin end
                endcase
            end
        end
    end
    // The adapter only maps the actual generated core ports. It contains no
    // Sobel arithmetic or replacement behaviour.
    sobel_core_adapter core(.clock(pclk),.reset_n(preset_n),.start(start),
        .pixels({pixels2[7:0],pixels1,pixels0}),.done(core_done),.result(core_result));
endmodule
