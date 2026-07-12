library IEEE;
use ieee.numeric_std.all;
use IEEE.std_logic_1164.all;

entity three_k_plus_one is 
    port(reset : in std_logic; -- asynchronous
         clk_in : in std_logic; -- the 100MHz FPGA board clock
         an: out std_logic_vector(7 downto 0 ); -- the 8 anodes of each -- 7-seg display
         sseg : out std_logic_vector(7 downto 0 );
         done_out : out std_logic); 
end three_k_plus_one;

architecture structural of three_k_plus_one is
-- data path registers
signal done : std_logic;
signal number, length : unsigned(3 downto 0);
signal term : unsigned(6 downto 0);

-- status signals
signal reset_number, inc_number : std_logic; -- number input signals

signal reset_term, shift_term, mult_inc_term, load_term : std_logic; -- term input signals

signal reset_length, inc_length : std_logic; -- length input signals

signal reset_done, load_done : std_logic; -- done input signals

type STATE_TYPE is (reset_state, test_state, increment, reload_term, generate_next_term, shift, mult_add, done_state);
signal state : STATE_TYPE;

-- ------------- 7-segment ----------------
-- The 7-segment uses a counter to create the necessary delay for multiplexing the 3 hex values to be displayed (number, term_out0, term_out1)
-- The size of the counter is given by:
-- N = log₂(clock frequency / target LED refresh rate) = log₂(100 MHz / 90 Hz) = 19.9 ~ 20
-- 90 Hz = 10.5 ms cycle time for each of the 4 hex values to be displayed, which is fast enough to appear continuous to the human eye
constant N : integer := 20;
signal q_reg, q_next : unsigned(N-1 downto 0);
signal sel : std_logic_vector(1 downto 0);
signal hex : std_logic_vector(3 downto 0); -- value to be displayed at any given moment

begin
    LOGIC : process(clk_in, reset) -- control logic
    begin
        if reset = '1' then
            state <= reset_state;
        elsif rising_edge(clk_in) then
            case state is
                when reset_state =>
                    state <= test_state; -- reset must be '0'
                when test_state =>
                    if length = "1001" then
                        state <= done_state;
                    elsif term = "0000001" then
                        state <= increment;
                    else
                        state <= generate_next_term;
                    end if;
                when increment =>
                    state <= reload_term;
                when reload_term =>
                    state <= test_state;
                when generate_next_term =>
                    if term(0) = '0' then
                        state <= shift;
                    else
                        state <= mult_add;
                    end if;
                when shift =>
                    state <= test_state;
                when mult_add =>
                    state <= test_state;
                when done_state =>
                    state <= done_state;
            end case;
        end if;
    end process LOGIC;

    OUTPUTS : process(state) -- non registered outputs
    begin
        reset_number  <= '0'; inc_number <= '0';
        reset_term    <= '0'; shift_term <= '0';
        mult_inc_term <= '0'; load_term  <= '0';
        reset_length  <= '0'; inc_length <= '0';
        reset_done    <= '0'; load_done  <= '0';
        case state is
            when reset_state =>
                reset_number  <= '1'; reset_term <= '1';
                reset_length  <= '1'; reset_done <= '1';
            when test_state =>
                null;
            when increment =>
                inc_number    <= '1';
            when reload_term =>
                load_term     <= '1';
                reset_length  <= '1';
            when generate_next_term =>
                inc_length    <= '1';
            when shift =>
                shift_term    <= '1';
            when mult_add =>
                mult_inc_term <= '1';
            when done_state =>
                load_done     <= '1';
        end case;
    end process OUTPUTS;

    NUMBER_PROCESS : process(clk_in) -- number
    begin
        if rising_edge(clk_in) then
            if reset_number = '1' then
                number <= "0001";
            elsif inc_number = '1' then
                number <= number + 1;
            end if;
        end if;
    end process NUMBER_PROCESS;

    TERM_PROCESS : process(clk_in) -- term
    begin
        if rising_edge(clk_in) then
            if reset_term = '1' then
                term <= "0000001";
            elsif shift_term = '1' then
                term <= shift_right(term, 1);
            elsif mult_inc_term = '1' then
                term <= resize(3*term, 7) + 1;
            elsif load_term = '1' then
                term <= resize(number, 7);
            end if;
        end if;
    end process TERM_PROCESS;

    LENGTH_PROCESS : process(clk_in) -- length
    begin
        if rising_edge(clk_in) then
            if reset_length = '1' then
                length <= "0001";
            elsif inc_length = '1' then
                length <= length + 1;
            end if;
        end if;
    end process LENGTH_PROCESS;

    DONE_PROCESS : process(clk_in) -- done
    begin
        if rising_edge(clk_in) then
            if reset_done = '1' then
                done <= '0';
            elsif load_done = '1' then
                done <= '1';
            end if;
            -- can be expressed as done <= (load_done or done) and not reset_done; but the above is more concise and easier to read
        end if;
    end process DONE_PROCESS;
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

    q_next <= q_reg + 1;
    sel <= std_logic_vector(q_reg(N-1 downto N-2));

    -- asynchronous multiplexing of the 4 hex values to be displayed
    HEX_MUX : process(sel, number, term)
    begin
        case sel is
            when "00" =>
                an  <= "11111110";
                hex <= std_logic_vector(number);
            when "01" =>
                an  <= "11101111";
                hex <= std_logic_vector(term(3 downto 0));
            when others => -- "10" and "11" both display the second hex value since we only have 3 hex values
                an  <= "11011111";
                hex <= '0' & std_logic_vector(term(6 downto 4));
        end case;
    end process HEX_MUX;

    -- hex-to-7-segment LED decoding
    with hex select
        sseg <=
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