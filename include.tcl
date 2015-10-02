set TCL_8p4_DIR /usr/bin/tclsh8.5
set TCLLIB_DIR /usr/share/tcltk/tcllib1.12
set TK_CON_DIR /usr/share/tcltk/tkcon2.5 ;#bin: /usr/bin/tkcon
set ITCL_DIR /usr/share/tcltk/itcl3.4

set auto_path [concat $auto_path $TCL_8p4_DIR $TCLLIB_DIR $ITCL_DIR $TK_CON_DIR]

package require Itcl
#package require debug
#package require debug::heartbeat

##########
#   TOOL:
##########
### 0    BASIC:
proc source_echo {file_name} {

}
proc incr {varName {amount 1}} {
   upvar 1 $varName var
   if {[info exists var]} {
      set var [expr $var+$amount]
   } else {
      set var $amount
   }
   return $var
}
proc show_var {varName} {
   upvar $varName var
   puts "$varName=$var"
}
#
### 1   CONNECTION
proc get_fi_pin_level {dPinName {level -1}} {
   global USAGE_ENV; if {$USAGE_ENV ne "DesignCompiler"} {puts "Error: proc is only used when USAGE_ENV eq DesignCompiler";return}
    if {$level == -1 } {
        set allFiClct [all_fanin -to [get_pins $dPinName] -flat]
    } else {
        set allFiClct [all_fanin -to [get_pins $dPinName] -flat -level $level]
    }
    set pin [filter_colection $allFiClct {direction==2}]
    return $pin
}

proc get_fi_seq_pin {dPinName} {
   global USAGE_ENV; if {$USAGE_ENV ne "DesignCompiler"} {puts "Error: proc is only used when USAGE_ENV eq DesignCompiler";return}
    #set returnList [list]
    set pinClct [get_fi_pin_level $dPinName]
    foreach_in_c p $pinClct {
        set cell [get_cells -of $p]
        if {[get_attr $cell is_sequential]} {
            lappend returnList [get_attr $p full_name]
        }

    }
    return [get_pins $returnList]
}

#   1.1 clock tree connection
proc get_fo_from_pin {root_point_name {level -1}} {
   global USAGE_ENV; if {$USAGE_ENV ne "DesignCompiler"} {puts "Error: proc is only used when USAGE_ENV eq DesignCompiler";return}
   if{$level==-1} {
      set fo_clct [all_fanout -from $root_point_name -flat]
   } elseif {$level==0} {
      set fo_clct [all_fanout -from $root_point_name -flat -levels 0]
   } else {
      set fo_clct \
      [  \
         remove_from_coll \
         [all_fanout -from $root_point_name -flat -levels [expr $level     ]] \
         [all_fanout -from $root_point_name -flat -levels [expr $level  -1 ]] \
      ]
   }
}

### 2 TEST/NAME:
proc get_tail {name {tail_count 0}} {
# >set name 0/1/2/3/4/5
# >get_tail $name
# 5
# >get_tail $name 1
# 4/5
   set start_str "end-$tail_count"
   return [join [lrange [split $name "/"] $start_str end] "/"]
}
proc cut_tail {name {tail_count 0}} {
   return [get_head $name [expr [llength $name] -$tail_count +2]]
}
proc get_head {name {head_count 0}} {
# >set name 0/1/2/3/4/5
# >get_head $name
# 0
# >get_head $name 1
# 0/1
   return [join [lrange [split $name "/"] 0 $head_count] "/"]
}
proc cut_head {name {head_count 0}} {
   return [get_tail $name [expr [llength $name ] - $head_count  +2]]
}

proc cell2ck {cell_name} {
   set ck_pin $cell_name/CK   ;if {[get_pins $ck_pin] ne ""} {return $ck_pin}
   set ck_pin $cell_name/CKB  ;if {[get_pins $ck_pin] ne ""} {return $ck_pin}
   set ck_pin $cell_name/CP   ;if {[get_pins $ck_pin] ne ""} {return $ck_pin}
   set ck_pin $cell_name/CPB  ;if {[get_pins $ck_pin] ne ""} {return $ck_pin}
   set ck_pin $cell_name/E    ;if {[get_pins $ck_pin] ne ""} {return $ck_pin}
   set ck_pin $cell_name/EB   ;if {[get_pins $ck_pin] ne ""} {return $ck_pin}

   puts "Error: proc cell2ck $cell_name"
}

