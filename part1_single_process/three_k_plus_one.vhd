--------------------------------------------------------------------------------
-- Project : 3k+1 (Collatz) sequence generator -- COEN 313
-- File    : three_k_plus_one.vhd
-- Author  : Bryce Orchard
-- Target  : Digilent Nexys A7 (Artix-7), 100 MHz on-board clock
--
-- Finds the smallest positive integer whose 3k+1 sequence has >= 9 terms
-- (answer: 6). This variant implements the algorithm in a SINGLE clocked
-- process using variables, plus a time-multiplexed 7-segment display driver.
--
-- Related files:
--   three_k_plus_one_sim.vhd  -- simulation-only variant (display removed)
--   ../part2_asm_fsm/three_k_plus_one_asm.vhd  -- ASM-chart / FSM+datapath version
--------------------------------------------------------------------------------
library IEEE;
use ieee.numeric_std.all;
use IEEE.std_logic_1164.all;

entity three_k_plus_one is
    port(reset : in std_logic; -- asynchronous
         clk_in : in std_logic; -- the 100MHz FPGA board clock
         an: out std_logic_vector(7 downto 0 ); -- the 8 anodes of each -- 7-seg display
         sseg : out std_logic_vector(7 downto 0 ); -- the 8 cathodes of each 7-seg display
         done_out : out std_logic); 
end three_k_plus_one;

architecture structural of three_k_plus_one is
signal done : std_logic; -- create signal for done since it needs to be read
signal number_out : unsigned(3 downto 0);
signal term_out : unsigned(6 downto 0);

-- ------------- 7-segment ----------------
-- The 7-segment uses a counter to create the necessary delay for multiplexing the 3 hex values to be displayed (number, term_out0, term_out1)
-- The size of the counter is given by:
-- N = log₂(clock frequency / target LED refresh rate) = log₂(100 MHz / 90 Hz) = 19.9 ~ 20
-- 90 Hz = 10.5 ms cycle time for each of the 4 hex values to be displayed, which is fast enough to appear continuous to the human eye
constant N : integer := 20;
signal q_reg, q_next : unsigned(N-1 downto 0);
signal sel : std_logic_vector(1 downto 0);
signal hex : std_logic_vector(3 downto 0);

begin
    -- number, term and length are VARIABLES (not signals) so that an updated value
    -- is visible immediately within the same clock cycle -- e.g. the incremented
    -- number can be loaded straight into term. This mirrors the sequential C++
    -- reference; signals would instead lag by one clock cycle.
    LOGIC : process(clk_in, reset)
        variable number, length : unsigned(3 downto 0) := "0001"; -- 4 bits for the integers under test (max 6)
        variable term : unsigned(6 downto 0) := "0000001"; -- 7 bits for the terms of the sequence (max 16)
    begin
        if reset = '1' then
            number := "0001";
            length := "0001";
            term := "0000001";
            done <= '0';
        elsif rising_edge(clk_in) then
            if done /= '1' then
                if length = "1001" then -- if we have reached 9 terms, we are done
                    done <= '1';
                elsif term = "0000001" then -- if term = 1, we have completed the sequence for the current number and can move to the next number
                    number := number + 1;
                    term := resize(number, 7);
                    length := "0001"; -- reset length to 1 since we have already counted the first term of the new sequence
                else
                    if term(0) = '0' then -- if even
                        term := term / 2;
                    else                  -- if odd
                        term := resize(3*term, 7) + 1;
                    end if;
                    length := length + 1;
                end if;
            end if;
        end if;
        -- update the outputs to be displayed on the 7-segment LEDs
        number_out <= number;
        term_out <= term;
    end process LOGIC;

    done_out <= done;

    -- register for the counter to create the necessary delay for the 7-segment display multiplexing
    COUNTER_REG : process(clk_in, reset)
    begin
        if reset = '1' then
            q_reg <= (others => '0');
        elsif rising_edge(clk_in) then
            q_reg <= q_next;
        end if;
    end process COUNTER_REG;

    -- next-state logic for the counter
    q_next <= q_reg + 1;

    -- 2 MSBs of counter to control 4-to-1 multiplexing
    sel <= std_logic_vector(q_reg(N-1 downto N-2));

    -- asynchronous multiplexing of the 4 hex values to be displayed
    HEX_MUX : process(sel, term_out, number_out)
    begin
        case sel is
            when "00" =>
                an  <= "11111110";
                hex <= std_logic_vector(number_out);
            when "01" =>
                an  <= "11101111";
                -- display the 4 least significant bits of term as the first hex value
                hex <= std_logic_vector(term_out(3 downto 0)); 
            when others => -- "10" and "11" both display the second hex value since we only have 3 hex values
                an  <= "11011111";
                -- display the 3 most significant bits of term as the second hex value (with a leading 0)
                hex <= std_logic_vector('0' & term_out(6 downto 4));
        end case;
    end process HEX_MUX;

    -- hex-to-7-segment LED decoding
    with hex select
        sseg <= -- sseg format is [a, b, c, d, e, f, g, dp]
            "00000011" when "0000",   -- 0
            "10011111" when "0001",   -- 1
            "00100101" when "0010",   -- 2
            "00001101" when "0011",   -- 3
            "10011001" when "0100",   -- 4
            "01001001" when "0101",   -- 5
            "01000001" when "0110",   -- 6
            "00011111" when "0111",   -- 7
            "00000001" when "1000",   -- 8
            "00001001" when "1001",   -- 9
            "00010001" when "1010",   -- a
            "11000001" when "1011",   -- b
            "01100011" when "1100",   -- c
            "10000101" when "1101",   -- d
            "01100001" when "1110",   -- e
            "01110001" when others;   -- f

end structural;