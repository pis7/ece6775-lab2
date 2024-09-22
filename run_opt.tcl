#=============================================================================
# run.tcl 
#=============================================================================
# @brief: A Tcl script for synthesizing the digit recongnition design.
#
# @desc: This script launches a batch of simulation & synthesis runs
# to quickly explore different K parameters.
#
# 1. The user specifies the list of K values.
# 2. Useful simulation & synthesis stats are consolidated into ./result/result.csv

#------------------------------------------------------
# Remove old result file
#------------------------------------------------------
set filename "knn_result_opt.csv"
file delete -force "./result/${filename}"

#------------------------------------------------------
# You can specify a set of parameter K to explore.
#------------------------------------------------------
set value_k {3}
#------------------------------------------------------
# run batch experiments
#------------------------------------------------------
foreach { K } $value_k {

# Define the bitwidth macros from CFLAGs
set CFLAGS "-DK_CONST=${K}"

# Project name
set hls_prj ${K}-nn.prj

# Open/reset the project
open_project ${hls_prj} -reset
# Top function of the design is "digitrec"
set_top digitrec

# Add design and testbench files
add_files digitrec.cpp -cflags $CFLAGS
add_files -tb digitrec_test.cpp -cflags $CFLAGS
add_files -tb data

open_solution "solution1"
# Use Zynq device
set_part {xc7z020clg484-1}

# Target clock period is 10ns
create_clock -period 10

# Do not inline update_knn and knn_vote functions 
set_directive_inline -off update_knn
set_directive_inline -off knn_vote

set_directive_unroll digitrec/knn_init_outer
set_directive_unroll digitrec/knn_init_inner
set_directive_unroll digitrec/training_inner
set_directive_unroll update_knn/popcount
set_directive_unroll update_knn/search_max
set_directive_unroll sort_knn/flatten_outer
set_directive_unroll sort_knn/flatten_inner
set_directive_unroll sort_knn/bubble_outer
set_directive_unroll sort_knn/bubble_inner
set_directive_unroll knn_vote/set_zero
set_directive_unroll knn_vote/get_freqs
set_directive_unroll knn_vote/search_max

set_directive_array_partition -type complete -dim 0 digitrec knn_set
set_directive_array_partition -type complete -dim 0 digitrec knn_set
set_directive_array_partition -type complete -dim 0 knn_vote sorted_distances
set_directive_array_partition -type complete -dim 0 knn_vote sorted_labels
set_directive_array_partition -type complete -dim 0 knn_vote freqs

# Simulate the C++ design
csim_design
# Synthesize the design
csynth_design
# Co-simulate the design
#cosim_design

#---------------------------------------------
# Collect & dump out results from HLS reports
#---------------------------------------------
set argv [list $filename $hls_prj]
set argc 2
source "./script/collect_result.tcl"
}
exit
