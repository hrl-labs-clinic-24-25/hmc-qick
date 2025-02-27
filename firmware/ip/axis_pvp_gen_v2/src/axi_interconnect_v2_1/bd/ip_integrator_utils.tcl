###############################################################################
##
## (c) Copyright 2012-2013 Xilinx, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of Xilinx, Inc. and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## Xilinx, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) Xilinx shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or Xilinx had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## Xilinx products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of Xilinx products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##

proc find_nearest_intf_for_resolution_conflict { conflicting_intf_net } {
  set bob [find_nearest_bob $conflicting_intf_net]
  if {$bob != ""} {
    set SI [get_bd_intf_pins "$bob/S_AXI"]
    set conn [get_intf_net_inside $SI]
    # if conn is connected to Reg, return the connection on other
    # side of reg
    set connected_blk [get_bd_cells -of_objects $conn -filter {VLNV==xilinx.com:rodin_ip:axi_register_slice:2.1}]
    if {$connected_blk!=""} {
      set M_AXI [get_bd_intf_pins "$connected_blk/M_AXI"]
      return [get_bd_intf_net -of_objects $M_AXI]
    } else {
      return $conn
    }
  }
  return ""
}

proc isObj { thing } {
  if { [catch {get_property CLASS $thing} ] } {
    return 0
  }
  return 1
}

proc getParentStr { obj } {
  return [string range $obj 0 [expr [string last / $obj] - 1]]
}


proc find_nearest_bob {intf_net} {
  set cell [get_bd_cells -of_objects [getMasterIntf $intf_net]]
  if {[string first couplers $cell] != -1} {
    return $cell
  }
  set cell [get_bd_cells -of_objects [getSlaveIntf $intf_net]]
  if {[string first couplers $cell] != -1} {
    return $cell
  }
  return ""
}

proc isIntfPort { objfullstr } {
     if { [get_bd_intf_ports $objfullstr] == "" } {
         return 0
     } else {
        return 1
     }
}

proc getMasterIntf {intf_net} {
  if { [isObj $intf_net] } {
    set net $intf_net
  } else {
    set net [get_bd_intf_nets $intf_net]
  }

  set intf [get_bd_intf_pins -of_objects $net -filter {(MODE==Master && TYPE==ip) || (MODE==Slave && TYPE==hier)} ]
  if {$intf == ""} {
    set intf [get_bd_intf_ports -of_objects $net -filter {MODE==Master}]
    if {[getParentStr $intf] != ""} {
      set intf [get_bd_intf_pins $intf]
    }
  }
  return $intf
}

proc getSlaveIntf {intf_net} {
  if { [isObj $intf_net] } {
    set net $intf_net
  } else {
    set net [get_bd_intf_nets $intf_net]
  }
  set intf [get_bd_intf_pins -of_objects $net -filter {(MODE==Slave && TYPE==ip) || (MODE==Master && TYPE==hier)}]
  if {$intf == ""} {
    set intf [get_bd_intf_ports -of_objects $net -filter {MODE==Slave}]
    if {[getParentStr $intf] != ""} {
      set intf [get_bd_intf_pins $intf]
    }
  }
  return $intf
}

# Temp hack becasue get_bd_intf_nets -of_objects does not
# return intf_nets inside of hierarchy
proc get_intf_net_inside { intf_pin } {
  set parentCell [get_bd_cells [getParentStr $intf_pin]]
  set inets [get_bd_intf_nets -of_objects $parentCell]
  foreach inet $inets {
    # Another hack, in hier blk, have to use get_bd_intf_ports on the 
    # boundary of hierblock, and from the intf_port ob, get the corresponding
    # sb_intf_pin.
    # but in this case, I am just matching names, so I can just use
    # the name of the intf_pin == intf_port since they have the same
    # full_name
    set intfPorts [get_bd_intf_ports -of_objects $inet]
    foreach intfPort $intfPorts {
      if {[string equal $intfPort $intf_pin]} {
        return $inet
      }
    }
  }
  return ""
}

