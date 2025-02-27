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

array set ifx_resolve_nets {}
array set ifx_user_params {}
array set ifx_auto_user_params {}

source [::bd::get_vlnv_dir xilinx.com:ip:ifx_util:1.1]/bd/ifx_common_debug_util.tcl
source [::bd::get_vlnv_dir xilinx.com:ip:ifx_util:1.1]/bd/ifx_common_ipi_util.tcl
source [::bd::get_vlnv_dir xilinx.com:ip:ifx_util:1.1]/bd/ifx_common_appcore_util.tcl
source ip_integrator_utils.tcl
source axi_resolve.tcl

proc rsb_resolve { resolve_net conflict_dict } {
  ifx_debug_proc_header

  set si [getSlaveIntf $resolve_net]
  set mi [getMasterIntf $resolve_net]
  ifx_puts "Resolve net is $resolve_net"
  ifx_puts "Conflict Parameters are $conflict_dict"
  
  if {[llength $conflict_dict] == 0} {
    ifx_puts "conflict dictionary contains no parameters"
    return
  }

  if {$si == "" || $mi == ""} {
    ifx_puts "ERROR: SI ($si) or MI ($mi) is undefined"
    return
  }

  set conflict_net [dict keys $conflict_dict]
  axi_resolve $resolve_net $conflict_dict

  ifx_debug_proc_footer
}

proc init { cell_name args } {
  ifx_debug_proc_header
  bd::mark_propagate_overrideable [get_bd_cells $cell_name] {XBAR_DATA_WIDTH SYNCHRONIZATION_STAGES}  
  ifx_debug_proc_footer
  return []
}

proc pre_propagate { this {prop_info {}} } {
  global env
  ifx_debug_proc_header
  update_contents $this $prop_info

  if {[info exists env(XIL_IFX_NULLIFY_DEPENDENT_INTERFACE_PROPERTIES)]} {
    ifx_puts "XIL_IFX_NULLIFY_DEPENDENT_INTERFACE_PROPERTIES enabled"
    current_bd_instance [get_bd_cells $this]
    foreach c [get_bd_cells -hier -filter {type==ip}] {
      foreach i [get_bd_intf_pins -of_objects $c -filter {vlnv==xilinx.com:interface:aximm_rtl:1.0}] {
        foreach p {READ_WRITE_MODE PROTOCOL} {
          ifx_puts "NULLIFY: <$c> <$i> <$p>"
          set_property CONFIG.$p NULL $i
          set_property CONFIG.$p.VALUE_SRC DEFAULT $i
        }
      }
    }
  }
  ifx_debug_proc_footer
}

proc post_propagate { this {prop_info {}} } {
  variable ifx_resolve_nets
  variable ifx_auto_user_params

  ifx_debug_proc_header

  set resolve_nets [lsort [array names ifx_resolve_nets "[current_bd_design]:$this/*"]]
  ifx_puts "Resolve nets for design: [current_bd_design] instance $this are:"
  foreach n $resolve_nets {ifx_puts "$n"}

  foreach net_ref $resolve_nets {
    set net [lindex  [split $net_ref :] 1]
    set inet [get_bd_intf_net $net]

    #ifx_puts "search_for_conflicts (filtering $this) on $net"
    ifx_puts "search_for_conflicts on $net"
    #set conflict [bd::util_cmd search_for_conflicts filter $this $net]
    set conflict [bd::util_cmd search_for_conflicts $net]

    ifx_puts "conflicts are <$conflict>"

    if {[llength $conflict] > 0} {
      rsb_resolve $inet [dict get $conflict $inet]
      array unset ifx_resolve_nets $net_ref
    } else {
      ifx_puts "No conflicts detected on $net"
    }
  }

  if {[info exists env(XIL_IFX_ENABLE_PROPERTY_PERSISTENCE)]} {  
    pop_user_params $this ifx_auto_user_params
  }

  set run_second_pass 0
  set cells [get_bd_cells -hier -of_object [get_bd_cells $this]]
  foreach c $cells {
    if {[string match "auto_*" [lindex [split $c /] end]]} {
      ifx_puts "$c is a converter IP: triggering additional propagation round"
      set run_second_pass 1
      break
    }
    ifx_puts "$c is not a converter IP"
  }

  if {[get_param bd.addr_relations_use_matrices] == 0} {
    # ----------------------------------------------------------------------
    # Insert MMUs if required
    current_bd_instance $this
    set ip [get_bd_cells $this]
    set sis [get_bd_intf_pins -of_objects $ip -filter {vlnv==xilinx.com:interface:aximm_rtl:1.0 && mode==Slave}]
    foreach si $sis {
      if {[get_property CONFIG.NUM_SI $ip] == 1 && [get_property CONFIG.NUM_MI $ip] == 1} {
        set need_mmu false
      } else {
        set need_mmu [::bd::addr::is_mmu_required_for $si];
      }

      set xbar [find_upstream_xbar $si]
      if {$need_mmu != "false" && [llength $xbar] == 0} {
        regexp {S(\d\d)_AXI} [get_property NAME $si] {} idx
        set mmu [create_bd_cell -vlnv xilinx.com:ip:axi_mmu:2.1 s${idx}_mmu ]
        set target_net [get_bd_intf_nets -of_objects $ip -filter "name==[get_property name $ip]_to_s${idx}_couplers"]
        delete_bd_obj $target_net
        connect_bd_intf_net [get_bd_intf_pin $mmu/S_AXI] [get_bd_intf_pin $ip/S${idx}_AXI]
        connect_bd_intf_net [get_bd_intf_pin $mmu/M_AXI] [get_bd_intf_pin s${idx}_couplers/s_axi]
        connect_bd_net -net [get_bd_net -of_objects [get_bd_pins s${idx}_couplers/s_aclk]] [get_bd_pins $mmu/aclk]
        connect_bd_net -net [get_bd_net -of_objects [get_bd_pins s${idx}_couplers/s_aresetn]] [get_bd_pins $mmu/aresetn]
        set run_second_pass 1
      } else {
        ifx_puts "MMU Required: $need_mmu"
        ifx_puts "Upstream xbar: $xbar"
      }
    }
  }

  ifx_puts "post_propagate return code: $run_second_pass"
  ifx_debug_proc_footer

  return $run_second_pass
}

