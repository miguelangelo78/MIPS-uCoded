`include "microcode.sv"



module datapath_multicycle;
	/* Generate clock: */
	reg clk; always #1 clk = en_clk ? ~clk : clk;
	reg en_clk;
	
	initial begin
		$dumpfile("datapath_multicycle.vcd");
		$dumpvars(0, datapath_multicycle);
		
		/* Initialize: */
		en_clk = 0;
		clk = 0;
		
		/* Kickstart: */
		#1;
		clk = 1;
		en_clk = 1;
		
		/* Let it run for a while: */
		#50 $finish;
	end
endmodule