# Temp hack becasue get_bd_intf_nets -of_objects does not
# return intf_nets inside of hierarchy
proc get_net_inside { pin } {
  set parentCell [get_bd_cells [getParentStr $pin]]
  if {[get_property TYPE $parentCell] == "hier"} {
    set nets [get_bd_nets -of_objects $parentCell]
    foreach net $nets {
      # Another hack, in hier blk, have to use get_bd_ports on the 
      # boundary of hierblock, and from the intf_port ob, get the corresponding
      # sb_pin.
      # but in this case, I am just matching names, so I can just use
      # the name of the intf_pin == intf_port since they have the same
      # full_name
      set ports [get_bd_ports -of_objects $net]
      foreach port $ports {
        if {[string equal $port $pin]} {
          return $net
        }
      }
    }
  } else {
    return [get_bd_nets -of_objects [get_bd_pins $pin]]
  }

  return ""
}


# ----------------------------------------------------------------------
# FROM SHAY:
proc find_associated_clk_pin { intf_pin } {
  if { [isObj $intf_pin] } {
    set intf $intf_pin
  } else {
    set intf [get_bd_intf_pins $intf_pin]
  }
  if {$intf == ""} {
    debug::send_message -severity ERROR -msg "$intf_pin doesn't exist"    
  }

  regexp "(.*\/.*)\/.*$" $intf {} parentCellPath
  set parentCell [get_bd_cells $parentCellPath]
  set clk_pins [ get_bd_pins -of_object $parentCell -filter { TYPE==clk } ]

  foreach pin $clk_pins {
    set assoc_busifs [get_property CONFIG.ASSOCIATED_BUSIF $pin]
    if {$assoc_busifs!=""} {
      set toks [split $assoc_busifs :]
      foreach busif $toks {
        set busif_parts [split $intf_pin /]
        set name [lindex $busif_parts [expr [llength $busif_parts] - 1]]
        if {[string equal $name $busif]} {
          # if name of intf_pin is same as name in CONFIG.ASSOCIATED_BUSIF
          # we are done
          return $pin
        }
      }
    }
  }
  return  ""
}

proc find_associated_rst_pin { intf_pin } {
  if { [isObj $intf_pin] } {
    set intf $intf_pin
  } else {
    set intf [get_bd_intf_pins $intf_pin]
  }

  set pin [find_associated_clk_pin $intf_pin]
  regexp "(.*\/.*)\/.*$" $intf {} parentCellPath
  set parentCell [get_bd_cells $parentCellPath]
  set assoc_busifs [get_property CONFIG.ASSOCIATED_RESET $pin]
  if {$assoc_busifs!=""} {
    return [get_bd_pins "$parentCell/$assoc_busifs"]
  }
  return  ""
}


proc get_bd_intf_obj { name } {
  set obj [get_bd_intf_pins $name]
  if {$obj == ""} {
    set obj [get_bd_intf_ports $name]
  }
  return $obj
}

proc get_parent_cell_type { obj } {
  set parent [get_bd_cells -of_objects $obj]
  if {$parent != ""} {
    return [get_property TYPE $parent]
  }
  return 
}

proc get_mode { obj } {
  return [::bd::get_intf_obj_mode $obj]
#  set intf [get_bd_intf_obj $obj]
#  set t [get_property -quiet TYPE  [get_bd_cells -of_objects $intf]]
#  set m [get_property MODE  $intf]
#  set c [get_property CLASS $intf]
#  if {$t != ""} {
#    set r  [dict get {sbintfpin {Slave {hier src ip dest} Master {hier dest ip src}} sbintfport {Slave src Master dest}} $c $m $t]
#  } else {
#    set r  [dict get {sbintfpin {Slave {hier src ip dest} Master {hier dest ip src}} sbintfport {Slave src Master dest}} $c $m ]
#  }
#  return $r
}