proc find_upstream_xbar { si } {
  set si [get_bd_intf_pins $si]
  set iter 0
  while {[info exists si] && $si != "" && $iter < 10000} {
    set prev_si $si
    set mi [bd::utils::old_find_bd_objs -relation CONNECTED_TO $si]
    unset si

    if {[llength $mi] == 1} {
      # Did we find an endpoint immediately?
      if {[get_property CLASS $mi] == "bd_intf_port" ||
          ([get_property CLASS $mi] == "bd_intf_pin" &&
           [get_property BD_ATTRIBUTE.TYPE $mi] == "END_POINT")} {
        ifx_puts "Endpoint $mi"
        return {}
      } 

      # did we find a crossbar?
      set ip [get_bd_cells -of_objects $mi]
      if {[string match "xilinx.com:ip:axi_crossbar:*" [get_property VLNV $ip]]} {
        ifx_puts "xbar: $ip"
        return $ip
      }

      set ip_sis [get_bd_intf_pins -of_objects $ip -filter {vlnv==xilinx.com:interface:aximm_rtl:1.0 && mode==Slave}]
      if {[llength $ip_sis] == 1} {
        # It's a passthrough coupler, continue searching back:
        set si [lindex $ip_sis 0]
        ifx_puts "Passthrough coupler: $ip, si: $si... iterating..."
      } else {
        # Can't search further - not a 1:1 coupler
        ifx_puts "!Passthrough coupler && !Endpoint... Halt traversal"
        return {}
      }
    }
  }  
  ifx_puts "ERROR: Maximum iteration count reached\n"
  return {}
}

proc gen_si_name      {idx} { return [format "S%.2d_AXI"     $idx ] }
proc gen_mi_name      {idx} { return [format "M%.2d_AXI"     $idx ] }
proc gen_si_aclk_name {idx} { return [format "S%.2d_ACLK"    $idx ] }
proc gen_mi_aclk_name {idx} { return [format "M%.2d_ACLK"    $idx ] }
proc gen_si_arst_name {idx} { return [format "S%.2d_ARESETN" $idx ] }
proc gen_mi_arst_name {idx} { return [format "M%.2d_ARESETN" $idx ] }

