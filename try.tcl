#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" "$@"
lappend auto_path .
set USAGE_ENV "tclsh"
source include.tcl 
setenv DEBUG 1
setenv CONTINUE_FLAG_FILE ./.CONTINUE_FLAG_FILE
exec touch [getenv CONTINUE_FLAG_FILE]

set name "0/1/2/3/4"
foreach i {0 1 2 3} {
   puts "cut_head $name $i:"
   puts [cut_head $name $i]
}

puts "--"
set a 1
puts [incr a -1]
puts [incr a -1]
puts [incr a -1]
puts [incr a -1]

puts "--"
puts [lappend u 1]
puts [lappend u 2]
puts [lappend u 3]
puts "--"
 puts [vec_add {1 2 } {1 2 3}]
#set a {1 2}
#show_var a
puts "--"

set a {1 2}
set b {1 2 3}
judge_length_of_vec {a b}
puts "--"
puts [vec_inner_product {1 2} {1 2 3}]
puts [vec_inner_product {1 2} {1 2 3} big_endian]
puts "end--"
