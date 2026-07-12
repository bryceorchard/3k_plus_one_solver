--------------------------------------------------------------------------------
-- Project : 3k+1 (Collatz) sequence generator -- COEN 313
-- File    : three_k_plus_one_sim.vhd
-- Author  : Bryce Orchard
-- Target  : ModelSim simulation only (NOT for synthesis)
--
-- Simulation-only variant of three_k_plus_one.vhd. The 7-segment display driver
-- and the an/sseg ports are removed to keep the waveform focused on the
-- algorithm, and an extra 'length_out' signal is exposed so the term count is
-- visible in the wave window.
--
-- Because 'length' is never read by any logic, ModelSim optimizes it away unless
-- vsim is run with -voptargs="+acc". Drive with part1.do.
--------------------------------------------------------------------------------
library IEEE;
use ieee.numeric_std.all;
use IEEE.std_logic_1164.all;

entity three_k_plus_one is
    port(reset : in std_logic; -- asynchronous
         clk_in : in std_logic; -- the 100MHz FPGA board clock
         done_out : out std_logic);
end three_k_plus_one;

architecture structural of three_k_plus_one is
signal done : std_logic;
signal number_out, length_out : unsigned(3 downto 0);
signal term_out : unsigned(6 downto 0);

begin
    process(clk_in, reset)
        variable number, length : unsigned(3 downto 0) := "0001";
        variable term : unsigned(6 downto 0) := "0000001";
    begin
        if reset = '1' then
            number := "0001";
            length := "0001";
            term := "0000001";
            done <= '0';
        elsif rising_edge(clk_in) then
            if done /= '1' then
                if length = "1001" then
                    done <= '1';
                elsif term = "0000001" then
                    number := number + 1;
                    term := resize(number, 7);
                    length := "0001";
                else
                    if term(0) = '0' then
                        term := term / 2;
                    else
                        term := resize(3*term, 7) + 1;
                    end if;
                    length := length + 1;
                end if;
            end if;
        end if;
        number_out <= number;
        term_out <= term;
        length_out <= length;
    end process;

    done_out <= done;

end structural;