proc cell2d {cell_name} {
   set d_pin $cell_name/TD   ;if {[get_pins $d_pin] ne ""} {return $d_pin}
   set d_pin $cell_name/D    ;if {[get_pins $d_pin] ne ""} {return $d_pin}
   puts "Error: proc cell2d  $cell_name"
}

###3 SET USER ATTRIBUTES
if {$USAGE_ENV ne "DesignCompiler"} { 
} else {
proc UDP_set_attr2scan_cell args {
   set results(-IN)     ""
   set results(-OUT)     ""
   set results(-cell)     ""
   set results(-BITS)     ""
   set results(-test_scan_def_chain_name)     ""
   set results(-test_scan_def_chain_order)     ""
   parse_proc_arguments -args $args results

   set IN     			            $results(-IN)     			
   set OUT     			         $results(-OUT)     			
   set cell     			         $results(-cell)     			
   set BITS     			         $results(-BITS)     			
   set test_scan_def_chain_name  $results(-test_scan_def_chain_name)     			
   set test_scan_def_chain_order $results(-test_scan_def_chain_order)     			

   set_attribute $cell IN $IN
   set_attribute $cell OUT $OUT

   if {$BITS ne ""} {
      set_attribute $cell BITS $BITS
   }
   set_attribute $cell test_scan_def_chain_name  $test_scan_def_chain_name
   set_attribute $cell test_scan_def_chain_order $test_scan_def_chain_order
   return 1
}

define_proc_attributes UDP_set_attr2scan_cell \
-info "set scandef info to cell" \
-define_args {
   {-IN     "string help" AString string required}
   {-OUT    "string help" AString string required}
   {-cell   "string help" AString string required}
   {-BITS   "help" "val"          int    optional}
   {-test_scan_def_chain_name  "int" "help" int required}
   {-test_scan_def_chain_order "int" "help" int required}
}
}

###4 FORMAT PRINTING
proc print_list_line_by_line {ll {limit 0} {sort 0}} {
   if {$sort} {
      set ll [lsort -dic $ll]
   } 
   puts "\tbegin of list"
   puts "\ttotally [llength $ll]"
   if {$limit<=0} {
      foreach i $ll {
         puts $i
      }
   } else {
      set cnt 0
      foreach i $ll {
         puts $i
         incr cnt
         if {$cnt >= $limit} {puts "reaching limit=$limit, break"; break}
      }
   }
}

###5 STATISTICS:
proc stat_max {numlist} {
   set max [lindex $numlist 0]
   foreach i $numlist {
      if {$i>$max} {
         set max $i
      }
   }
   return [expr $max]
}
proc stat_min {numlist} {
   set min [lindex $numlist 0]
   foreach i $numlist {
      if {$i<$min} {
         set min $i
      }
   }
   return [expr $min]
}
proc stat_sum {numlist} {
   set sum 0
   foreach i $numlist {
      set sum [expr $sum+$i]
   }
   return $sum
}
proc stat_mean {numlist} {
   set total [expr [llength $numlist]]
   set sum [stat_sum $numlist]
   return [expr 1.0*$sum/$total]
}
proc stat_dev {numlist} {
# dx=E(x^2)-EX^2
   #set sqr_list [list]
   foreach i $numlist {
      lappend sqr_list [expr 1.0*$i*$i]
   }
   set ex [stat_mean $numlist]
   return [expr [stat_mean $sqr_list] - $ex*$ex]
}
proc stat_stddev {numlist} {
   set n [stat_dev $numlist]
   if {$n<1e-7} {
      set n 0
   }
   return [expr sqrt($n)]
}

###6 VECTOR
proc vec_scalar_add {v scalar} {
   #set r [list]
   foreach i $v {
      lappend r [expr $i+$scalar]
   }
   return $r
}
proc vec_scalar_mul {v scalar} {
   #set r [list]
   foreach i $v {
      lappend r [expr $i*$scalar]
   }
   return $r
}

