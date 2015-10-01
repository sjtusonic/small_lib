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
#   0    BASIC:
proc source_echo {file_name} {

}
#
#   1   CONNECTION
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
    set returnList [list]
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

