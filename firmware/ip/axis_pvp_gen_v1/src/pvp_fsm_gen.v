module pvp_fsm_gen (
	// Reset and clock.
	rstn			,
	clk				,

	// AXIS Slave to queue waveforms.
	s1_axis_tdata 		,
	s1_axis_tvalid		,
	s1_axis_tready		,

	// Fifo interface.
	fifo_rd_en_o	,
	fifo_empty_i	,
	fifo_din_o		,

	// Iterator Interface.
	iter_rd_en	,
	iter_full_i		,
	iter_din_o	,

	);

/**************/
/* Parameters */
/**************/

/*********/
/* Ports */
/*********/
input						rstn;
input						clk;

input 	[49:0]			s1_axis_tdata_i;
input					s1_axis_tvalid_i;
output					s1_axis_tready_o;

output						fifo_rd_en_o;
input						fifo_empty_i;
output		[23:0]			fifo_din_o;

output						iter_rd_en_o;
input						iter_empty_i;
output		[23:0]			iter_din_o;

input						m_axis_tready_i;
output						m_axis_tvalid_o;
output		[N_DDS*16-1:0]	m_axis_tdata_o;

/********************/
/* Internal signals */
/********************/

// Muxed output.
wire		[15:0]			dout_mux			[0:N_DDS-1];
wire		[15:0]			dout_mux_la			[0:N_DDS-1];

// Output source selection.
wire		[1:0]			src_int;
wire		[1:0]			src_la;

// Output enable.
wire						en_int;
wire						en_la;
reg							en_la_r;

/**********************/
/* Begin Architecture */
/**********************/
// Control block.
ctrl 
	#(
		.N		(N		),
		.N_DDS	(N_DDS	)
	)
	ctrl_i
	(
		// Reset and clock.
		.rstn			(rstn			),
		.clk			(clk			),

		// Fifo interface.
		.fifo_rd_en_o	(fifo_rd_en_o	),
		.fifo_empty_i	(fifo_empty_i	),
		.fifo_dout_i	(fifo_dout_i	),

		// dds control.
		.dds_ctrl_o		(dds_ctrl_int	),

		// memory control.
		.mem_addr_o		(mem_addr_int	),

		// gain.
		.gain_o			(gain_int		),

		// Output source selection.
		.src_o			(src_int		),
		
		// Steady value selection.
		.stdy_o			(stdy_int		),

		// Output enable.
		.en_o			(en_int			)
		);



generate
genvar i;
	for (i=0; i<N_DDS; i=i+1) begin : GEN_dds
		/***********************/
		/* Block instantiation */
		/***********************/
		

		/*************/
		/* Registers */
		/*************/
		

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
		
		/***********/
		/* Outputs */
		/***********/
		
	end
endgenerate 


// Outputs.
assign mem_addr_o			= mem_addr_int_r;
assign m_axis_tvalid_o 		= en_la_r;

endmodule

