-----------------------------------
------- author : Dennis Z********
------- matr_nr: '********
------- date   : 21.06.20
-----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;    

entity cordic_control_w is
port(
		clk   : in std_logic;
		reset : in std_logic;
		enable: in std_logic;
		stop: in std_logic;
		
		X_in  : inout std_logic_vector(15 downto 0); 	--    -32.768 to 32.767 (signed short) 
		Y_in  : inout std_logic_vector(15 downto 0); 	--    -32.768 to 32.767 (signed short)
		Z_in  : inout std_logic_vector(15 downto 0);  	--    -32.768 to 32.767 (signed short) 
		
		iter  : in std_logic_vector(3 downto 0) := "1100";
		Y_out : inout signed(15 downto 0); -- y value output;
		X_out : inout signed(15 downto 0) -- x value output 
		);
		
end cordic_control_w;

architecture bhv of cordic_control_w is


-------------------SIGNAL LIST-------------------------------
type machine is(ready, check_quad, rot_mode,waiting, prep_next); -- main state machine
signal state : machine;


--- Signals for pipelined CORDIC structure ---
signal i       :   unsigned(3 downto 0);
signal X_out_q :   signed(15 downto 0);
signal Y_out_q :   signed(15 downto 0);
signal Z_out_q :   signed(15 downto 0);
signal X_in_q :   signed(15 downto 0);
signal Y_in_q :   signed(15 downto 0);
signal Z_in_q :   signed(15 downto 0);
signal sig    :    signed(1 downto 0);
signal theta_q  : signed(15 downto 0);

--- Signals for timebase generation ----
signal freq_gen : integer range 1 to 500000; 
signal freq_cnt : integer range 0 to freq_gen-1 := 0;
signal mode : std_logic := '0';
signal enable_n: std_logic;

--Signals for fixed point multiplication for K value----
signal realnumber_x : sfixed(19 downto -12); -- fixed point output (12 fraction bits)
signal realnumber_y : sfixed(19 downto -12); -- fixed point output (12 fraction bits)
signal mag_x_q	  : signed(15 downto 0);
signal mag_y_q	  : signed(15 downto 0);

begin

X_out <= mag_x_q;
Y_out <= mag_y_q;

realnumber_x <= to_sfixed(0.60725,3,-12) * to_sfixed(X_out_q,15,0); -- two fixed point multiplications
realnumber_y <= to_sfixed(0.60725,3,-12) * to_sfixed(Y_out_q,15,0); -- floating point takes too much resources

--- INITIALIZE STARTING VECTOR HERE ---

X_in <= "0011111111111111"; -- X vector start
Y_in <= "0000000000000000"; -- Y vector Start
Z_in <= "0000000101101100"; -- step for each CORDIC Sample, currently 2° (25°: "0001000111000111"  2°: "0000000101101100")
freq_gen <= 50; 		    -- sample frequency is 1/50 f clk 
mode <= '0';                -- different modes (not implemented yet), 

enable_n <= '1' when freq_cnt = freq_gen-1 else '0'; -- enable trigger

f_gen: process(clk)
begin
if reset = '0' then
freq_cnt <= 0;
elsif rising_edge(clk) then

	if freq_cnt = freq_gen-1 then
		freq_cnt <= 0;
	else    freq_cnt <= freq_cnt + 1;
	end if;

end if;
end process;


--- STATE MACHINE TO PROCESS CORDIC ALGORITHM ----

state_machine : process(clk) 
begin

if reset = '0' then
state <= ready;

elsif rising_edge(clk) then
	case(state) is
	when ready =>							-- reset state
					i <= "0000";
					X_in_q <= signed(X_in);
					Y_in_q <= signed(Y_in);
					Z_in_q <= signed(Z_in);
					
					if enable_n = '1' then
					state <= check_quad;
					end if;
	  
	when check_quad => 	-- Not needed in rotation mode, therefore skipped
					   if X_in_q > 0 and Y_in_q > 0 then -- 1st quadrant

					elsif X_in_q < 0 and Y_in_q > 0 then -- 2nd quadrant

					elsif X_in_q < 0 and Y_in_q < 0 then -- 3rd quadrant
					
					elsif X_in_q > 0 and Y_in_q < 0 then -- 4th quadrant

					end if;
					state <= rot_mode;

	when rot_mode => 	-- apply equations depending on sigma 
					

					if Z_in_q > 0 then 	   -- => sigma = 1

					X_out_q <= X_in_q - shift_right((Y_in_q), to_integer(i)); -- equations for positive sigma
					Y_out_q <= Y_in_q + shift_right((X_in_q), to_integer(i)); -- right_shift by to_integer(i)
					Z_out_q <= Z_in_q - theta_q;

					elsif Z_in_q < 0 then      -- => sigma = -1
					
					X_out_q <= X_in_q + shift_right((Y_in_q), to_integer(i)); -- equations for negative sigma
					Y_out_q <= Y_in_q - shift_right((X_in_q), to_integer(i));
					Z_out_q <= Z_in_q + theta_q;
					
					end if;
					state <= prep_next;

	when prep_next => 	-- reload the input by flopping once without computation. Might be not nessecary, didn't test yet.
					X_in_q <= X_out_q;
					Y_in_q <= Y_out_q; 
					Z_in_q <= Z_out_q;
					if i = "1101" then -- CORDIC finished once all iterations processed
						state <= waiting;
					else
					    i <= i + "1";
					    state <= rot_mode; -- loop until finished
						--thet
					end if;
	when waiting => ---------------------------------------------------------
					i <= "0000";
					Z_in_q <= signed(Z_in);						  -- assign same rotation value to generate consistent sin/cos wave
					X_in_q <= signed(realnumber_x(15 downto 0));  		          -- CORDIC_out -> CORDIC_in
					Y_in_q <= signed(realnumber_y(15 downto 0));                      -- CORDIC_out -> CORDIC_in

					mag_y_q <= signed(realnumber_y(15 downto 0));                     -- update output value of y vector
					mag_x_q <= signed(realnumber_x(15 downto 0));			  -- update output value of x vector

					if enable_n = '1' then 						  -- adjust sin/cos frequency by this sampling trigger
					state <= rot_mode;							  -- (frequency limited through algorithm delay, currently 30 cycles)
					
					elsif stop = '1' then 						  -- toggle
					state <= ready;
					end if; --
	end case;	
end if;
end process;


mux_theta: process(i) -- Multiplexer for theta values
begin
case (i) is
when "0000" => theta_q <= "0010000000000000"; 
when "0001" => theta_q <= "0001001011100100"; 
when "0010" => theta_q <= "0000100111111011";
when "0011" => theta_q <= "0000010100010001";
when "0100" => theta_q <= "0000001010001011";
when "0101" => theta_q <= "0000000101000110";
when "0110" => theta_q <= "0000000010100011";
when "0111" => theta_q <= "0000000001010001";
when "1000" => theta_q <= "0000000000101000";
when "1001" => theta_q <= "0000000000010100";
when "1010" => theta_q <= "0000000000001010";
when "1011" => theta_q <= "0000000000000101";
when "1100" => theta_q <= "0000000000000010";
when "1101" => theta_q <= "0000000000000001";
when others =>
end case;
end process;

end bhv;
