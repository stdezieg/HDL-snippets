
// @HOCHSCHULE DARMSTADT h_da

/**
 *		##### Based on the "state_machine_toplevel_framework"-template, Copyright by Dr. Prof. Jakob.
 */
 

/**
 *		##### 40-CYCLES SHA1-KERNEL - IMPLEMENTATION COPYRIGHT BY:
 *		#####
 *		##### VITALIJ T******, 		******
 *		##### DENNIS Z********, 	******
 *		####  LUKAS N*******,		******
 *		#####
 *		##### Complex Digital Architectures - Summer Term 2019 - Hochschule Darmstadt
 */


package sha1_kernel_definitions;

	
	enum logic [1:0] {__RESET = 2'b00, __IDLE = 2'b01, __PROC = 2'b10, __DONE = 2'b11} state;		// enum-defines for the state
	enum logic [1:0] {__CH = 2'b00, __PARITY = 2'b01, __MAY = 2'b10, __PARITY2 = 2'b11} func;		// enum-defines for the "Sha1-Kernel"-functions
	

endpackage


/**
 *		The following combinational-modules describe each function of the SHA1-Kernel.
 */

module ch_SHA1(
	input logic [31:0] x, y, z,  
	output logic [31:0] w
	);
	
	assign w = (x&y) | (~x&z);
	
endmodule

module parity_SHA1(
	input logic [31:0] x, y, z,
	output logic [31:0] w
	);
	
	assign w = x^y^z;
	
endmodule

module may_SHA1(
	input logic [31:0] x, y, z,
	output logic [31:0] w
	);
	
	assign w = (x&y) | (x&z) | (y&z);
	
endmodule


module rotl_SHA1(
	input logic [31:0] n, x,
	output logic [31:0] w
	);
	
	assign w = (x << n) | (x >> (32-n));
	
endmodule

/**
 *		End of the dedicated function-modules.
 */
 
 
 
	


