`define CTRL_WIDTH 32
`define CTRL_DEPTH 256
`define SEGMENT_MAXCOUNT 256
`define CTRL_DEPTH_ENC ($clog2(`CTRL_DEPTH) - 1)
`define SEGMENT_MAXCOUNT_ENC ($clog2(`SEGMENT_MAXCOUNT) - 1)

/* Change this macro to 0 to convert the microcode unit 
 * into a multicycle microcode unit */
`define SINGLECYCLE 0

module Microcode(clk, ctrl, opcode, eos, sos);

/************************* PORT DEFINITIONS *************************/
input clk;
output reg [`CTRL_WIDTH:0] ctrl = 0;
input [5:0] opcode;
/* End of segment: signals the outer system that its execution is finished, and will wait until a sos signal is received */
output eos;
assign eos = ctrl[`CTRL_WIDTH]; /* It's the very last bit of the control bus */
/* Start of segment: triggers the execution of the next segment */
input sos;

/************************* LOCAL VARIABLES *************************/
reg [`CTRL_DEPTH_ENC:0] code_ip = 0; /* Microcode instruction pointer */
reg [`CTRL_WIDTH:0] code [0:`CTRL_DEPTH]; /* Microcode memory */
reg [`SEGMENT_MAXCOUNT_ENC:0] seg_start [`SEGMENT_MAXCOUNT]; /* Start of the segment */
integer segment_counter = 0;
integer microinstr_ctr = 0;
reg microunit_running = 1;

/************************* SYSTEM PROCESSES *************************/
always@(posedge clk) begin
	/* Check for invalid/halt opcode: */
	check_microcode_running;
	if(microunit_running && code_ip != 'hFF && !eos) begin
		/* Only continue sequentially when EOS is 0 */
		ctrl = code[code_ip];
		code_ip = code_ip + 1;
	 end else begin end; /* Microcode unit is frozen. Needs to be restarted */
end

always@(posedge sos) begin
	check_microcode_running;
	/* Jump to segment before fetching control: */
	if(microunit_running) begin
		code_ip = seg_start[opcode];
		ctrl = code[code_ip];
	end
end


/************************* FUNCTIONS *************************/
task check_microcode_running; begin
	microunit_running = opcode == ~6'h0 ? 1'b0 : 1'b1;
end endtask

task microinstr;
	input reg [31:0] control;
	input integer is_sos; /* Is start of segment? */
	input integer is_eos; /* Is end of segment? */
begin
	/* Create Segment: */
	if(is_sos) begin
		seg_start[segment_counter] = microinstr_ctr;
		segment_counter = segment_counter + 1;
	end
	
	/* Generate Segment Terminator signal: */
	code[microinstr_ctr] = {is_eos ? 1'b1 : 1'b0, control};
	microinstr_ctr = microinstr_ctr + 1;
end endtask

task microinstr_finish; begin
	/* Fill the rest with 0s in order to keep the CPU frozen */
	for(microinstr_ctr=microinstr_ctr; microinstr_ctr < `CTRL_DEPTH; microinstr_ctr++) 
		code[microinstr_ctr] = 0;
	/* Fill the rest of the segments with invalid pointers */
	for(segment_counter = segment_counter; segment_counter < `SEGMENT_MAXCOUNT; segment_counter++)
		seg_start[segment_counter] = ~0;
end endtask

/************************** MICROCODE BEGIN SECTION **************************/
initial begin
	/* Program Microcode for each instruction here: */
if(`SINGLECYCLE) begin
	microinstr(32'b1100011000, 1, 1); /* LW */
	microinstr(32'b0110000000, 1, 1); /* SW */
	/* ADD */
	/* SUB */
	/* AND */
	/* OR */
	/* SLT */
	/* BEQ */
	/* JMP */
end else begin
	microinstr(32'b1100011000, 1, 1); /* LW */
	microinstr(32'b0110000000, 1, 1); /* SW */
	/* ADD */
	/* SUB */
	/* AND */
	/* OR */
	/* SLT */
	/* BEQ */
	/* JMP */
end
	microinstr_finish;
end
endmodule