proc vec_neg {a} {
   #set r [list]
   foreach i $a {
      lappend r [expr -$i]
   }
   return $r
}
proc vec_abs {a} {
   foreach i $a {
      lappend r [expr abs($i)]
   }
   return $r
}
proc judge_length_of_vec {vec_name_list} {
   set old_len "NA"
   set return_flag true
   foreach name $vec_name_list {
      upvar $name var
      set curr_len [llength $var]
      #puts "vec:\t$name\tlength:\t$curr_len"
      if {($curr_len != $old_len) && ($old_len ne "NA")} {
         puts "Warning vec:$name have different length($curr_len!=$old_len)!"
         set return_flag false
      }
      set old_len $curr_len
   }
   return $return_flag
}
proc vec_add {a b {force_check_len_legal 1}} {
   if {$force_check_len_legal && ![judge_length_of_vec {a b}]} {
      puts "Warning: in proc vec_add, length of a,b mismatch:"
      show_var a
      show_var b
   }
   foreach i $a j $b {
      if {$i eq ""} {set i 0}
      if {$j eq ""} {set j 0}
      lappend r [expr $i+$j]
   }
   return $r
}
proc vec_sub {a b} {
   return [vec_ad $a [vec_neg $b]]
}
proc vec_inner_product {a b {mode "small_endian"}} {
# mode==small_endian:
# a=1 2
# b=1 2 3
# 5
# mode==big_endian:
# a=  1 2
# b=1 2 3
# 8
   if {![judge_length_of_vec {a b}]} {
      puts "Warning: in proc vec_inner_product, length of a,b mismatch:"
      show_var a
      show_var b
   }
   set sum 0
   if {$mode eq "small_endian"} {
      foreach i $a j $b {
         if {$i eq ""} {set i 0}
         if {$j eq ""} {set j 0}
         set sum [expr $i*$j+$sum]
      }
   } elseif {$mode eq "big_endian"} {
      set a [lreverse $a]
      set b [lreverse $b]
      foreach i $a j $b {
         if {$i eq ""} {set i 0}
         if {$j eq ""} {set j 0}
         set sum [expr $i*$j+$sum]
      }
   } else {
      puts "Error in proc vec_inner_product"
   }
   return $sum
}

# calc_weighted_vec is a special application of vec_inner_product:
proc calc_weighted_vec {vec weight_list {mode "small_endian"}} {
   vec_inner_product $vec $weight_list $mode
}

proc vec_outer_product_algebra {a b} { ;# only used in 2D vector
   if {![judge_length_of_vec {a b}]} {
      puts "Warning: in proc vec_inner_product, length of a,b mismatch:"
      show_var a
      show_var b
   }
   set a0 [lindex $a 0]
   set a1 [lindex $a 1]
   set b0 [lindex $b 0]
   set b1 [lindex $b 1]
   return [expr $a0*$b1-$b0*$a1]
}

proc vec_length {v1} {
   set sum 0
   foreach i $v1 {
      set sum [expr $sum+$i**2]
   }
   return [expr $sum**0.5]
}
proc vec_length_manhattan {v1} {
   set sum 0
   foreach i $v1 {
      set sum [expr $sum+abs($i)]
   }
   return [expr $sum]
}

###6.1 VECTOR/BBOX TRANSFORM
proc v2b {vec4} { ;# convert vec={1 4 3 2} to regular bbox {{1 2} {3 4}} (regular bbox is {{llx lly} {urx ury}})
   set v0 [lindex $vec4 0]
   set v1 [lindex $vec4 1]
   set v2 [lindex $vec4 2]
   set v3 [lindex $vec4 3]

   set x_min [stat_min [list $v0 $v2]]
   set x_max [stat_max [list $v0 $v2]]
   set y_min [stat_min [list $v1 $v3]]
   set y_max [stat_max [list $v1 $v3]]

   set a [list $x_min $y_min]
   set b [list $x_max $y_max]
   return [list $a $b]
}
proc b2v {bbox} {;# this bbox may be not regular
   set tmp0_0 [lindex $bbox 0 0];#llx
   set tmp0_1 [lindex $bbox 0 1];#lly
   set tmp1_0 [lindex $bbox 1 0];#urx
   set tmp1_1 [lindex $bbox 1 1];#ury

   set llx [stat_min [list $tmp0_0 $tmp1_0]]
   set urx [stat_max [list $tmp0_0 $tmp1_0]]
   set lly [stat_min [list $tmp0_1 $tmp1_1]]
   set ury [stat_max [list $tmp0_1 $tmp1_1]]
   return [list $llx $lly $urx $ury]
}

###6.2 BBOX