module sha1_kernel(
	input logic clk, input logic reset_n, input logic start,

	// The 512-Bit preprocessed input message provided by the testbench.
	// Input-Message: CDA is fun 2019
	input logic [31:0] splits_ [15:0],
	
	// The output of the final SHA1-Hash
	output logic [31:0] aOut_, bOut_, cOut_, dOut_ ,eOut_,
	
	);
	
	// Importing the enum-defines
	import sha1_kernel_definitions::*;
	
	// Defining Loop-Itereation and the coresponding BITWIDTHs of the step-counters.
	localparam LOOP_ITERATIONS_40 = 40;							// For the 40-Cycles SHA1
	localparam ITERATIONS_40 = LOOP_ITERATIONS_40 - 1;
	localparam BITWIDTH_40   = $clog2(ITERATIONS_40);

	/*localparam LOOP_ITERATIONS_80 = 80;							// Needed seperate BITWIDTH of the 80-Cycles for the padded message.
	localparam ITERATIONS_80 = LOOP_ITERATIONS_80 - 1;
	localparam BITWIDTH_80   = $clog2(ITERATIONS_80);	

    */
	
	logic [31:0] splits [79:0] = '{default:0};		// Will contain the padded message. Needs to have a size of 80 for a proper SHA1-Kernel calculation.
																	// Loaded from tb.
																	// Inits with 0's.
	
	logic [31:0] k[3:0] = '{32'hca62c1d6,32'h8f1bbcdc,32'h6ed9eba1,32'h5a827999};							// K-Factor		Note: In brackets {Highest to Lowest Idx}.
	logic [31:0] mag[4:0] = '{32'hC3D2E1F0,32'h10325476,32'h98BADCFE,32'hEFCDAB89,32'h67452301};		// Magic number ? needed?
	
	
	// Temporary logics used by the function-modules (80-Cycles SHA-1 only).
	logic [31:0] temp_CH, temp_R5, temp_R30, temp_R1, temp_PARITY, temp_MAY;			
	
	// Needed in Addition for the 40-Cycles SHA1-Kernel.
	logic [31:0] temp_R5_bIn_PARITY, temp_R30_bIn, temp_R1_splitCount2, temp_R30_aIn, 
	temp_CH_sec, temp_PARITY_sec, temp_MAY_sec, temp_R5_bIn, temp_R1_splitCount, temp_R5_bIn_pre, 
	temp_R5_bIn_pre_PARITY, temp_R5_bIn_pre_CH ,temp_R5_bIn_pre_MAY, temp_R5_bIn_CH, temp_R5_bIn_MAY;
	
	//Initial Hash Values
	logic [31:0] aIn = 32'h67452301;
	logic [31:0] bIn = 32'hEFCDAB89;
	logic [31:0] cIn = 32'h98BADCFE;
	logic [31:0] dIn = 32'h10325476;
	logic [31:0] eIn = 32'hC3D2E1F0;
	
	
	/*
	Possible Optimizations:
	- macht der RESET State die 5*32 bit register [mag] überflüssig?
	- alle SHA1 80 Runden Register entfernen -> logic[31:0] temp_CH, temp_R5, temp_R1, temp_R30, temp_MAY, temp_PARITY
	
	
	*/
	
	
	/* ### start detection ... ################################################
	
						  _______________
			__________|					  |___________
			
						 ^
						 |
						
					  START
	
	*/
	logic [3:0] sync_reg = 4'b0000;
	always_ff@(posedge clk)
		begin : start_detection
			if(reset_n == 1'b0)
				sync_reg <= 4'b0000;
			else
				sync_reg <= {sync_reg[2:0],start};
		end : start_detection
			
	logic sync_start; 
	assign sync_start = (sync_reg == 4'b0011) ? 1'b1 : 1'b0;
	

	
	logic [BITWIDTH_40-1:0] step = 'd0;			// The step-counter for the 40-Cycles SHA1
	logic [BITWIDTH_80-1:0] splitCount = 'd0;	// The splitCount-counter has to iterate 80-times through the padded message "splits" 

	
	
	// Implemented instances of the function modules for the 80-Cycles SHA1-Kernel only.
	
	rotl_SHA1 inst_1(.n(30), .x(bIn), .w(temp_R30)); // ROTL: Anzahl, Input, Output
	
	rotl_SHA1 inst_3(.n(1), .x((splits[step-3])^(splits[step-8])^(splits[step-14])^(splits[step-16])), .w(temp_R1)); // ROTL1, Input Wt, Output TempR1
	
	rotl_SHA1 inst_2(.n(5), .x(aIn), .w(temp_R5)); // ROTL5, Input aIn, Output TempR5
	
	
	ch_SHA1 inst_0(.x(bIn), .y(cIn), .z(dIn), .w(temp_CH)); // f1 (nummer nachprüfen) input, output temp_CH
	
	parity_SHA1 inst_4(.x(bIn), .y(cIn), .z(dIn), .w(temp_PARITY)); // f2 f4  Input , Temp F2/F4 Output
	
	may_SHA1 inst_5(.x(bIn), .y(cIn), .z(dIn), .w(temp_MAY)); // " "       " " 
	

	
	// Implemented instances in addition for the 40-Cycles SHA1-Kernel.
	
	rotl_SHA1 inst_6(.n(30), .x(bIn), .w(temp_R30_bIn)); // ROTL30, Input bIn, Output tempr30bin
	
	rotl_SHA1 inst_7(.n(30), .x(aIn), .w(temp_R30_aIn)); // ROTL30, Input aIn, Output tempr30aIn
	
	rotl_SHA1 inst_8(.n(1), .x((splits[splitCount-3])^(splits[splitCount-8])^(splits[splitCount-14])^(splits[splitCount-16])), .w(temp_R1_splitCount)); // ROTL1, Input Wt, Output TempR1Splitcount

	ch_SHA1 inst_9(.x(aIn), .y(temp_R30_bIn), .z(cIn), .w(temp_CH_sec));
	
	parity_SHA1 inst_10(.x(aIn), .y(temp_R30_bIn), .z(cIn), .w(temp_PARITY_sec));
	
	may_SHA1 inst_11(.x(aIn), .y(temp_R30_bIn), .z(cIn), .w(temp_MAY_sec));
	
	rotl_SHA1 inst_12(.n(5), .x(temp_R5_bIn_pre), .w(temp_R5_bIn));
	
	rotl_SHA1 inst_13 (.n(1), .x((splits[splitCount-2])^(splits[splitCount-7])^(splits[splitCount-13])^(splits[splitCount-15])), .w(temp_R1_splitCount2));
	
	rotl_SHA1 inst_14(.n(5), .x(temp_R5_bIn_pre_CH), .w(temp_R5_bIn_CH));
	
	rotl_SHA1 inst_15(.n(5), .x(temp_R5_bIn_pre_PARITY), .w(temp_R5_bIn_PARITY));
	
	rotl_SHA1 inst_16(.n(5), .x(temp_R5_bIn_pre_MAY), .w(temp_R5_bIn_MAY));
	

	assign temp_R5_bIn_pre_CH = temp_CH + eIn + temp_R5 + temp_R1_splitCount + k[func];

	assign temp_R5_bIn_pre_PARITY = temp_PARITY + eIn + temp_R5 + temp_R1_splitCount + k[func];

	assign temp_R5_bIn_pre_MAY = temp_MAY + eIn + temp_R5 + temp_R1_splitCount + k[func];
	
	assign temp_R5_bIn_pre = temp_CH + eIn + temp_R5 + splits[splitCount] + k[func];	

	
	
	
	
	// ### 'state machine' ... ################################################

	
	always_ff@(posedge clk) 
		begin : state_machine
			if(reset_n == 1'b0)
				begin
					state	<= __RESET;
				end
			else
				case(state)
					__RESET: begin
						
						// Initializes the values for the SHA1-Kernel.
						
						func <= __CH;
						splitCount <= 'd0;
						step <= 'd0;
						
						splits[15:0] <= splits_[15:0];
						
						aIn <= 32'h67452301;
 						bIn <= 32'hEFCDAB89;
						cIn <= 32'h98BADCFE;
						dIn <= 32'h10325476;
						eIn <= 32'hC3D2E1F0;
						
						state <= __IDLE;
						
					end 
					__IDLE:  begin
					
						/* reset those (?)
							aOut_ <= 32'hxxxxxxxx;
							bOut_ <= 32'hxxxxxxxx;
							cOut_ <= 32'hxxxxxxxx;
							dOut_ <= 32'hxxxxxxxx;
							eOut_ <= 32'hxxxxxxxx;
							*/

						if(sync_start)
							state <= __PROC;
					end
					__PROC:  begin // edge detection / state machine / init

					
					
					
/**
 *		##### 40-CYCLES SHA1-KERNEL - IMPLEMENTATION COPYRIGHT BY:
 *		#####
 *		##### VITALIJ TKANOV
 *		##### DENNIS ZIEGELMANN
 *		#####	LUKAS NEUKIRCHEN
 *		#####
 *		##### Complex Digital Architectures - Summer Term 2019 - Hochschule Darmstadt
 */
					
						
						// Each function needs to be executed for 10 cycles.
						if (step <= 8) begin	
							func <= __CH;
															/**								Example, which applies to each if-statement.
															 *		step  |	func
															 *		_____________
															 *		 0		|	__CH
															 *		 1		|	__CH
															 *		 2		|	__CH
															 *		 3		|	__CH
															 *		 4		|	__CH
															 *		 5		|	__CH	
															 *		 6		|	__CH
															 *		 7		|	__CH
															 *		 8		|	__CH
															 *		 9 	|	__CH			<- Enters here the next if-statement, but still keeps the function (func = _CH)
															 *		10		|	__PARITY		<- Until it finally changes @posedge clk to function: func = _PARITY
															 */
															 
						end
						else if (step > 8 && step <= 18) begin
							func <= __PARITY;
						end
						else if (step > 18 && step <= 28) begin
							func <= __MAY;
						end
						else if (step > 28 && step <= 38) begin
							func <= __PARITY2;	
						end
												
 
 
 
 						step <= step+1;	// The step-counter represents the 40-Cycles.	
						
						splitCount <= splitCount+2;		// The splitCount-counter iterates through the padded message.
																	// To process two iterations @ 1 cycle it needs to be increased by two every clock.
																	
 
 
 						// The 40-Cycles SHA1-Kernel starts @ step = 0
						
						
						eIn <= cIn; // (1)
						
						
						// All the following "temp_....." are assigned by the corresponding function-module before being set to the their local outputs @posedge clk.
						
						dIn <= temp_R30_bIn;	// (2)
						cIn <= temp_R30_aIn;	// (3)	
						
						
						// All "temp_R5_bIn_pre....." are equal to "bIn+1" at the formula-description 
						// All "temp_R5_bin....." are equal to "ROTL5(bIn+1)" at the formula-description
 
						if(step <= 7) begin
							
							bIn <= temp_R5_bIn_pre;														// alle Wt vorhanden... einfach zuweisen
							aIn <= temp_CH_sec + dIn + k[func] + temp_R5_bIn + splits[splitCount+1];
						
						end
						else if (step > 7) begin				// wenn step > 7 dann muss Wt kontinuierlich berechnet werden
						
							splits[splitCount] <= temp_R1_splitCount;
							splits[splitCount+1] <= temp_R1_splitCount2;
							
							if (func == __CH) begin
								bIn <= temp_R5_bIn_pre_CH;
								aIn <= temp_CH_sec + dIn + k[func] + temp_R5_bIn_CH + temp_R1_splitCount2;
							end
							if (func == __PARITY || func == __PARITY2) begin
								bIn <= temp_R5_bIn_pre_PARITY;
								aIn <= temp_PARITY_sec + dIn + k[func] + temp_R5_bIn_PARITY + temp_R1_splitCount2;
							end
							if (func == __MAY) begin
								bIn <= temp_R5_bIn_pre_MAY;
								aIn <= temp_MAY_sec + dIn + k[func] + temp_R5_bIn_MAY + temp_R1_splitCount2;
							end			
					
						end
										
						
						
						// As a final step, the magic-numbers will be added at the end of the SHA1-Kernel. 
						// The results will be provided to the corresponding outputs.
						if(step > ITERATIONS_40) begin
							
							aOut_ <= aIn + mag[0];
							bOut_ <= bIn + mag[1];
							cOut_ <= cIn + mag[2];
							dOut_ <= dIn + mag[3];
							eOut_ <= eIn + mag[4];
							
							state	<= __DONE;
						end
							
							
					end
					__DONE:  begin
						state <= __RESET;	
					end
					
					default: begin
						state <= __RESET;
					end
				endcase	
		end : state_machine
				
		assign q_done  = (state == __DONE) ? 1'b1 : 1'b0; 
		assign q_start = sync_start;
		assign q_state = state;
		assign q_step  = step;
		//assign q_testDB = splits_[0];
		//assign q_testDB = splitCount;

endmodule 



	








