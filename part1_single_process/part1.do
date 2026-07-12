# ModelSim macro for the Part 1 single-process design (three_k_plus_one_sim.vhd).
# Adds signals to the wave window, generates a 100 MHz clock, applies a 2-cycle
# reset, then runs until 'done' asserts. View number/term/length in unsigned radix.
# Run vsim with -voptargs="+acc" so the unread 'length' signal is not optimized away.
add wave clk_in
add wave reset
add wave number_out
add wave term_out
add wave length_out
add wave done_out

# Generate clock: period 10ns, 50% duty cycle
force clk_in 0 0, 1 5 -repeat 10

# Assert reset for 2 clock cycles
force reset 1
run 20

# Start
force reset 0
run 320