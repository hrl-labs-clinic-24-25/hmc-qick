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

source_subcore_ipfile xilinx.com:ip:ifx_util:1.1 bd/ifx_common_debug_util.tcl
source_subcore_ipfile xilinx.com:ip:ifx_util:1.1 xgui/ifx_common_xgui_util.tcl
source_subcore_ipfile xilinx.com:ip:axi_infrastructure:1.1 xgui/axi_common_xgui.tcl

proc create_gui { ipview } {
  ipgui::add_param $ipview -parent $ipview -name Component_Name

  set_property show_ipsymbol false [ipgui::get_canvasspec -of $ipview]
	set Page0     [ipgui::add_page $ipview  -name "Top Level Settings" -layout vertical]
	set NUM_SI    [ipgui::add_param $ipview -parent $Page0 -name NUM_SI -widget comboBox ]
	set NUM_MI    [ipgui::add_param $ipview -parent $Page0 -name NUM_MI -widget comboBox ]	
	set STRATEGY  [ipgui::add_param $ipview -parent $Page0 -name STRATEGY -widget comboBox ]
  ipgui::add_static_text $ipview -parent $Page0 -name ICT_STATIC_TEXT -text "<br><br>AXI Interconnect includes IP Integrator automatic converter insertion and configuration.<blockquote>When the endpoint IPs attached to the interfaces of the AXI Interconnect differ<br>in width, clock or protocol, a converter IP will automatically be added inside the interconnect.<br>If a converter IP is inserted, IP integrator's parameter propagation automatically<br>configures the converter to match the design.<br>To see which conversion IPs have been inserted, use the IP integrator <br>'expand hierarchy' buttons to explore inside the AXI Interconnect hierarchy. </blockquote><br>NOTE:Addressing information for AXI Interconnect is specified in the IP Integrator address editor." 
  
	set SI_CONFIG [ ipgui::add_page $ipview  -name "Slave Interfaces"  -layout vertical]
  set widget_order { "Enable Register Slice" HAS_REGSLICE comboBox "Enable Data FIFO" HAS_DATA_FIFO comboBox }
  gen_param_table $ipview $SI_CONFIG SI_TABLE slave_settings_table_ 17 3 "Slave Interface" {S[format %.2d $i]_AXI} {S[format %.2d $i]} $widget_order

	set MI_CONFIG [ ipgui::add_page $ipview  -name "Master Interfaces" -layout vertical]
  set widget_order { "Enable Register Slice" HAS_REGSLICE comboBox "Enable Data FIFO" HAS_DATA_FIFO comboBox }
  gen_param_table $ipview $MI_CONFIG MI_TABLE master_settings_table_ 65 3 "Master Interface" {M[format %.2d $i]_AXI} {M[format %.2d $i]} $widget_order

  set ADVANCED_OPTIONS [ ipgui::add_page $ipview  -name "Advanced Options" -layout vertical]
  set ENABLE_ADVANCED_OPTIONS  [ipgui::add_param $ipview -parent $Page0 -name ENABLE_ADVANCED_OPTIONS -widget checkBox ]

  set mtbf_group [ipgui::add_group $ipview -name "Clock Domain Crossing MTBF Options" -parent $ADVANCED_OPTIONS]
  set SYNCHRONIZATION_STAGES  [ipgui::add_param $ipview -parent $mtbf_group -name SYNCHRONIZATION_STAGES -widget comboBox ]	  

  set xbar_group [ipgui::add_group $ipview -name "Interconnect Crossbar Options" -parent $ADVANCED_OPTIONS]
  set XBAR_DATA_WIDTH  [ipgui::add_param $ipview -parent $xbar_group -name XBAR_DATA_WIDTH -widget comboBox ]	  

  set debug_group [ipgui::add_group $ipview -name "Interconnect Debug Options" -parent $ADVANCED_OPTIONS]  

  set pchk_options {
    ENABLE_PROTOCOL_CHECKERS checkBox {Enable Protocol Checkers and Mark Interfaces for Debug}
    PCHK_WAITS               textEdit  {Specify the number of wait cycles for READY/VALID checking}
    PCHK_MAX_RD_BURSTS       comboBox  {Specify the maximum number of read transactions expected on any interface}
    PCHK_MAX_WR_BURSTS       comboBox  {Specify the maximum number of write transactions expected on any interface}
  }
  add_widgets $ipview $debug_group $pchk_options

  set mi_group [ipgui::add_group $ipview -name "Master Interface Options" -parent $ADVANCED_OPTIONS]
  set widget_order { "Secure Slave" SECURE checkBox}
  gen_param_table $ipview $mi_group ADVANCED_MI_OPTIONS advanced_master_settings_table_ 65 2 "Master Interface" {M[format %.2d $i]_AXI} {M[format %.2d $i]} $widget_order

  set si_group [ipgui::add_group $ipview -name "Slave Interface Options" -parent $ADVANCED_OPTIONS]
  set widget_order { "Arbitration Priority" ARB_PRIORITY comboBox}
  gen_param_table $ipview $si_group ADVANCED_SI_OPTIONS advanced_si_settings_table_ 17 2 "Slave Interface" {S[format %.2d $i]_AXI} {S[format %.2d $i]} $widget_order

  set_property visible false $ADVANCED_OPTIONS
}

