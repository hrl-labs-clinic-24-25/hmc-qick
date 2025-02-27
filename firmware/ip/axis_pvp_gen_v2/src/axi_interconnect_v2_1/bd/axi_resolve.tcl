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

proc resolve_protocol { resolve_net name src_val dest_val } {
  ifx_debug_proc_header

  set ip [ifx_insert_ip $resolve_net $name xilinx.com:ip:axi_protocol_converter:2.1]

  ifx_puts "Assigning conversion properties directly into $ip:"
  set_property CONFIG.SI_PROTOCOL $src_val $ip
  ifx_readback_check SI_PROTOCOL $src_val $ip
  set_property CONFIG.SI_PROTOCOL.VALUE_SRC USER $ip
  ifx_readback_check SI_PROTOCOL.VALUE_SRC USER $ip
  
  set_property CONFIG.MI_PROTOCOL $dest_val $ip
  ifx_readback_check MI_PROTOCOL $dest_val $ip
  set_property CONFIG.MI_PROTOCOL.VALUE_SRC USER $ip
  ifx_readback_check MI_PROTOCOL.VALUE_SRC USER $ip

  ifx_debug_proc_footer
  return $ip
}

proc resolve_data_width { resolve_net name src_val dest_val } {
  ifx_debug_proc_header
  set ip [ifx_insert_ip $resolve_net $name xilinx.com:ip:axi_dwidth_converter:2.1]

  ifx_puts "Assigning conversion properties directly into $ip:"
  set_property CONFIG.SI_DATA_WIDTH $src_val $ip
  ifx_readback_check SI_DATA_WIDTH $src_val $ip
  set_property CONFIG.SI_DATA_WIDTH.VALUE_SRC USER $ip
  ifx_readback_check SI_DATA_WIDTH.VALUE_SRC USER $ip
  
  set_property CONFIG.MI_DATA_WIDTH $dest_val $ip
  ifx_readback_check MI_DATA_WIDTH $dest_val $ip
  set_property CONFIG.MI_DATA_WIDTH.VALUE_SRC USER $ip
  ifx_readback_check MI_DATA_WIDTH.VALUE_SRC USER $ip
  
  ifx_debug_proc_footer
  return $ip
}

proc assign_synchronization_stages { ip } {
  ifx_debug_proc_header
  set appcore_cell [get_bd_cells [join [lrange [split $ip /] 0 end-2] /]]
  set ip [get_bd_cells $ip]
  if {[get_property CONFIG.ENABLE_ADVANCED_OPTIONS $appcore_cell] == 1 && [get_property CONFIG.SYNCHRONIZATION_STAGES.VALUE_SRC $appcore_cell] == "USER"} {
    set appcore_synchronization_stages [get_property CONFIG.SYNCHRONIZATION_STAGES $appcore_cell]
    ifx_puts "Assigning synchronization_stages $appcore_synchronization_stages to $ip"
    set_property CONFIG.SYNCHRONIZATION_STAGES $appcore_synchronization_stages $ip
  }
  ifx_debug_proc_footer
}

proc assign_combo_us_cc_df { ip } { 
  ifx_debug_proc_header

  set ip [get_bd_cells $ip]
  set_property CONFIG.FIFO_MODE 2 $ip
  ifx_puts "FIFO_MODE of $ip is [get_property CONFIG.FIFO_MODE $ip]"
  ifx_puts "bd_pins on $ip are [get_bd_pins -of_objects $ip -filter {type==clk}]"

  assign_synchronization_stages $ip

  ifx_debug_proc_footer
}

