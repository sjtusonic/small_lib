#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" "$@"

source include.tcl

set name "0/1/2/3/4"
foreach i {0 1 2 3} {
   puts "cut_head $name $i:"
   puts [cut_head $name $i]
}