proc ENABLE_ADVANCED_OPTIONS_updated { ipview } {
  if {[get_param_value ENABLE_ADVANCED_OPTIONS] == 1} {
    set v true
  } else {
    set v false
  }    

  set_property visible $v [ipgui::get_pagespec "Advanced Options" -of $ipview]
#  set_property visible $v [ipgui::get_groupspec "Master Interface Options" -of $ipview]
#  set_property visible $v [ipgui::get_groupspec "Interconnect Debug Options" -of $ipview]
#  if {[get_param_value NUM_MI] > 1 || [get_param_value NUM_SI] > 1} {
#    set_property visible $v [ipgui::get_groupspec "Interconnect Crossbar Options" -of $ipview]
#  }
}

proc ENABLE_PROTOCOL_CHECKERS_updated { ipview } {
  if {[get_param_value ENABLE_PROTOCOL_CHECKERS] == 1} {
    set v true
  } else {
    set v false
  }    

  foreach p {PCHK_WAITS PCHK_MAX_RD_BURSTS PCHK_MAX_WR_BURSTS} {
    set_property enabled $v [ipgui::get_paramspec -name $p -of $ipview]
  }

}

proc STRATEGY_updated { ipview } {
  set s [get_param_value STRATEGY]

  if {$s == 0 || $s == 1} {
    for {set i 0} {$i < [get_param_value NUM_SI]} {incr i} {
      set_property enabled true [ipgui::get_paramspec -name S[format %.2d $i]_HAS_DATA_FIFO -of $ipview]
    }
  }
  
  if {$s == 2} {
    for {set i 0} {$i < [get_param_value NUM_SI]} {incr i} {
      set_property value 2 [ipgui::get_paramspec -name S[format %.2d $i]_HAS_DATA_FIFO -of $ipview]
      set_property enabled false [ipgui::get_paramspec -name S[format %.2d $i]_HAS_DATA_FIFO -of $ipview]
    }
  }
}


proc update_mi_config_visibility {NUM_SI NUM_MI ipview} {
  set mi_config_tab [ipgui::get_pagespec "Master Interfaces" -of $ipview]
  if {[get_param_value NUM_SI] == 1 && [get_param_value NUM_MI] == 1} {
    set_property visible false $mi_config_tab
  } else {
    set_property visible true $mi_config_tab
  }
}

proc update_strategy_enablement { ipview } {
  if {[expr [get_param_value NUM_SI] + [get_param_value NUM_MI]]  > 2} {
    set_property enabled true [ipgui::get_paramspec -name STRATEGY -of $ipview]
  } else {
    set_property value 0 [ipgui::get_paramspec -name STRATEGY -of $ipview]
    set_property enabled false [ipgui::get_paramspec -name STRATEGY -of $ipview]
  }
  STRATEGY_updated $ipview
}

proc NUM_SI_updated {ipview} {
  set NUM_SI [get_param_value NUM_SI]
  set NUM_MI [get_param_value NUM_MI]

  set hidden_rows ""
  for {set i [expr $NUM_SI+1]} {$i < 17 } {incr i } {
    set hidden_rows [join [lappend hidden_rows $i] ,]
  }

  if {$NUM_SI == 1} {
    set_property range 1,64 [ipgui::get_paramspec -name NUM_MI -of $ipview]
    set_property visible false [ipgui::get_groupspec "Slave Interface Options"	-of	$ipview ]
  } else {
    set_property range 1,16 [ipgui::get_paramspec -name NUM_MI -of $ipview]
    set_property visible true [ipgui::get_groupspec "Slave Interface Options"	-of	$ipview ]
    set_property hidden_rows "$hidden_rows" [ipgui::get_tablespec "ADVANCED_SI_OPTIONS"	-of	$ipview ]
  }

  set_property hidden_rows "$hidden_rows" [ipgui::get_tablespec "SI_TABLE"	-of	$ipview ]
  update_mi_config_visibility $NUM_SI $NUM_MI $ipview
  update_strategy_enablement $ipview
}

proc NUM_MI_updated {ipview} {
  set NUM_SI [get_param_value NUM_SI]
  set NUM_MI [get_param_value NUM_MI]
  set hidden_rows ""
  for {set i [expr $NUM_MI+1]} {$i < 65 } {incr i } {
    set hidden_rows [join [lappend hidden_rows $i] ,]
  }

  set_property hidden_rows "$hidden_rows" [ipgui::get_tablespec "MI_TABLE"	-of	$ipview ]
  set_property hidden_rows "$hidden_rows" [ipgui::get_tablespec "ADVANCED_MI_OPTIONS"	-of	$ipview ]
  update_mi_config_visibility $NUM_SI $NUM_MI $ipview
  update_strategy_enablement $ipview
}

ifx_debug_trace_setup