proc resolve_combo_us_cc_df { resolve_net name src_val dest_val } {
  ifx_debug_proc_header

  set ip [ifx_insert_ip $resolve_net $name xilinx.com:ip:axi_dwidth_converter:2.1 assign_combo_us_cc_df]
  
  set_property CONFIG.MI_DATA_WIDTH $dest_val $ip
  ifx_readback_check MI_DATA_WIDTH $dest_val $ip
  set_property CONFIG.MI_DATA_WIDTH.VALUE_SRC USER $ip
  ifx_readback_check MI_DATA_WIDTH.VALUE_SRC USER $ip

  set_property CONFIG.SI_DATA_WIDTH $src_val $ip
  ifx_readback_check SI_DATA_WIDTH $src_val $ip
  set_property CONFIG.SI_DATA_WIDTH.VALUE_SRC USER $ip
  ifx_readback_check SI_DATA_WIDTH.VALUE_SRC USER $ip

  set coupler_cell [get_bd_cells [join [lrange [split $resolve_net /] 0 end-1] /]]
  set fifo_cell [get_bd_cells -of_objects $coupler_cell -filter {vlnv==xilinx.com:ip:axi_data_fifo:2.1}]

  ifx_remove_cell $fifo_cell

  ifx_debug_proc_footer
  return $ip
}

proc assign_combo_us_df { ip } {
  set_property CONFIG.FIFO_MODE 1 [get_bd_cells $ip]
}

proc resolve_combo_us_df { resolve_net name src_val dest_val } {
  ifx_debug_proc_header
  set ip [ifx_insert_ip $resolve_net $name xilinx.com:ip:axi_dwidth_converter:2.1 assign_combo_us_df]

  set_property CONFIG.MI_DATA_WIDTH $dest_val $ip
  ifx_readback_check MI_DATA_WIDTH $dest_val $ip
  set_property CONFIG.MI_DATA_WIDTH.VALUE_SRC USER $ip
  ifx_readback_check MI_DATA_WIDTH.VALUE_SRC USER $ip

  set_property CONFIG.SI_DATA_WIDTH $src_val $ip
  ifx_readback_check SI_DATA_WIDTH $src_val $ip
  set_property CONFIG.SI_DATA_WIDTH.VALUE_SRC USER $ip
  ifx_readback_check SI_DATA_WIDTH.VALUE_SRC USER $ip
  
  set coupler_cell [get_bd_cells [join [lrange [split $resolve_net /] 0 end-1] /]]
  set fifo_cell [get_bd_cells -of_objects $coupler_cell -filter {vlnv==xilinx.com:ip:axi_data_fifo:2.1}]
  ifx_remove_cell $fifo_cell
  
  ifx_debug_proc_footer
  return $ip
}

proc disable_pc_splitter { coupler_cell } {
  ifx_debug_proc_header
  set couplers [get_bd_cells $coupler_cell]
  set pc [get_bd_cells -of_objects $couplers -filter {vlnv==xilinx.com:ip:axi_protocol_converter:2.1}]
  set ds [get_bd_cells -of_objects $couplers -filter {vlnv==xilinx.com:ip:axi_dwidth_converter:2.1}]

  if {[llength $pc] == 1 && [llength $ds] == 1} {
    set_property CONFIG.TRANSLATION_MODE 0 $pc
    ifx_readback_check TRANSLATION_MODE 0 $pc
    set_property CONFIG.MAX_SPLIT_BEATS 16 $ds
    ifx_readback_check MAX_SPLIT_BEATS 16 $ds
  } else {
    ifx_puts "ERROR: couldn't find protocol converter with vlnv xilinx.com:ip:axi_protocol_converter:2.1 in $couplers"
  }

  ifx_debug_proc_footer
  return {}
}

