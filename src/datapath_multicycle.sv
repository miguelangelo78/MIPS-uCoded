`include "microcode.sv"

module PC(ip_next, pc_wr, ip);
	input [31:0] ip_next;
	input pc_wr;
	output reg [31:0] ip = 0;
	always@(posedge pc_wr) ip = ip_next;
endmodule

module Memory(address, data_in, data_out, memread, memwrite);
	input [31:0] address;
	input [31:0] data_in;
	output [31:0] data_out;
	input memread, memwrite; 
	
	reg [31:0] memory [0:256];
	
	assign data_out = memread ? memory[address] : 'hZ;
	always@(posedge memwrite) memory[address] = data_in;
		
	initial begin
		memory[0] = {6'h0, 5'h0,5'h0,16'h0}; /* LW */
		memory[1] = {6'h1, 5'h0,5'h0,16'h0}; /* SW */
		memory[2] = {6'h0, 5'h0,5'h0,16'h0}; /* LW */
		memory[3] = {6'h1, 5'h0,5'h0,16'h0}; /* SW */
		memory[4] = {6'h0, 5'h0,5'h0,16'h0}; /* LW */
		/* ADD */
		/* SUB */
		/* BEQ */
		/* JMP */
		
		/* End of memory: */
		memory[5] = {~6'h0, 26'h0}; /* Invalid Op */
	end
endmodule

module InstructionReg(instr_in, instr_out, irwrite);
	input [31:0] instr_in;
	output reg [31:0] instr_out = 0;
	input irwrite;
	
	always@(posedge irwrite) instr_out = instr_in;
endmodule

module MDR(clk, data_in, data_out);
	input clk;
	input [31:0] data_in;
	output reg [31:0] data_out = 0;
	
	always@(posedge clk) data_out = data_in;
endmodule

module Registers(clk, readreg1, readreg2, writereg, writedata, outA, outB, regwr);
	input clk;
	input [4:0] readreg1,readreg2, writereg;
	input [31:0] writedata;
	output reg [31:0] outA = 0;
	output reg [31:0] outB = 0;
	input regwr;
	
	reg [31:0] regfile [0:32];
	
	always@(posedge clk) begin
		outA = regfile[readreg1];
		outB = regfile[readreg2];	
	end
	
	initial begin
		integer i;
		for(i = 0; i < 32; i++) regfile[i] = 0;
	end
	
	always@(posedge regwr) if(regwr) regfile[writereg] = writedata;
endmodule

module ALU(clk, opA, opB, func, zero, result, aluout);
	input clk;
	input [31:0] opA, opB;
	input [3:0] func;
	output zero;
	output [31:0] result;
	output reg [31:0] aluout = 0;
	assign result = 
		func == 4'b0000 ? opA & opB : 
		func == 4'b0001 ? opA | opB :
		func == 4'b0010 ? opA + opB :
		func == 4'b0110 ? opA - opB :
		func == 4'b0111 ? (opA < opB ? 1 : 0) :
		func == 4'b1100 ? ~(opA | opB) : 'hX;
	assign zero = !result ? 1 : 0;
	
	always@(posedge clk) aluout = result;
endmodule

module datapath_multicycle;
	/* Generate clock: */
	reg clk; always #1 clk = en_clk ? ~clk : clk;
	reg en_clk;
	
	/* Instantiate microcode controller: */
	wire [`CTRL_WIDTH:0] ctrl;
	wire microcode_done; /* Signals when the microcode has finished executing a certain segment */
	reg microcode_restart; /* Triggers the execution of the microcode unit */
	Microcode microcode(clk, ctrl, instr_out[31:26], microcode_done, microcode_restart);
	
	/* Bring the microcode trigger down every negative clock edge: */
	always@(negedge clk) microcode_restart <= 0;
	
	/* Control wires (connect it to microcode controller): */
	wire pcwritecond = ctrl[0];
	wire pcwrite = ctrl[1];
	wire iord = ctrl[2];
	wire memread = ctrl[3];
	wire memwrite = ctrl[4];
	wire memtoreg = ctrl[5];
	wire irwrite = ctrl[6];
	wire [1:0] pcsource = ctrl[8:7];
	wire [1:0] aluop = ctrl[10:9];
	wire [1:0] alusrcb = ctrl[12:11];
	wire alusrca = ctrl[13];
	wire regwrite = ctrl[14];
	wire regdst = ctrl[15];
	
	/* Program Counter: */
	wire [31:0] ip_next = pcsource == 2'b00 ? result : pcsource == 2'b01 ? aluout : pcsource == 2'b10 ? instr_out[25:0] << 2 : 0;
	wire [31:0] ip;
	wire pc_wr = (zero & pcwritecond) | pcwrite;
	PC pc(ip_next, pc_wr, ip);
	
	/* Memory: */
	wire [31:0] mem_addr = iord ? aluout : ip;
	wire [31:0] mem_data_in = outB;
	wire [31:0] mem_data_out;
	Memory memory(mem_addr, mem_data_in, mem_data_out, memread, memwrite);
	
	/* Instruction Register: */
	wire [31:0] instr_in = mem_data_out;
	wire [31:0] instr_out;
	InstructionReg instructionReg(instr_in, instr_out, irwrite);
	
	/* Memory Data Register: */
	wire [31:0] mdr_data_in = mem_data_out;
	wire [31:0] mdr_data_out;
	MDR mdr(clk, mdr_data_in, mdr_data_out);
	
	/* Registers: */
	wire [4:0]  readreg1 = instr_out[25:21];
	wire [4:0]  readreg2 = instr_out[20:16];
	wire [4:0]  writereg = regdst ? instr_out[15:11] : instr_out[20:16];
	wire [31:0] writedata = memtoreg ? mdr_data_out : aluout;
	wire [31:0] outA, outB;
	Registers   registers(clk, readreg1, readreg2, writereg, writedata, outA, outB, regwrite);
	
	/* ALU: */
	wire [31:0] opA = alusrca ? outA : ip;
	wire [31:0] opB = alusrcb == 2'b00 ? outB : alusrcb == 2'b01 ? 1 : alusrcb == 2'b10 ? {16'h0,instr_out[15:11]} : {16'h0,instr_out[15:11]} << 2;
	wire [3:0] func =
		/* ALU Control: */
		!aluop   ? 4'b0010 :
		aluop[0] ? 4'b0110 :
		aluop[1] ?
			(
			  instr_out[5:0] == 4'b0000 ? 4'b0010 :
			  instr_out[5:0] == 4'b0010 ? 4'b0110 :
			  instr_out[5:0] == 4'b0100 ? 4'b0000 :
			  instr_out[5:0] == 4'b0101 ? 4'b0001 :
			  instr_out[5:0] == 4'b1010 ? 4'b0111 :
			  'hX
			)
		: 'hX;
	wire zero;
	wire [31:0] result;
	wire [31:0] aluout;
	ALU alu(clk, opA, opB, func, zero, result, aluout);
	
	/* Testbench: */
	initial begin
		$dumpfile("datapath_multicycle.vcd");
		$dumpvars(0, datapath_multicycle);
		
		/* Initialize: */
		microcode_restart = 0;
		en_clk = 0;
		clk = 0;
		
		/* Kickstart: */
		#1;
		clk = 1;
		en_clk = 1;
		microcode_restart = 1;
		
		/* Let it run for a while: */
		#50 $finish;
	end
endmodule
