module MIPS_PIPELINE(
  input clk,
  input reset
  );

wire [5:0] opcode;
wire [8:0] control;

ControlUnit controlUnit(reset, opcode, control);
Datapath dataPath(clk, reset, control, opcode);

endmodule