proc resolve_ds_auto_rs { resolve_net name } {
  ifx_debug_proc_header

  set appcore_cell [get_bd_cells [join [lrange [split $resolve_net /] 0 end-2] /]]
  set coupler_cell [get_bd_cells [join [lrange [split $resolve_net /] 0 end-1] /]]
  set df [get_bd_cells -of_objects $coupler_cell -filter {vlnv==xilinx.com:ip:axi_data_fifo:2.1}]
  set dwc [get_bd_cells -of_objects $coupler_cell -filter {vlnv==xilinx.com:ip:axi_dwidth_converter:2.1}]
  set intf [get_bd_intf_pins -of_objects $dwc -filter {mode==Master}]
  set net [get_bd_intf_nets -of_objects $intf]
  set downstream_ip [get_bd_cells -of_objects $net -filter {vlnv!=xilinx.com:ip:axi_dwidth_converter:2.1}]

  ifx_puts "downstream IP IS: $downstream_ip"

  regexp {([sm])(\d\d)_couplers} [get_property name $coupler_cell] {} role idx
  
  if {$role == "s" && ([get_property CONFIG.[string toupper $role]${idx}_HAS_DATA_FIFO $appcore_cell] > 0)} {
    ifx_puts "Data fifo available - no auto_rs required for $coupler_cell & $dwc"
    set ip ""
  } elseif {($role == "m") && ([get_property CONFIG.[string toupper $role]${idx}_HAS_REGSLICE $appcore_cell] == 4) && ([get_property VLNV $downstream_ip] == "xilinx.com:ip:axi_register_slice:2.1")} {
      ifx_puts "Downstream IP is a register slice"
    set ip ""
  } else {
    set ip [ifx_insert_ip $net $name xilinx.com:ip:axi_register_slice:2.1]
  }
  ifx_debug_proc_footer
  return $ip
}

proc resolve_us_auto_rs { resolve_net name } {
  ifx_debug_proc_header

  set appcore_cell [get_bd_cells [join [lrange [split $resolve_net /] 0 end-2] /]]
  set coupler_cell [get_bd_cells [join [lrange [split $resolve_net /] 0 end-1] /]]
  set dwc [get_bd_cells -of_objects $coupler_cell -filter {vlnv==xilinx.com:ip:axi_dwidth_converter:2.1}]
  set intf [get_bd_intf_pins -of_objects $dwc -filter {mode==Slave}]
  set net [get_bd_intf_nets -of_objects $intf]  
  set upstream_ip [get_bd_cells -of_objects $net -filter {vlnv!=xilinx.com:ip:axi_dwidth_converter:2.1}]

  regexp {([sm])(\d\d)_couplers} [get_property name $coupler_cell] {} role idx

  ifx_puts "UPSTREAM IP IS: $upstream_ip"

  if {$role == "m" && ([get_property CONFIG.[string toupper $role]${idx}_HAS_DATA_FIFO $appcore_cell] > 0)} {
    ifx_puts "Data fifo available - no auto_rs required for $coupler_cell & $dwc"
    set ip ""
  } elseif {($role == "s") && ([get_property CONFIG.[string toupper $role]${idx}_HAS_REGSLICE $appcore_cell] == 4) && ([get_property VLNV $upstream_ip] == "xilinx.com:ip:axi_register_slice:2.1")} {
    ifx_puts "Downstream IP is a register slice"
    set ip ""
  } else {
    ifx_insert_ip $net $name xilinx.com:ip:axi_register_slice:2.1
    set ip $dwc
  }

  ifx_debug_proc_footer
  return $ip
}

proc assign_auto_rs_w { ip } {
  set_property -dict {CONFIG.REG_AR 0 CONFIG.REG_R 0 CONFIG.REG_AW 0 CONFIG.REG_B 0 CONFIG.REG_W 1} [get_bd_cells $ip]
}

proc resolve_dwc_auto_rs_w { resolve_net name } {
  ifx_debug_proc_header

  set appcore_cell [get_bd_cells [join [lrange [split $resolve_net /] 0 end-2] /]]
  set coupler_cell [get_bd_cells [join [lrange [split $resolve_net /] 0 end-1] /]]
  set dwc [get_bd_cells -of_objects $coupler_cell -filter {vlnv==xilinx.com:ip:axi_dwidth_converter:2.1}]
  set has_df [llength [get_bd_cells -quiet -of_objects $coupler_cell -filter {vlnv==xilinx.com:ip:axi_data_fifo:2.1}]]
  regexp {([sm])(\d\d)_couplers} [get_property name $coupler_cell] {} role idx

  if {$role == "m"} {
    set intf_mode Slave
  } else {
    set intf_mode Master
  }
  
  set intf [get_bd_intf_pins -of_objects $dwc -filter "mode==$intf_mode"]
  set net [get_bd_intf_nets -of_objects $intf]  
  set conn_ip [get_bd_cells -of_objects $net -filter "vlnv!~xilinx.com:ip:axi_dwidth_converter:2.1"]

  if {[llength $conn_ip] > 0} {
    set conn_ip_vlnv [get_property VLNV $conn_ip]
  } else {
    set conn_ip_vlnv ""
  }

  if {[string match "xilinx.com:ip:axi_register_slice:*" $conn_ip_vlnv] || 
      [string match "xilinx.com:ip:axi_clock_converter:*" $conn_ip_vlnv] || 
      $has_df } {
    set ip ""
    ifx_puts "No auto_rs required at $dwc (conn_ip is $conn_ip_vlnv or dwc is packet mode)"
  } else {
    set ip [ifx_insert_ip $net $name xilinx.com:ip:axi_register_slice:2.1 assign_auto_rs_w]
  }

  ifx_debug_proc_footer
  return $ip
}

