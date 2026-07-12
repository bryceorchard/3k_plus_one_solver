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