proc update_boundary { this {prop_info {}} } {
  ifx_debug_proc_header

  global env

  if {[info exists env(XIL_IFX_DISABLE_APPCORE_UPDATE_BOUNDARY)]} {
    ifx_puts "Update contents has been disabled"
    return
  }

  set obj [get_bd_cells $this]
  current_bd_instance $obj

  set si_pins [get_bd_intf_pins -hier -regexp "S\[0-9\]*_AXI"]
  set mi_pins [get_bd_intf_pins -hier -regexp "M\[0-9\]*_AXI"]
  set num_si_pins [llength $si_pins]
  set num_mi_pins [llength $mi_pins]

  set num_si [get_property CONFIG.NUM_SI $obj]
  set num_mi [get_property CONFIG.NUM_MI $obj]

  if {[get_bd_pins $obj/ACLK] == ""} {
    set ict_clk [create_bd_pin -type clk -dir I ACLK]
    set_property CONFIG.ASSOCIATED_RESET ARESETN $ict_clk
  }

  if {[get_bd_pins $obj/ARESETN] == ""} {
    set ict_rst [create_bd_pin -type rst -dir I ARESETN]
  }

  if { $num_si > $num_si_pins } {
    for {set i $num_si_pins} {$i < $num_si} {incr i} {
      set intf [create_bd_intf_pin -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode slave [gen_si_name $i]]
      set clk  [create_bd_pin -type clk -dir I [gen_si_aclk_name $i]]
      set rst  [create_bd_pin -type rst -dir I [gen_si_arst_name $i]]
      set_property CONFIG.ASSOCIATED_BUSIF [gen_si_name $i]    $clk
      set_property CONFIG.ASSOCIATED_RESET [gen_si_arst_name $i] $clk
    }
  }
  
  if { $num_si < $num_si_pins } {
    for {set i $num_si} {$i < $num_si_pins} {incr i} {
      ifx_puts "Deleting port S$i"
      delete_bd_objs [get_bd_intf_pins [gen_si_name $i]]
      delete_bd_objs [get_bd_pins [gen_si_aclk_name $i]]
      delete_bd_objs [get_bd_pins [gen_si_arst_name $i]]
    }
  }
  
  if { $num_mi > $num_mi_pins } {
    for {set i $num_mi_pins} {$i < $num_mi} {incr i} {
      set intf [create_bd_intf_pin -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode master [gen_mi_name $i]]
      set clk  [create_bd_pin -type clk -dir I [gen_mi_aclk_name $i]]
      set rst  [create_bd_pin -type rst -dir I [gen_mi_arst_name $i]]
      set_property CONFIG.ASSOCIATED_BUSIF [gen_mi_name $i]    $clk
      set_property CONFIG.ASSOCIATED_RESET [gen_mi_arst_name $i] $clk
    }
  }
  
  if { $num_mi < $num_mi_pins } {
    for {set i $num_mi} {$i < $num_mi_pins} {incr i} {
      delete_bd_objs [get_bd_intf_pins [gen_mi_name $i]]
      delete_bd_objs [get_bd_pins [gen_mi_aclk_name $i]]
      delete_bd_objs [get_bd_pins [gen_mi_arst_name $i]]                
    }
  }

  ifx_debug_proc_footer
}

