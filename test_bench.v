module MIPS_PIPELINE_TB();
  reg clk, reset;
  
  MIPS_PIPELINE tb(clk, reset);
  
  initial
  begin
    clk = 0;
    while (1)
    begin
      #10
      clk = ~clk; // chu ky = 20
    end
  end
  initial
  begin
    reset = 0;
    #20
    reset = 1;
    #10
    reset = 0;
  end
endmodule
