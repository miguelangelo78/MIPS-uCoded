`define CTRL_WIDTH 32
`define CTRL_DEPTH 256

module Microcode(clk, ctrl, opcode);
	
input clk;
output reg [`CTRL_WIDTH-1:0] ctrl = 0;
input [5:0] opcode;

wire next_segment_signal = ctrl[0]; /* First bit of output will signal an instruction fetch request */

/* Local Variables: */
reg [7:0] code_ip = 0;
reg [`CTRL_WIDTH-1:0] code [0:`CTRL_DEPTH];
reg [7:0] seg_start [10]; /* Start of the segment */
integer segment_counter = 0;
integer microinstr_ctr = 0;
integer microunit_running = 1;

always@(posedge clk) begin
	if(opcode == ~6'h0) microunit_running = 0;
	
	if(code_ip != 'hFF && microunit_running) begin
		if(next_segment_signal) begin 
			/* Jump to segment before fetching control: */
			code_ip = seg_start[opcode];
			ctrl = code[code_ip];
		end else begin
			ctrl = code[code_ip];
			/* Fetch next microcode (sequentially) */
			code_ip = code_ip + 1;
		end
	end else begin
		ctrl = 0; /* Microcode unit is frozen. Needs to be restarted */
	end
end

task microinstr;
	input reg [30:0] control;
	input integer is_sos; /* Is start of segment? */
	input integer is_eos; /* Is end of segment? */
begin
	/* Create Segment: */
	if(is_sos) begin
		seg_start[segment_counter] = microinstr_ctr;
		segment_counter = segment_counter + 1;
	end
	
	/* Generate Segment Terminator signal: */
	code[microinstr_ctr] = {control, is_eos ? 1'b1 : 1'b0};
	microinstr_ctr = microinstr_ctr + 1;
end endtask

task microinstr_finish; begin
	/* Fill the rest with 0s in order to keep the CPU frozen */
	for(microinstr_ctr=microinstr_ctr; microinstr_ctr < `CTRL_DEPTH; microinstr_ctr++) 
		code[microinstr_ctr] = 0;
	/* Fill the rest of the segments with invalid pointers */
	for(segment_counter = segment_counter; segment_counter < 10; segment_counter++)
		seg_start[segment_counter] = ~0;
end endtask

/************************** MICROCODE BEGIN SECTION **************************/
initial begin
	/* Program Microcode for each instruction here: */
	microinstr(31'b1100011000, 1, 1); /* LW */
	microinstr(31'b0110000000, 1, 1); /* SW */
	/* ADD */
	/* SUB */
	/* AND */
	/* OR */
	/* SLT */
	/* BEQ */
	/* JMP */
	microinstr_finish;
end
endmodule
