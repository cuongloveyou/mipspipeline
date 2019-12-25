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
parameter beqOp = 6'b000100;

reg [63:0] IF_ID_reg;
reg [147:0] ID_EX_reg;
reg [84:0] EX_MEM_reg;

reg [31:0] Imemory [0:1023]; //InstructionMemory
reg [31:0] PCcurrent, PCnext, readdata; 
reg [1:0] check;

reg [31:0] readData1, readData2, signExtend, shiftOut; //Decode
reg [5:0] opcodeReg;
reg [31:0] PCnextID;
reg [4:0] rt;
reg [4:0] rd;

reg [31:0] ALUresult; // alu
reg [5:0] WriteAddr;
reg [5:0] ReadAddr;
reg [31:0] BranchAddr;
reg [8:0] controlEX;

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
		
		memory[1] <= 32'h00000003;
		
		PCnext = 0;	
		check = 2'b00;
		
end
	
always @ (posedge clk) //pc	   //InstructionMemory
	begin	 
	  if (EX_MEM_reg[83] == 1) //branch
	    begin
	      PCnext = EX_MEM_reg[75:44];
	    end
	  if (check == 2'b00)
	    begin
	      PCcurrent = PCnext;
	      PCnext = PCnext + 4;
        readdata = Imemory[PCcurrent>>2]; // Insmem
        if (readdata[31:26] == beqOp)
          begin
            check = 2'b10;
          end
      end
    else check = check - 1;
	end			

always @(negedge clk)
begin
        IF_ID_reg = {PCnext, readdata};
end

assign opcode = opcodeReg;

always @(posedge clk) // Decode
  begin
    opcodeReg = IF_ID_reg[31:26];
    readData1 = memoryReg[IF_ID_reg[25:21]];
    readData2 = memoryReg[IF_ID_reg[20:16]];
    if (IF_ID_reg[15] == 1) signExtend = {16'b1111111111111111, IF_ID_reg[15:0]};
    else signExtend = {16'b0000000000000000, IF_ID_reg[15:0]};
    shiftOut = {signExtend[29:0], x2bitZero};
    PCnextID = IF_ID_reg[63:32];
    rt = IF_ID_reg[20:16];
    rd = IF_ID_reg[15:11];
  end

always @(negedge clk)
begin
  ID_EX_reg = {control, PCnextID, readData1, readData2, shiftOut, rt, rd};
                            // pcnext
end

always @(posedge clk) // ALU
begin
  case (ID_EX_reg[139:138]) //aluop
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
          ReadAddr = ID_EX_reg[105:74];
          WriteAddr = ID_EX_reg[9:5] + ID_EX_reg[17:12];
        end
    sw:
        begin
          //ReadAddr = ID_EX_reg[9:5];
          ALUresult = ID_EX_reg[73:42];
          WriteAddr = ID_EX_reg[4:0] + ID_EX_reg[17:12];
        end
    beq:
        begin
          if (ID_EX_reg[105:74] == ID_EX_reg[73:42])
            begin
              $display("%d", ID_EX_reg[137:106]);
              $display("%d", ID_EX_reg[41:10]);
              BranchAddr = ID_EX_reg[137:106] + ID_EX_reg[41:10];
            end
          else 
            begin
              BranchAddr = ID_EX_reg[137:106];
            end
        end
    endcase
    controlEX = ID_EX_reg[146:138];
end

always @(negedge clk)
begin
    EX_MEM_reg = {controlEX, BranchAddr, ALUresult, ReadAddr, WriteAddr};
end

always @(posedge clk) // DataMem
  begin
    if(EX_MEM_reg[80] == 1) // MemWrite
    begin
      memory[EX_MEM_reg[5:0]] = EX_MEM_reg[43:12]; // writeAddr __ ALUresult
      $display("sw %b",EX_MEM_reg[43:12]);
    end
    
    if (EX_MEM_reg[82] == 1) // MemRead MemToReg lw
    begin
      memoryReg[EX_MEM_reg[5:0]] = memory[EX_MEM_reg[11:6]]; // writeAddr __ readAddr
              $display("w %b", EX_MEM_reg[5:0]);
              $display("dr %b", memoryReg[EX_MEM_reg[5:0]]);
      
    end
    
    if (EX_MEM_reg[79] == 1) //RegWrite
    begin
      memoryReg[EX_MEM_reg[5:0]] = EX_MEM_reg[43:12]; // writeAddr __ ALUresult
    end
  end
endmodule