proc update_contents {this {prop_info {}} } {
  ifx_debug_proc_header

  variable ifx_resolve_nets
  ifx_puts "clearing resolve nets for: [current_bd_design]:$this/*"
  foreach n [array names ifx_resolve_nets "[current_bd_design]:$this/*"] {  ifx_puts "-- match $n"  }
  array unset ifx_resolve_nets "[current_bd_design]:$this/*"
  ifx_puts "resolve nets now: [current_bd_design]:$this/*"
  foreach n [array names ifx_resolve_nets "[current_bd_design]:$this/*"] {  ifx_puts "-- match $n"  }

  global env

  if {[info exists env(XIL_IFX_DISABLE_APPCORE_UPDATE_CONTENTS)]} {
    ifx_puts "Update contents has been disabled"
    return
  }

  if {[info exists env(XIL_IFX_ENABLE_PROPERTY_PERSISTENCE)]} {
    push_user_params $this
  }

  set obj [get_bd_cells $this]
  set num_si [get_property CONFIG.NUM_SI $obj]
  set num_mi [get_property CONFIG.NUM_MI $obj]    
  set strategy [get_property CONFIG.STRATEGY $obj]

  current_bd_instance $obj

  set si_pins [get_bd_intf_pins -hier -regexp "S\[0-9\]*_AXI"]
  set mi_pins [get_bd_intf_pins -hier -regexp "M\[0-9\]*_AXI"]
  
  set num_si_pins [llength $si_pins]
  set num_mi_pins [llength $mi_pins]
  # ----------------------------------------------------------------------
  set clk_sources ""
  foreach p [get_bd_pins -of_objects $obj -filter type==clk] {
    set c "<[bd::utils::old_find_bd_objs -quiet -relation CONNECTED_TO $p]>"
    lappend clk_sources $c
    ifx_puts "Searching for clk pin source of $p: found $c"
  }
  ifx_puts "Detected these clk pin attachments: $clk_sources"

  set clk_sources [lsort -unique $clk_sources]

  if {[llength $clk_sources] == 1 && ($num_si > 1 || $num_mi > 1)} {
    ifx_puts "Detected unique clk source: $clk_sources.  Setting single clk source"
    set clk_source single
  } else {
    ifx_puts "Detected multiple clk sources: $clk_sources. Setting multiple clk source"
    set clk_source multiple
  }


  # ----------------------------------------------------------------------
  set rst_sources ""
  foreach p [get_bd_pins -of_objects $obj -filter type==rst] {
    set c "<[bd::utils::old_find_bd_objs -quiet -relation CONNECTED_TO $p]>"
    lappend rst_sources $c
    ifx_puts "Searching for rst pin source of $p: found $c"
  }
  ifx_puts "Detected these rst pin attachments: $rst_sources"

  set rst_sources [lsort -unique $rst_sources]

  if {[llength $rst_sources] == 1 && ($num_si > 1 || $num_mi > 1)} {
    ifx_puts "Detected unique rst source: $rst_sources.  Setting single rst source"
    set rst_source single
  } else {
    ifx_puts "Detected multiple rst sources: $rst_sources. Setting multiple rst source"
    set rst_source multiple
  }

  if {[info exists env(XIL_IFX_DISABLE_SINGLE_CLOCK_SOURCE)]} {
    set clk_source "multiple"
    set rst_source "multiple"
  }

  # ----------------------------------------------------------------------
  # Clean out the contents of the appcore:
#   foreach obj_type {nets intf_nets cells} {
#     set objs [get_bd_$obj_type]
  #     if {$objs != ""} {
#       delete_bd_objs $objs
#     }
#   }
  foreach obj_type {nets intf_nets} {
    set objs [get_bd_$obj_type]
    if {$objs != ""} {
      delete_bd_objs $objs
    }
  }
  set objs_to_del [get_bd_cells -filter "path != ${this}/xbar"]
  if {[llength $objs_to_del] > 0} {
    delete_bd_objs $objs_to_del
  }

  set ict_clk [get_bd_pins $obj/ACLK]
  set ict_rst [get_bd_pins $obj/ARESETN]

  set ict_clk_net [create_bd_net [lindex [split $obj /] end]_ACLK_net]
  set ict_rst_net [create_bd_net [lindex [split $obj /] end]_ARESETN_net]
  
#  set crossbar ""
  set crossbar [get_bd_cells ${this}/xbar]
  if {$num_mi > 1 || $num_si > 1} {
#    set crossbar [create_bd_cell -vlnv xilinx.com:ip:axi_crossbar:2.1 -type ip -name xbar]

    if {[llength $crossbar] == 0} {
      set crossbar [create_bd_cell -vlnv xilinx.com:ip:axi_crossbar:2.1 -type ip -name xbar]
      for {set i 0} {$i < 16} {incr i} {
        lappend av CONFIG.M[format %.2d $i]_A00_BASE_ADDR 0xffffffffffffffff
        lappend av CONFIG.M[format %.2d $i]_A00_ADDR_WIDTH 0
        lappend as CONFIG.M[format %.2d $i]_A00_BASE_ADDR.VALUE_SRC DEFAULT
        lappend as CONFIG.M[format %.2d $i]_A00_ADDR_WIDTH.VALUE_SRC DEFAULT
      }
      set_property -dict $av $crossbar
      set_property -dict $as $crossbar
    }

    if {$num_si == 1 && $num_mi > 16} {
      set partition_size 8
      set primary_partitions [expr $num_mi / $partition_size]
      set partition_remainder [expr $num_mi % $partition_size]
      if {$partition_remainder == 1} {        
        set partitions [list {*}[lrepeat [expr ($primary_partitions-1)] 8] 7 2]
      } elseif {$partition_remainder == 0} {
        set partitions [list {*}[lrepeat $primary_partitions 8]]
      } else {
        set partitions [list {*}[lrepeat $primary_partitions 8] $partition_remainder]
      }
      ifx_puts "Partitions are $partitions"

      set_property CONFIG.NUM_SI $num_si $crossbar
#      set_property CONFIG.NUM_SI.VALUE_SRC PROPAGATED $crossbar

      set_property CONFIG.NUM_MI [llength $partitions] $crossbar
#      set_property CONFIG.NUM_MI.VALUE_SRC PROPAGATED $crossbar

      set xbar_clk [get_bd_pins $crossbar/ACLK]
      set xbar_rst [get_bd_pins $crossbar/ARESETN]

      connect_bd_net -net $ict_clk_net $ict_clk $xbar_clk
      connect_bd_net -net $ict_rst_net $ict_rst $xbar_rst

      set i 0
      foreach p $partitions {
        set t2xbar [create_bd_cell -vlnv xilinx.com:ip:axi_crossbar:2.1 -type ip -name tier2_xbar_$i]
        connect_bd_net -net $ict_clk_net [get_bd_pins -of_objects $t2xbar -filter {type==clk}]
        connect_bd_net -net $ict_rst_net [get_bd_pins -of_objects $t2xbar -filter {type==rst}]

        set_property CONFIG.NUM_SI 1 $t2xbar
#        set_property CONFIG.NUM_SI.VALUE_SRC PROPAGATED $t2xbar
        set_property CONFIG.NUM_MI $p $t2xbar
#        set_property CONFIG.NUM_MI.VALUE_SRC PROPAGATED $t2xbar
        incr i
      }

      set tier1_mis [get_bd_intf_pins -of_objects $crossbar -filter {mode==Master}]
      set tier2_xbars [get_bd_cells tier2_xbar_*]
      set i 0
      foreach mi $tier1_mis c $tier2_xbars {
        ifx_puts "creating coupler $mi $c"
        set coupler [create_bd_cell -type hier i[format %.2d $i]_couplers]
        current_bd_instance $coupler
        set coupler_mi [create_bd_intf_pin -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode master M_AXI]
        set coupler_mi_clk [create_bd_pin -type clk -dir I M_ACLK]
        set_property CONFIG.ASSOCIATED_BUSIF M_AXI $coupler_mi_clk
        set_property CONFIG.ASSOCIATED_RESET M_ARESETN $coupler_mi_clk
        set coupler_mi_rst [create_bd_pin -type rst -dir I M_ARESETN]

        set coupler_si [create_bd_intf_pin -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode slave  S_AXI]
        set coupler_si_clk [create_bd_pin -type clk -dir I S_ACLK]
        set_property CONFIG.ASSOCIATED_BUSIF S_AXI $coupler_si_clk
        set_property CONFIG.ASSOCIATED_RESET S_ARESETN $coupler_si_clk
        set coupler_si_rst [create_bd_pin -type rst -dir I S_ARESETN]
        connect_bd_intf_net_with_name $coupler_si $coupler_mi
        mark_coupler_resolve_nets $coupler
        current_bd_instance ..

        connect_bd_intf_net_with_name $mi $coupler_si
        connect_bd_intf_net_with_name $coupler_mi [get_bd_intf_pins -of_objects $c -filter {mode==Slave}]
        connect_bd_net -net $ict_clk_net $coupler_si_clk $coupler_mi_clk
        connect_bd_net -net $ict_rst_net $coupler_si_rst $coupler_mi_rst
        incr i
      }

    } else {
      set_property CONFIG.NUM_SI $num_si $crossbar
#      set_property CONFIG.NUM_SI.VALUE_SRC PROPAGATED $crossbar

      set_property CONFIG.NUM_MI $num_mi $crossbar
#      set_property CONFIG.NUM_MI.VALUE_SRC PROPAGATED $crossbar

      set xbar_clk [get_bd_pins $crossbar/ACLK]
      set xbar_rst [get_bd_pins $crossbar/ARESETN]

      connect_bd_net -net $ict_clk_net $ict_clk $xbar_clk
      connect_bd_net -net $ict_rst_net $ict_rst $xbar_rst
    }
  }

  if {$num_mi == 1 && $num_si == 1 && [llength $crossbar] > 0} {
    delete_bd_objs $crossbar
    set crossbar ""
  }

  # ----------------------------------------------------------------------
  # Generate SI Couplers
  for {set i 0} {$i < $num_si} {incr i} {
    set coupler [create_bd_cell -type hier -name [format "s%.2d_couplers" $i]]
    current_bd_instance $coupler
    set mi [create_bd_intf_pin -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode master M_AXI]
    set mi_clk [create_bd_pin -type clk -dir I M_ACLK]

    set_property CONFIG.ASSOCIATED_BUSIF M_AXI $mi_clk
    set_property CONFIG.ASSOCIATED_RESET M_ARESETN $mi_clk
    set mi_rst [create_bd_pin -type rst -dir I M_ARESETN]

    set si [create_bd_intf_pin -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode slave  S_AXI]
    set si_clk [create_bd_pin -type clk -dir I S_ACLK]
    set_property CONFIG.ASSOCIATED_BUSIF S_AXI $si_clk
    set_property CONFIG.ASSOCIATED_RESET S_ARESETN $si_clk
    set si_rst [create_bd_pin -type rst -dir I S_ARESETN]

    set last_intf $si

    set coupler_chain_spec [subst { 
      {CONFIG.S[format %.2d $i]_HAS_REGSLICE   {(value == 1 || value == 4)} {map_regslice}         "xilinx.com:ip:axi_register_slice:2.1"     s[format %.2d $i]_regslice           $si_clk  $si_rst}
      {CONFIG.S[format %.2d $i]_HAS_DATA_FIFO  {} {map_data_fifo}        "xilinx.com:ip:axi_data_fifo:2.1"          s[format %.2d $i]_data_fifo          $mi_clk  $mi_rst}
      {CONFIG.S[format %.2d $i]_HAS_REGSLICE   {value == 2} {map_regslice}         "xilinx.com:ip:axi_register_slice:2.1"     s[format %.2d $i]_regslice           $si_clk  $si_rst}
    }]
    
    set last_intf [gen_coupler_chain $obj $last_intf $coupler_chain_spec]

    connect_bd_intf_net_with_name $last_intf $mi

    mark_coupler_resolve_nets $coupler

    current_bd_instance $obj
    connect_bd_intf_net_with_name [get_bd_intf_pins $obj/[gen_si_name $i]] $si
    if {$clk_source == "multiple" || $rst_source == "multiple"} {
      connect_bd_net  [get_bd_pins $obj/[gen_si_aclk_name $i]] [get_bd_pins $coupler/S_ACLK]
      connect_bd_net  [get_bd_pins $obj/[gen_si_arst_name $i]] [get_bd_pins $coupler/S_ARESETN]
    } else {
      connect_bd_net  -net $ict_clk_net [get_bd_pins $coupler/S_ACLK]
      connect_bd_net  -net $ict_rst_net [get_bd_pins $coupler/S_ARESETN]
    }

    if {$num_si > 1 || $num_mi > 1} {
      set xbarInterface [format "S%.2d_AXI" $i]
      connect_bd_intf_net_with_name  $mi [get_bd_intf_pins $crossbar/$xbarInterface]
    }
  }

  connect_bd_net -net $ict_clk_net [get_bd_pins -hier -regexp "\.\*s\.\*_couplers\.\*M_ACLK"]
  connect_bd_net -net $ict_rst_net [get_bd_pins -hier -regexp "\.\*s\.\*_couplers\.\*M_ARESETN"]

  # ----------------------------------------------------------------------
  # Generate MI Couplers
  set mis {}
  if {$num_si == 1 && $num_mi == 1} {
    # Do nothing
  } elseif {$num_si == 1 && $num_mi > 16} {
    foreach c [get_bd_cells tier2_xbar_*] {
      lappend mis {*}[get_bd_intf_pins -of_objects $c -filter {mode==Master}]
    }
    set mis [lsort $mis]
  } else {
    set mis [lsort [get_bd_intf_pins -of_objects $crossbar -filter {mode==Master}]]
  }

  # for \{set i 0\} \{$i < $num_mi && $crossbar != ""\} \{incr i\} \{

  set i 0
  foreach xbar_mi $mis {

    set coupler [create_bd_cell -type hier -name [format "m%.2d_couplers" $i]]
    ifx_puts "Created coupler container: $coupler"
    current_bd_instance $coupler
    ifx_puts "current bd instance set to $coupler"

    set mi [create_bd_intf_pin -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode master M_AXI]
    set mi_clk [create_bd_pin -type clk -dir I M_ACLK]
    set_property CONFIG.ASSOCIATED_BUSIF M_AXI $mi_clk
    set_property CONFIG.ASSOCIATED_RESET M_ARESETN $mi_clk
    set mi_rst [create_bd_pin -type rst -dir I M_ARESETN]

    set si [create_bd_intf_pin -vlnv xilinx.com:interface:aximm_rtl:1.0 -mode slave  S_AXI]
    set si_clk [create_bd_pin -type clk -dir I S_ACLK]
    set_property CONFIG.ASSOCIATED_BUSIF S_AXI $si_clk
    set_property CONFIG.ASSOCIATED_RESET S_ARESETN $si_clk
    set si_rst [create_bd_pin -type rst -dir I S_ARESETN]

    set last_intf $si

    set coupler_chain_spec [subst { 
      {CONFIG.M[format %.2d $i]_HAS_REGSLICE  {value == 2} {map_regslice}         "xilinx.com:ip:axi_register_slice:2.1"     m[format "%.2d" ${i}]_regslice    $mi_clk  $mi_rst}
      {CONFIG.M[format %.2d $i]_HAS_DATA_FIFO {}           {map_data_fifo}        "xilinx.com:ip:axi_data_fifo:2.1"          m[format "%.2d" ${i}]_data_fifo   $si_clk  $si_rst}
      {CONFIG.M[format %.2d $i]_HAS_REGSLICE  {(value == 1) || (value == 4)} {map_regslice}         "xilinx.com:ip:axi_register_slice:2.1"     m[format "%.2d" ${i}]_regslice    $mi_clk  $mi_rst}
    }]
    
    set last_intf [gen_coupler_chain $obj $last_intf $coupler_chain_spec]
    connect_bd_intf_net_with_name $last_intf $mi

    mark_coupler_resolve_nets $coupler

    current_bd_instance $obj
    connect_bd_intf_net_with_name $mi [get_bd_intf_pins $obj/[gen_mi_name $i]] 
    if {$clk_source == "multiple" || $rst_source == "multiple"} {
      connect_bd_net  [get_bd_pins $obj/[gen_mi_aclk_name $i]] [get_bd_pins $coupler/M_ACLK]
      connect_bd_net  [get_bd_pins $obj/[gen_mi_arst_name $i]] [get_bd_pins $coupler/M_ARESETN]
    } else {
      connect_bd_net  -net $ict_clk_net [get_bd_pins $coupler/M_ACLK]
      connect_bd_net  -net $ict_rst_net [get_bd_pins $coupler/M_ARESETN]
    }

    set crossbarIdx [format "%.2d" $i]
    connect_bd_intf_net_with_name  $xbar_mi $si
    incr i
  }

  if {$num_si > 1 || $num_mi > 1} {
    connect_bd_net -net $ict_clk_net [get_bd_pins -hier -regexp "\.\*m\.\*_couplers\.\*S_ACLK"]
    connect_bd_net -net $ict_rst_net [get_bd_pins -hier -regexp "\.\*m\.\*_couplers\.\*S_ARESETN"]
  }


  if {$num_si == 1 && $num_mi == 1} {
    connect_bd_intf_net_with_name [get_bd_intf_pins $obj/s00_couplers/M_AXI] [get_bd_intf_pins $obj/[gen_mi_name $i]] 
    connect_bd_net  [get_bd_pins $obj/[gen_mi_aclk_name 0]] [get_bd_pins $coupler/M_ACLK]
    connect_bd_net  [get_bd_pins $obj/[gen_mi_arst_name 0]] [get_bd_pins $coupler/M_ARESETN]    
  }

  if {[llength $crossbar] > 0} {
    set_property CONFIG.STRATEGY [get_property CONFIG.STRATEGY $obj] $crossbar
    if {[get_property CONFIG.ENABLE_ADVANCED_OPTIONS $obj] == 1} {
      if {$num_si >1 || $num_mi > 1} {
        if {[get_property CONFIG.XBAR_DATA_WIDTH.VALUE_SRC $obj] == "USER" && ($num_si > 1 || $num_mi > 1)} {
          set_property CONFIG.DATA_WIDTH [get_property CONFIG.XBAR_DATA_WIDTH $obj] $crossbar
        } else {
          set_property CONFIG.DATA_WIDTH 32 $crossbar
          set_property CONFIG.DATA_WIDTH.VALUE_SRC DEFAULT $crossbar
        }
        if {$num_si > 1} {
          set assignments {}
          for {set i 0} {$i < $num_si} {incr i} {
            lappend assignments CONFIG.S[format %.2d $i]_ARB_PRIORITY [get_property CONFIG.S[format %.2d $i]_ARB_PRIORITY $obj]
          }
          ifx_puts "Passdown ARB PRIORITY: assignments are $assignments"
          if {[llength $assignments] > 0} {
            set_property -dict $assignments $crossbar
          }
        }
        if {[get_property CONFIG.NUM_MI $obj] > 16} {
          set xbars [lsort [get_bd_cells -of_objects $obj -filter {name=~tier2_*}]]
        } else {
          set xbars [list $crossbar]
        }

        ifx_puts "xbars is $xbars"
        set i 0
        foreach xb $xbars {
          set j 0
          for {set j 0} {$j < [get_property CONFIG.NUM_MI $xb]} {incr j} {
            set p "M[format %.2d $i]_SECURE"
            set xp "M[format %.2d $j]_SECURE"
            set v  [get_property CONFIG.$p $obj]
            ifx_puts "Passthrough $xp $v $xb"

            if {[get_property CONFIG.$p.VALUE_SRC $obj] == "USER"} {
              set_property CONFIG.$xp $v $xb
            } else {
              set_property CONFIG.$xp.VALUE_SRC PROPAGATED $xb
            }
            incr i
          }
        }
      }
    } else {
      if {[get_property CONFIG.DATA_WIDTH.VALUE_SRC $crossbar] == "USER"} {        
        set_property CONFIG.DATA_WIDTH 32 $crossbar
        set_property CONFIG.DATA_WIDTH.VALUE_SRC DEFAULT $crossbar
      }
      set assignments {}
      for {set i 0} {$i < $num_si} {incr i} {
        lappend assignments CONFIG.S[format %.2d $i]_ARB_PRIORITY 0 CONFIG.S[format %.2d $i]_ARB_PRIORITY.VALUE_SRC DEFAULT
      }
      set_property -dict $assignments $crossbar
    }
  }

  if {[get_property CONFIG.ENABLE_ADVANCED_OPTIONS $obj] == 1 && [get_property CONFIG.ENABLE_PROTOCOL_CHECKERS $obj] == 1} {
    ifx_puts "----------------------------------------------------------------------"
    ifx_puts "Inserting protocol checkers"

    foreach {role guard} "s $num_si m $num_mi" {
      for {set i 0} {$i < $guard} {incr i} {
        
        set idx $role[format %.2d $i]
        set pc [create_bd_cell -vlnv xilinx.com:ip:axi_protocol_checker:2.0  ${idx}_pchk]
        set_property CONFIG.MAX_RD_BURSTS [get_property CONFIG.PCHK_MAX_RD_BURSTS $obj] $pc
        set_property CONFIG.MAX_WR_BURSTS [get_property CONFIG.PCHK_MAX_WR_BURSTS $obj] $pc
        foreach ch {AW AR R W B} {
          set_property CONFIG.MAX_${ch}_WAITS [get_property CONFIG.PCHK_WAITS $obj] $pc  
        }
        if {$num_mi == 1 && $num_si == 1 && $role == "m"} {
          connect_bd_intf_net [get_bd_intf_pins $pc/PC_AXI] [get_bd_intf_pins $obj/M00_AXI]
          set clk_pin [get_bd_pins $obj/s00_couplers/m_aclk]
          set rst_pin [get_bd_pins $obj/s00_couplers/m_aresetn]
        } else {
          connect_bd_intf_net [get_bd_intf_pins $pc/PC_AXI] [get_bd_intf_pins $obj/${idx}_couplers/[string toupper $role]_AXI]
          set clk_pin [get_bd_pins $obj/${idx}_couplers/${role}_aclk]
          set rst_pin [get_bd_pins $obj/${idx}_couplers/${role}_aresetn]
        }
        
        set pc_net  [get_bd_intf_nets -of_objects [get_bd_intf_pins $pc/PC_AXI]]
        set clk_net [get_bd_nets -of_objects $clk_pin]
        set rst_net [get_bd_nets -of_objects $rst_pin]

        connect_bd_net      [get_bd_pins $pc/aclk]    -net $clk_net
        connect_bd_net      [get_bd_pins $pc/aresetn] -net $rst_net

        set_property HDL_ATTRIBUTE.MARK_DEBUG true $pc_net
        set_property HDL_ATTRIBUTE.MARK_DEBUG true $rst_net
      }
    }
  }

  if {[info exists env(XIL_IFX_ENABLE_PROPERTY_PERSISTENCE)]} {
    pop_user_params $this ifx_user_params
  }

  ifx_debug_proc_footer
}

