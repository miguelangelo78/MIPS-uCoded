`include "microcode.sv"

module Progmem(address, instruction);
	input [31:0] address;
	output [31:0] instruction;
	
	reg [31:0] mem [0:256];
	assign instruction = mem[address];
	
	/***************** Fill progmem here *****************/
	initial begin
		mem[0] = {6'h0, 5'h0,5'h0,16'h0}; /* LW */
		mem[1] = {6'h1, 5'h0,5'h0,16'h0}; /* SW */
		mem[2] = {6'h0, 5'h0,5'h0,16'h0}; /* LW */
		mem[3] = {6'h1, 5'h0,5'h0,16'h0}; /* SW */
		mem[4] = {6'h0, 5'h0,5'h0,16'h0}; /* LW */
		/* ADD */
		/* SUB */
		/* BEQ */
		/* JMP */
		
		/* End of memory: */
		mem[5] = {~6'h0, 26'h0}; /* Invalid Op */
	end
endmodule

module Datamem(address, writedata, readdata, mrd, mwr);
	input [31:0]address, writedata;
	input mrd, mwr;
	output reg [31:0] readdata;
	reg [31:0] mem [0:256]; 
	
	assign readdata = mrd ? mem[address] : 'hz;
	
	always@(posedge mwr) if(mwr) mem[address] = writedata;
		
	initial begin
		integer i;
		for(i = 0; i < 256; i++) mem[i] = 'hAC;
	end
endmodule

module Registers(readreg1, readreg2, writereg, writedata, regout1, regout2, regwr);
	input [4:0] readreg1,readreg2, writereg;
	input [31:0] writedata;
	output [31:0] regout1,regout2;
	input regwr;
	
	reg [31:0] regfile [0:32];
	
	assign regout1 = regfile[readreg1];
	assign regout2 = regfile[readreg2];
	
	initial begin
		integer i;
		for(i = 0;i < 32; i++) regfile[i] = 0;
	end
	
	always@(posedge regwr) if(regwr) regfile[writereg] = writedata;
endmodule

module ALU(opA, opB, func, zero, result);
	input [31:0] opA, opB;
	input [3:0] func;
	output zero;
	output [31:0] result;
	assign result = 
		func == 4'b0000 ? opA & opB : 
		func == 4'b0001 ? opA | opB :
		func == 4'b0010 ? opA + opB :
		func == 4'b0110 ? opA - opB :
		func == 4'b0111 ? (opA < opB ? 1 : 0) :
		func == 4'b1100 ? ~(opA | opB) : 'hX;
	assign zero = !result ? 1 : 0;
endmodule

module datapath;
	/* Generate clock: */
	reg clk; always #1 clk = en_clk ? ~clk : clk;
	reg en_clk;
	
	/* Instantiate microcode controller: */
	wire [`CTRL_WIDTH:0] ctrl;
	wire microcode_done; /* Signals when the microcode has finished executing a certain segment */
	reg microcode_restart; /* Triggers the execution of the microcode unit */
	Microcode microcode(clk, ctrl, instruction[31:26], microcode_done, microcode_restart);
	
	/* Control wires (connect it to microcode controller): */
	wire eip_inc = microcode_done;
	wire regdst = ctrl[0];
	wire jump = ctrl[1];
	wire branch = ctrl[2];
	wire memread = ctrl[3];
	wire memtoreg = ctrl[4];
	wire [1:0] aluop = ctrl[6:5];
	wire memwrite = ctrl[7];
	wire alusrc = ctrl[8];
	wire regwrite = ctrl[9];
	
	/* Program Counter: */
	reg [31:0] eip = 0;
	wire [31:0] eip_next = eip + 1;
	
	always@(posedge eip_inc or posedge clk) begin
		/* Trigger microcode execution: */
		if(eip_inc) begin
			eip <= 
				jump ? {eip_next[31:28], (instruction[25:0] << 2)} : 
				branch & zero ?  eip_next + ({16'h0, instruction[15:0]} << 2) : eip_next;
			microcode_restart <= 1;
		end
	end
	
	always@(negedge clk) microcode_restart = 0; /* Bring the microcode trigger down */
	
	/* Program Memory: */
	wire [31:0] instruction;
	Progmem progmem(eip, instruction);
	
	/* Registers: */
	wire [4:0] readreg1 = instruction[25:21];
	wire [4:0] readreg2 = instruction[20:16];
	wire [4:0] writereg = regdst ? instruction[15:11] : instruction[20:16];
	wire [31:0] prog_writedata = memtoreg ? readdata : result;
	wire [31:0] regout1, regout2;
	Registers registers(readreg1, readreg2, writereg, prog_writedata, regout1, regout2, regwrite);
	
	/* ALU: */
	wire [31:0] opA = regout1;
	wire [31:0] opB = alusrc ? {16'h0,instruction[15:0]} : regout2;
	wire [3:0] func = 
		/* ALU Control: */
		!aluop   ? 4'b0010 : 
		aluop[0] ? 4'b0110 :
		aluop[1] ? 
			( 
			  instruction[5:0] == 4'b0000 ? 4'b0010 :
			  instruction[5:0] == 4'b0010 ? 4'b0110 :
			  instruction[5:0] == 4'b0100 ? 4'b0000 :
			  instruction[5:0] == 4'b0101 ? 4'b0001 :
			  instruction[5:0] == 4'b1010 ? 4'b0111 :
			  'hx
			) 
		: 'hx;
	wire zero;
	wire [31:0] result;
	ALU alu(opA, opB, func, zero, result);
	
	/* Data Memory: */
	wire [31:0] address = result;
	wire [31:0] data_writedata = regout2;
	wire [31:0] readdata;
	Datamem datamem(address, data_writedata, readdata, memread, memwrite);
	
	/* Testbench: */
	initial begin
		$dumpfile("datapath.vcd");
		$dumpvars(0, datapath);
		
		/* Initialize: */
		microcode_restart = 0;
		en_clk = 0;
		clk = 0;
		
		/* Kickstart: */
		#1;
		clk = 1;
		microcode_restart = 1;
		en_clk = 1;
		
		/* Let it run for a while: */
		#50 $finish;
	end
endmodule
