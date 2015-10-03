set TCL_8p4_DIR /usr/bin/tclsh8.5
set TCLLIB_DIR /usr/share/tcltk/tcllib1.12
set TK_CON_DIR /usr/share/tcltk/tkcon2.5 ;#bin: /usr/bin/tkcon
set ITCL_DIR /usr/share/tcltk/itcl3.4

lappend auto_path $TCL_8p4_DIR
lappend auto_path $TCLLIB_DIR
lappend auto_path $ITCL_DIR
lappend auto_path $TK_CON_DIR


package require Itcl
#package require debug
#package require debug::heartbeat

##########
#   TOOL:
##########
### 0    BASIC:
puts "USAGE_ENV=$USAGE_ENV"
if {$USAGE_ENV eq "tclsh"} {
   proc setenv {varName value } {
      global env
      set env($varName) $value
   }
   proc getenv {varName} {
      global env
      return $env($varName)
   }
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
   upvar 1 $varName var
   if {[info exists var]} {
      puts "$varName=$var"
   }
}

if {$USAGE_ENV eq "tclsh"} {
   if {[info procs source] eq ""} {
      puts "Info: setting up verbose feature for source proc"
      rename source source.orig
      proc source {file_name args } {
         show_var file_name
         show_var args
         if {[lsearch $args "-e"]==-1} {
            #source.orig $file_name
            uplevel "source.orig $file_name"
         } else {
            puts "source $file_name in verbose mode"
            puts [uplevel "verbose_eval $file_name"]
         }
      }
   }
   proc verbose_eval {script} {
      ;#in http://wiki.tcl.tk/473
      set cmd ""
      set fp [open $script]
      while {[gets $fp line]>=0} {
         if {$line eq ""} {continue}
         #puts "LINE: $line"
         append cmd $line\n
         if {[info complete $cmd]} {
            puts -nonewline "CMD>"
            puts -nonewline $cmd
            puts -nonewline [uplevel 1 $cmd]
            puts ""
            set cmd ""
         }
      }
      close $fp
   }
}
if {0} {
   set script {
      puts hello
      expr 2.2*3
      foreach i {1 2 3} {
         puts $i
      }
   }
   verbose_eval $script
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
   set a [lindex [vec2points $vec4] 0]
   set c [lindex [vec2points $vec4] 2]
   return [list $a $c]
}
proc b2v {bbox} {;# this bbox may be not regular
   #set tmp0_0 [lindex $bbox 0 0];#llx
   #set tmp0_1 [lindex $bbox 0 1];#lly
   #set tmp1_0 [lindex $bbox 1 0];#urx
   #set tmp1_1 [lindex $bbox 1 1];#ury

   #set llx [stat_min [list $tmp0_0 $tmp1_0]]
   #set urx [stat_max [list $tmp0_0 $tmp1_0]]
   #set lly [stat_min [list $tmp0_1 $tmp1_1]]
   #set ury [stat_max [list $tmp0_1 $tmp1_1]]
   set tmp [bbox2points $bbox]
   return [concat [lindex $tmp 0] [lindex $tmp 2]]
}

###6.2 BBOX
proc calc_area {bbox} {
   set points [bbox2points $bbox]
   set a [lindex $points 0]
   set c [lindex $points 2]

   set llx [lindex $a 0 ];#llx
   set lly [lindex $a 1 ];#lly
   set urx [lindex $c 0 ];#urx
   set ury [lindex $c 1 ];#ury
   return [expr ($urx-$llx)*($ury-$lly)]
}

proc point_is_in_bbox {p bbox {generalized 0}} {
   set points [bbox2points $bbox]
   set a [lindex $points 0]
   set c [lindex $points 2]
   set llx [lindex $a 0 ];#llx
   set lly [lindex $a 1 ];#lly
   set urx [lindex $c 0 ];#urx
   set ury [lindex $c 1 ];#ury

   set px [lindex $p 0]
   set py [lindex $p 1]

   if {$generalized} {
      if {  $px>=$llx 
         && $px<=$urx
         && $py>=$lly
         && $py<=$ury
         } {
         return true;
      }
   } else {
      if {  $px> $llx 
         && $px< $urx
         && $py> $lly
         && $py< $ury
         } {
         return true;
      }
   }
   return false
}