proc map_regslice {value cell} {
  set ip [get_bd_cells $cell]
  
#  if {$value == 1} {
#    foreach p {REG_AW REG_W REG_B REG_AR REG_R} {
#      set_property CONFIG.$p 8 $ip
#      set_property CONFIG.$p.VALUE_SRC PROPAGATED $ip
#    }
#  }
}

proc map_data_fifo {value cell} {
  set ip [get_bd_cells $cell]
  set remap { 1 {DEPTH 32 DELAY 0} 2 {DEPTH 512 DELAY 1} 3 {DEPTH 512 DELAY 0} }
  foreach {p v} [dict get $remap $value] {
    foreach m {READ_FIFO WRITE_FIFO} {
      if {[get_property CONFIG.${m}_$p $ip] != $v} {
        set_property CONFIG.${m}_$p $v $ip
      }
      set_property CONFIG.${m}_$p.VALUE_SRC PROPAGATED $ip
    }
  }
}

proc gen_coupler_chain {appcore_cell last_intf coupler_chain_spec} {
  foreach coupler_spec $coupler_chain_spec {
    foreach {test_var test_cond set_proc vlnv inst_name aclk_source aresetn_source} $coupler_spec {
      set value [get_property $test_var $appcore_cell]
      if {$test_cond == ""} { 
        set test_cond {$value != 0} 
      } else {
        regsub -all {value} $test_cond {$value} test_cond
        ifx_puts "test_cond is $test_cond" 
      }
      if { [expr $test_cond] } {
        set coupler_ip [create_bd_cell -vlnv ${vlnv} -type ip -name $inst_name]
        ifx_puts "$last_intf"
        ifx_puts "gen_coupler_chain: Adding: $coupler_ip :: [get_bd_intf_pins $coupler_ip/S_AXI]"
        connect_bd_intf_net_with_name $last_intf [get_bd_intf_pins $coupler_ip/S_AXI]
        set last_intf [get_bd_intf_pins $coupler_ip/M_AXI]
        set aclks   [get_bd_pins  $coupler_ip/ACLK    ]
        set aresets [get_bd_pins  $coupler_ip/ARESETN ]
        if {$aclks != "" && $aresets != ""} {
          connect_bd_net [get_bd_pins $aclk_source]    $aclks
          connect_bd_net [get_bd_pins $aresetn_source] $aresets
        }
        if {$set_proc != ""} {
          ifx_puts "executing custom set procedure as: $set_proc $value  $coupler_ip"
          $set_proc $value  $coupler_ip
        }
      }
    }
  }
  return $last_intf
}