proc axi_resolve {resolve_net conflict_dict} {
  global env
  ifx_debug_proc_header 

#  dict for {conf_net conf_info} $conflict_dict {
#    dict for {obj props} $conf_info {dict append remap [get_mode $obj] " $props"}
#  }

  dict for {conf_net conf_info} $conflict_dict {
    dict for {obj props} $conf_info {
      dict append remap [get_mode $obj] " $props"
      dict for {p v} $props { 
        dict append ocp $p " $obj" 
      }
    }
  }


  ifx_puts "remap: $remap"

  set containerCell [string range $resolve_net 0 [expr [string last "/" $resolve_net] -1 ]]
  current_bd_instance $containerCell
  
  set appcore_cell [get_bd_cells [join [lrange [split $containerCell /] 0 end-1 ] /]]
  regexp {([sim])(\d\d)_couplers} [lindex [split $containerCell /] end] {} role idx
  set role [string toupper $role]
  
  foreach p {DATA_WIDTH FREQ_HZ PROTOCOL PHASE CLK_DOMAIN} { set conflict_$p 0 }
  foreach r {auto_pc auto_us auto_ds auto_us_cc_df auto_us_df} { set $r 0 }

  set f "%20s|%20s|%20s"
  ifx_puts [format $f "Conflict" "Source" "Dest"]
  dict for {r a} $remap {
    dict for {p v} $a {
 #     ifx_puts [format $f $p [dict get $remap src $p] [dict get $remap dest $p]]
      set conflict_$p 1
      set ${r}_$p $v
    }
  }

  set single_coupler_clk_src 0
  set coupler_si_clk [get_bd_pins $containerCell/S_ACLK] 
  set coupler_mi_clk [get_bd_pins $containerCell/M_ACLK]
  set coupler_si_clk_src [bd::utils::old_find_bd_objs -quiet -relation CONNECTED_TO $coupler_si_clk]
  set coupler_mi_clk_src [bd::utils::old_find_bd_objs -quiet -relation CONNECTED_TO $coupler_mi_clk]

  ifx_puts "SI Clk: $coupler_si_clk"
  ifx_puts "SI Clk Src: $coupler_si_clk_src"
  ifx_puts "MI Clk: $coupler_mi_clk"
  ifx_puts "MI Clk Src: $coupler_mi_clk_src"    
  
  if {[llength $coupler_mi_clk_src] == 1 && [llength $coupler_si_clk_src] == 1 && ($coupler_si_clk_src == $coupler_mi_clk_src)} {
    ifx_puts "Detected the same clock source for coupler clocks.   No clock conversion will be applied."
    set single_coupler_clk_src 1
  }

  ifx_puts "single_coupler_clk_src: $single_coupler_clk_src"

  set adaptor_insertion {
    auto_pc {$conflict_PROTOCOL   && $conflict_DATA_WIDTH && ($src_DATA_WIDTH < $dest_DATA_WIDTH)}  {resolve_protocol $resolve_net $name $src_PROTOCOL $dest_PROTOCOL}
    auto_us_cc_df 
    {(![info exists env(XIL_IFX_DISABLE_COMBO_RESOLUTION)]) && $conflict_DATA_WIDTH && ($src_DATA_WIDTH < $dest_DATA_WIDTH) && !$single_coupler_clk_src && ([get_property CONFIG.$role${idx}_HAS_DATA_FIFO $appcore_cell] == 2)} 
    {resolve_combo_us_cc_df $resolve_net $name $src_DATA_WIDTH $dest_DATA_WIDTH}
    auto_us_df 
    {(![info exists env(XIL_IFX_DISABLE_COMBO_RESOLUTION)]) && $conflict_DATA_WIDTH && ($src_DATA_WIDTH < $dest_DATA_WIDTH) && ([get_property CONFIG.$role${idx}_HAS_DATA_FIFO $appcore_cell] == 2) && !$resolved_auto_us_cc_df} 
    {resolve_combo_us_df $resolve_net $name $src_DATA_WIDTH $dest_DATA_WIDTH}
    auto_us {$conflict_DATA_WIDTH && ($src_DATA_WIDTH <  $dest_DATA_WIDTH) && !$resolved_auto_us_cc_df && !$resolved_auto_us_df} {resolve_data_width $resolve_net $name $src_DATA_WIDTH $dest_DATA_WIDTH}
    auto_rs {$role != "I" && $resolved_auto_us && [get_property CONFIG.$role${idx}_HAS_REGSLICE $appcore_cell]>=3} {resolve_us_auto_rs $resolve_net $name}
    auto_cc {!$single_coupler_clk_src && !$resolved_auto_us_cc_df} {ifx_insert_ip $resolve_net $name xilinx.com:ip:axi_clock_converter:2.1 assign_synchronization_stages}
    auto_ds {$conflict_DATA_WIDTH && ($src_DATA_WIDTH >  $dest_DATA_WIDTH) && !$resolved_auto_us_cc_df} {resolve_data_width $resolve_net $name $src_DATA_WIDTH $dest_DATA_WIDTH}
    auto_pc {$conflict_PROTOCOL   && !$resolved_auto_pc} {resolve_protocol $resolve_net $name $src_PROTOCOL $dest_PROTOCOL}
    disable_pc_splitter {$resolved_auto_pc && ($src_PROTOCOL == "AXI4" && $dest_PROTOCOL == "AXI3") && ($resolved_auto_ds)} {disable_pc_splitter $containerCell}
    auto_rs {$role != "I" && $resolved_auto_ds && [get_property CONFIG.$role${idx}_HAS_REGSLICE $appcore_cell]>=3} {resolve_ds_auto_rs $resolve_net $name}
    auto_rs_w {$role != "I" && ($resolved_auto_ds || $resolved_auto_us) && [get_property CONFIG.$role${idx}_HAS_REGSLICE $appcore_cell]>=3} {resolve_dwc_auto_rs_w $resolve_net $name}
  }
  
  foreach {name guard action} $adaptor_insertion { 
    ifx_puts "----------------------------------------------------------------------"
    ifx_puts "NAME: $name"
    ifx_puts "GUARD: $guard [expr $guard]"
    ifx_puts "ACTION: $action"

    if {![info exists resolved_$name]} {
      ifx_puts "$name has not been resolved before..."
      set resolved_$name 0
    } else {
      ifx_puts "$name resolve status is currently [subst $[subst resolved_$name]]"
    } 
    if {[expr $guard]} {
      set resolved_$name 1
      set ip [eval $action]
      if {[llength $ip] == 1} { set resolve_net [get_bd_intf_nets -of_objects [get_bd_intf_pins -of_object $ip -filter {mode==Master}]] }

      set guard_conflict_params [regexp -all -inline {(conflict_\w*)} $guard]
      set resolved_params ""
      foreach p $guard_conflict_params {
        if {[subst $$p] == 1} {
          set pn [regsub {conflict_} $p  {}]
          dict set resolved_params $pn [dict get $ocp $pn]
        }
      }
      dict for {p v} $resolved_params {
        ifx_puts "mark_conflict_resolved <$p> <$v>"
        bd::util_cmd mark_conflict_resolved $p $v
      }

    } else {
      ifx_puts "No change required"
    }
  }

  ifx_debug_proc_footer
}