proc bbox2points {bbox} {
   set tmp0_0 [lindex $bbox 0 0];#llx
   set tmp0_1 [lindex $bbox 0 1];#lly
   set tmp1_0 [lindex $bbox 1 0];#urx
   set tmp1_1 [lindex $bbox 1 1];#ury

   set llx [stat_min [list $tmp0_0 $tmp1_0]]
   set urx [stat_max [list $tmp0_0 $tmp1_0]]
   set lly [stat_min [list $tmp0_1 $tmp1_1]]
   set ury [stat_max [list $tmp0_1 $tmp1_1]]
   
   set a [list $llx $lly]
   set b [list $urx $lly]
   set c [list $urx $ury]
   set d [list $llx $ury]
#  d---c
#  |   |
#  a---b
   return [list $a $b $c $d]
}
proc vec2points {vec4} {
   set v0 [lindex $vec4 0]
   set v1 [lindex $vec4 1]
   set v2 [lindex $vec4 2]
   set v3 [lindex $vec4 3]

   set x_min [stat_min [list $v0 $v2]]
   set x_max [stat_max [list $v0 $v2]]
   set y_min [stat_min [list $v1 $v3]]
   set y_max [stat_max [list $v1 $v3]]

   set a [list $x_min $y_min]
   set b [list $x_max $y_min]
   set c [list $x_max $y_max]
   set d [list $x_min $y_max]
#  d---c
#  |   |
#  a---b
   return [list $a $b $c $d]
}

proc bbox_overlap {bbox1 bbox2 {generalized 0}} {
   foreach i [bbox2points $bbox1] {
      if {[point_is_in_bbox $i $bbox2 $generalized]} {
         return true
      }
   }
   foreach i [bbox2points $bbox2] {
      if {[point_is_in_bbox $i $bbox1 $generalized]} {
         return true
      }
   }
   return false
}

###7 LIST
###7.0 JUDGE
proc is_list {target} {
   if {[lindex $target 0] ne ""} {return true}
   return false
}
###7.1 SET THEORY
proc list_intersection {lA lB} {
   set sA [lsort -u $lA]
   set ansList [list]
   foreach i $sA {
      if {[lsearch $lB $i]!=-1} {
         lappend ansList $i
      }
   }
   return $ansList
}

proc list_diff {lA lB} { ;# A-B
   set sA [lsort -u $lA]
   set ansList [list]
   foreach i $sA {
      if {[lsearch $lB $i]==-1} {
         lappend ansList $i
      }
   }
   return $ansList
}

proc list_union {lA lB} {
   return [concat [list_diff $lA $lB] $lB]
}

proc list_product {lA lB} {
   set r [list]
   foreach a $lA {
      foreach b $lB {
         lappend r [list $a $b]
      }
   }
   return $r
}

###7.2 MORE LIST OPTIONS
proc lremove {listVariable value} {
   upvar 1 $listVariable var
   set idx [lsearch -exact $var $value]
   set var [lreplace $var $idx $idx]
}
proc lremove_by_index {listVariable idx} {
   upvar 1 $listVariable var
   set var [lreplace $var $idx $idx]
}
proc push {listVariable item} {
   upvar 1 $listVariable var
   set var [concat $var $item]
}
proc unshift {listVariable item} {
   upvar 1 $listVariable var
   set var [concat $item $var]
}
proc pop {listVariable} {
   upvar 1 $listVariable var
   set tail [lindex $var end]
   set var  [lrange $var 0 end-1]
   return $tail
}
proc shift {listVariable} {
   upvar 1 $listVariable var
   set head [lindex $var 0]
   set var [lrange $var 1 end]
   return $head
}

###7.3 HISTOGRAM
# draw_histogram
proc get_sorted_ll_by_bound {ll bound} {
   set ind 0
   foreach i $ll {
      if {$i>$bound} {break}
      incr ind
   }
   return [lrange $ll 0 [expr $ind-1]]
}
proc draw_histogram {ll {from 0} {to "end"} {COLUMN_CNT 10}} {
   set ll_sort [lsort -dic $ll]
   set len [llength $ll]
   set max [stat_max $ll]
   set min [stat_min $ll]

   set STEP [expr 1.0*($max-$min)/$COLUMN_CNT]
   puts "max=$max,min=$min"
   puts "STEP=$STEP"
   set bound $min
   set old_bound $bound
   set cntr 0
   set old_match_len 0
   while {$cntr<[expr 2.5*$COLUMN_CNT]} {
      incr cntr
      set match_len [llength [get_sorted_ll_by_bound $ll_sort $bound]]
      puts "\($old_bound,$bound\]: [expr $match_len - $old_match_len]"
      set old_match_len $match_len
      set old_bound $bound
      set bound [expr $bound +$STEP]
      if {$bound > [expr $max+$STEP]} {
         break
      }
   }
}

# set ll {-3 1 2 3 4 5 6 7 8 9 10 11 12 1 1 1 1 7 7 7 1.1 1.1 1.1}
# draw_histogram $ll
#
###8 COLLECTION
###8.0 JUDGE
proc is_collection {target} {
   if {[index_collection $target 0] ne ""} {
      return true
   } 
   return false
}
###8.1 SET THEORY FOR COLLECTION
#proc clct_union {} {}
# ...