proc mark_coupler_resolve_nets { coupler } {
  ifx_debug_proc_header

  variable ifx_resolve_nets

  ifx_puts "----------------------------------------------------------------------"
  ifx_puts "Marking coupler resolve nets: $coupler"

  current_bd_instance $coupler
  
  set couplers [get_bd_cells]
  ifx_puts "Detected these cells inside the coupler: $couplers"
  set cnames {}
  foreach c $couplers {lappend cnames [lindex [split $c /] end]}
  ifx_puts "Detected these cell names inside the coupler: $cnames"

  if {[llength $cnames] < 2} { 
    if {([string match "*dat*"  $cnames ] && [string match {*m[0-9][0-9]_couplers} $coupler ]) ||
        ([string match "*reg*"  $cnames ] && [string match {*s[0-9][0-9]_couplers} $coupler ])} {

      set resolve_net [get_intf_net_inside $coupler/M_AXI]
    } else {
      set resolve_net [get_intf_net_inside $coupler/S_AXI]
    }
  }

  if {[llength $couplers] == 2} {    
    ifx_puts "Two couplers detected: searching for net between the two couplers"
    foreach net [get_bd_intf_nets] {
      regexp ".*\/(.*)$" $net {} l
      if {![string match *coupler* $l]} {
        set resolve_net $net
        break;
      }
    }
  }

  if {$resolve_net == ""} {
    ifx_puts "ERRROR!   blank resolve net!"
  } else {
    set ifx_resolve_nets([current_bd_design]:$resolve_net) {ADDR_WIDTH DATA_WIDTH PROTOCOL FREQ_HZ}
    ifx_puts "----------------------------------------------------------------------"
    ifx_puts "Added resolve net: $resolve_net"
  }

  ifx_debug_proc_footer
}

ifx_debug_trace_setup
