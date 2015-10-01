set auto_path [concat $auto_path $TCL_8.4_DIR $TCLLIB_DIR $ITCL_DIR $TK_CON_DIR]

package require Itcl
package require debug
package require debug::heartbeat

##########
#   TOOL:
##########
#
if {$USAGE_ENV eq "DesignCompiler" } {
#   1   CONNECTION
proc get_fi_pin_level {dPinName {level -1}} {
    if {$level == -1 } {
        set allFiClct [all_fanin -to [get_pins $dPinName] -flat]
    } else {
        set allFiClct [all_fanin -to [get_pins $dPinName] -flat -level $level]
    }
    set pin [filter_colection $allFiClct {direction==2}]
    return $pin
}

proc get_fi_seq_pin {dPinName} {
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
proc get_fo_from_pin {} {

}



}