###8a GUI
proc mark_text {} {

}

### FLY LINE:
#

###9 ABSTRACT ALGRBRA
proc transformation {vt v2} {
# transformation {0 1 2} {a b c} => {a b c}
# transformation {1 2 0} {a b c} => {c a b}
   if {[llength $vt]!=[llength $v2]} {
      puts "Error: proc transformation: llength vt, v2 not equal"
   }
   set new_ind 0
   set new_l [list]
   while {$new_ind<[llength $v2]} {
      set old_ind [lsearch $vt $new_ind]
      lappend new_l [lindex $v2 $old_ind]
      incr new_ind
   }
   return $new_l
}
proc rand_transformation {{length 1}} { 
;# in tcllib there is a shuffle proc
   set r [list]
   set cnt 0
   while {[llength $r]<$length} {
      set seed [expr int(rand()*$length)] ;# 0~$length-1
      if {[lsearch $r $seed]==-1} {
         lappend r $seed
      }
      incr cnt
      if {$cnt>[expr 1e3*$length]} {puts "Error: iterating $cnt times";break}
   }
   return $r
}

###10 FORMAT PRINTING
proc putsd {info} {
   if {[getenv DEBUG]} {
      puts $info
      if {![file exists [getenv CONTINUE_FLAG_FILE]]} {
         set sh_script_stop_severity E
         puts "[getenv CONTINUE_FLAG_FILE] does not exist! stop here!"
         script stop here
      }
   }
}

###11 DEBUG TOOL 
proc tracer {varName args} {
   upvar $varvame var
   puts "DEBUG Info: tracer: $varName was updated to be \"$var\""
}
if {0} {;# use tracer
   trace variable var_example wu tracer
   trace vinfo var_example
   trace vdelete var_example wu command
}

proc debug_proc_tracer args {
   puts "debug_proc_tracer $args"
}
proc debug_add_trace_to_proc {name {yesno 1}} {
   set mode [expr {$yesno? "add":"remove"}]
   trace $mode execution $name {enter leave} debug_proc_tracer
}

proc time_flag {flag} {
   putsd "TIME_FLAG: $flag - [debug timestamp]"
}

###12 OO
if {0} {
   itcl::find class tclass
   itcl::delete class tclass
   source xxx/xxx/itcl.tcl
}

proc make_obj {class_name obj_name} {
   set name $obj_name
   if {[itcl::find object $name -class $xlass_name] ne ""} {
      itcl::delete object $name
   }
   $class_name $name
}

###13 tcllib 
# move to head of this file

###14 PATH
proc lappend_PATH {path_name dir} {
   upvar 1 $path_name var
   if {[lsearch $var $dir]==-1} {
      lappend var $dir
   }
}
###15 FILE RELATED
proc grep {re args} {
   set return_flag 0
   set files [eval glob -types f $args]
   foreach file $files {
      set fp [open $file]
      while {[gets $fp line]>=0} {
         if [regexp -- $re $line] {
            if {[llength $files]>1} {puts -nonewline $file:}
            puts $line
            set return_flag 1
         }
      }
      close $fp
   }
   return $return_flag
}

###16 TIMING PATh
proc get_timing_path_segment {from to {include_hierarchical_pins 1}} {
   if {$include_hierarchical_pins} {
      set path_clct [get_timing_paths -thr $from -to $to -include]
   } else {
      set path_clct [get_timing_paths -thr $from -to $to ]
   }
   if {[sizeof_coll $path_clct]==0} {
      puts "Warning: proc get_timing_path_segment: no path from $from to $to"
      return
   }
   set path [index_collection $path_clct 0]

   set flag_in_segment 0
   set flag_in_segment_buf 0
   set ansList [list]

   foreach_in_c p [get_attr $path points] {
      set obj [get_attr $p object]
      set point_name [get_attr $obj full_name]

      set suffix ""
      if {$point_name eq $from} {
         set flag_in_segment 1
         set flag_in_segment_buf 1
         set suffix "<-"
      }
      if {$point_name eq $to} {
         set flag_in_segment_buf 0
         set suffix "<-"
      }

      if {$flag_in_segment} {
         lappend ansList $point_name
      }
      set flag_in_segment $flag_in_segment_buf
   }
   return $ansList
}


###17 TECH RELATED
proc get_bitcnt {ref_name} {
   puts "calling proc get_bitcnt $ref_name"
}

proc sum_of_bitcnt {cell_list} {
   set sum 0
   foreach c $cell_list {
      set ref [get_attr $c ref_name]
      incr sum [get_bitcnt $ref]
   }
   return $sum
}

