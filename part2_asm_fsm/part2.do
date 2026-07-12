# ModelSim macro for the Part 2 ASM/FSM design (three_k_plus_one_asm.vhd).
# Adds the datapath signals and FSM 'state' to the wave window, generates a
# 100 MHz clock, applies a 2-cycle reset, then runs until 'done' asserts.
# View number/term/length in unsigned radix to trace the algorithm per state.
add wave clk_in
add wave reset
add wave number
add wave term
add wave length
add wave done

# Generate clock: period 10ns, 50% duty cycle
force clk_in 0 0, 1 5 -repeat 10

# Assert reset for 2 clock cycles
force reset 1
run 20

# Start
force reset 0
run 1000