module Datapath(
  input clk,
  input reset,
  input [8:0] control,
  output [5:0] opcode
  );  
  
parameter R_type = 2'b00; // alu
parameter lw = 2'b01;  
parameter sw = 2'b10;  
parameter beq = 2'b11;
parameter add = 6'h20;
parameter sub = 6'h22;
parameter x16bitZero = 16'h0000;
parameter x2bitZero = 2'b00;

reg [63:0] IF_ID_reg;
reg [147:0] ID_EX_reg;
reg [82:0] EX_MEM_reg;

reg [31:0] Imemory [0:1023]; //InstructionMemory
reg [31:0] PCcurrent, PCnext; 

reg [31:0] readData1, readData2, signExtend, shiftOut; //Decode
reg [5:0] opcodeReg;

reg [31:0] ALUresult; // alu
reg [5:0] WriteAddr;
reg [5:0] ReadAddr;
reg [31:0] BranchAddr;

reg [31:0] memory [0:31]; // datamem
reg [31:0] memoryReg[0:31];

initial //load code
	begin
		$readmemh("code.txt",Imemory);
	end
	
always @(posedge reset) // initial mem
begin
    memoryReg[0] <= 32'h00000000;
		memoryReg[8] <= 32'h00000001;
		memoryReg[9] <= 32'h00000002;
		memoryReg[10] <= 32'h00000000;
		memoryReg[11] <= 32'h00000000;
		memoryReg[12] <= 32'h00000000;
		memoryReg[13] <= 32'h00000000;
		memoryReg[14] <= 32'h00000000;
		memoryReg[15] <= 32'h00000000;
		memoryReg[16] <= 32'h00000000;
		memoryReg[17] <= 32'h00000000;
		memoryReg[18] <= 32'h00000003;
		memoryReg[19] <= 32'h00000003;
		memoryReg[20] <= 32'h00000004;
		memoryReg[21] <= 32'h00000000;
		memoryReg[22] <= 32'h00000008;
		memoryReg[23] <= 32'h00000000;
		memoryReg[24] <= 32'h00000000;
		memoryReg[25] <= 32'h00000000;
		memoryReg[31] <= 32'h00000000;			
		
		PCnext = 0;	
		
end
	
always @ (posedge clk) //pc	   //InstructionMemory
	begin	 
	  if (control[7] == 1)
	    begin
	      PCnext = EX_MEM_reg[73:42];
	    end
	  PCcurrent = PCnext;
	  PCnext = PCnext + 4;
    //readdata <= Imemory[pc>>2]; // Insmem
    IF_ID_reg = {PCnext, Imemory[PCcurrent>>2]};
	end			

assign opcode = opcodeReg;

always @(negedge clk) // Decode
  begin
    opcodeReg = IF_ID_reg[31:26];
    readData1 = memoryReg[IF_ID_reg[25:21]];
    readData2 = memoryReg[IF_ID_reg[20:16]];
    signExtend = {x16bitZero, IF_ID_reg[15:0]};
    shiftOut = {signExtend[29:0], x2bitZero};
    ID_EX_reg = {control, IF_ID_reg[63:32], readData1, readData2, shiftOut, IF_ID_reg[20:16], IF_ID_reg[15:11]};
                            // pcnext
  end

always @(posedge clk) // ALU
begin
  case (control[1:0]) //aluop
    R_type:
      begin
        case (ID_EX_reg[17:12]) //function
          add: 
            begin
              ALUresult = ID_EX_reg[105:74] + ID_EX_reg[73:42];
              WriteAddr = ID_EX_reg[4:0];
            end
          sub:
            begin
              ALUresult = ID_EX_reg[105:74] - ID_EX_reg[73:42];
              WriteAddr = ID_EX_reg[4:0];
            end
          endcase
      end
    lw:
        begin
          ReadAddr = ID_EX_reg[9:5] + ID_EX_reg[17:12];
          WriteAddr = ID_EX_reg[4:0];
        end
    sw:
        begin
          ReadAddr = ID_EX_reg[9:5];
          WriteAddr = ID_EX_reg[4:0] + ID_EX_reg[17:12];
        end
    beq:
        begin
          if (ID_EX_reg[105:74] == ID_EX_reg[73:42])
            begin
              BranchAddr = ID_EX_reg[137:106] + ID_EX_reg[41:10];
            end
          else 
            begin
              BranchAddr = ID_EX_reg[137:106];
            end
        end
    endcase
    EX_MEM_reg = {control, BranchAddr, ALUresult, ReadAddr, WriteAddr};
end

always @(negedge clk) // DataMem
  begin
    if(EX_MEM_reg[80] == 1) // MemWrite
    begin
      memory[EX_MEM_reg[5:0]] = EX_MEM_reg[43:12]; // writeAddr __ ALUresult
    end
    
    if (EX_MEM_reg[82] == 1) // MemRead MemToReg
    begin
      memoryReg[EX_MEM_reg[5:0]] = memory[EX_MEM_reg[11:6]]; // writeAddr __ readAddr
    end
    
    if (EX_MEM_reg[79] == 1) //RegWrite
    begin
      $display("writeReg");
      memoryReg[EX_MEM_reg[5:0]] = EX_MEM_reg[43:12]; // writeAddr __ ALUresult
    end
  end
endmodule