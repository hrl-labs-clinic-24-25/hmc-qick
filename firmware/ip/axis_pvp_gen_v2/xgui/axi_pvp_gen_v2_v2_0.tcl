# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"


}

proc update_PARAM_VALUE.DWELL_CYCLES { PARAM_VALUE.DWELL_CYCLES } {
	# Procedure called to update DWELL_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DWELL_CYCLES { PARAM_VALUE.DWELL_CYCLES } {
	# Procedure called to validate DWELL_CYCLES
	return true
}

proc update_PARAM_VALUE.NUM_CYCLES { PARAM_VALUE.NUM_CYCLES } {
	# Procedure called to update NUM_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.NUM_CYCLES { PARAM_VALUE.NUM_CYCLES } {
	# Procedure called to validate NUM_CYCLES
	return true
}


proc update_MODELPARAM_VALUE.NUM_CYCLES { MODELPARAM_VALUE.NUM_CYCLES PARAM_VALUE.NUM_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.NUM_CYCLES}] ${MODELPARAM_VALUE.NUM_CYCLES}
}

proc update_MODELPARAM_VALUE.DWELL_CYCLES { MODELPARAM_VALUE.DWELL_CYCLES PARAM_VALUE.DWELL_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DWELL_CYCLES}] ${MODELPARAM_VALUE.DWELL_CYCLES}
}

