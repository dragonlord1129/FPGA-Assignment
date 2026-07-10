#!/usr/bin/env bash
# run_tests.sh -- compile once, run the SAME testbench against every program.
set -e
cd "$(dirname "$0")"

echo "Compiling (once)..."
iverilog -g2012 -o sim.out alu8.v memory8.v control_unit.v cpu8.v tb_cpu8.v

echo
echo "Running sw/program.hex  (loop sum 1..5, expect out_port=15)"
vvp sim.out +HEXFILE=sw/program.hex  +EXPECTED=15 +TESTNAME=sum_1_to_5    +MAXCYCLES=2000 | grep -E "^(TEST|HEXFILE|CPU halted|OUT_PORT|RESULT)"

echo
echo "Running sw/program2.hex (CALL/RET/PUSH/POP/SHL, expect out_port=20)"
vvp sim.out +HEXFILE=sw/program2.hex +EXPECTED=20 +TESTNAME=call_ret_stack +MAXCYCLES=2000 | grep -E "^(TEST|HEXFILE|CPU halted|OUT_PORT|RESULT)"
