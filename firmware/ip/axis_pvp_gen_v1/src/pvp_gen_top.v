module pvp_gen_top 
	(
		// Reset and clock.
    	aresetn				,
		aclk				,

    	// AXIS Slave to queue waveforms.
		s1_axis_tdata_i		,
		s1_axis_tvalid_i	,
		s1_axis_tready_o	,

		// M_AXIS for output.
		m_axis_tready_o		,
		m_axis_tvalid_o		,

		// MUXING LINES
		select
	);

/**************/
/* Parameters */
/**************/

/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

input 	[23:0]			s1_axis_tdata_i;
input					s1_axis_tvalid_i;
output					s1_axis_tready_o;

input					m_axis_tready_o;
output					m_axis_tvalid_o;
output	[23:0]      	m_axis_tdata_o;

output [4:0]			select;

// input           		WE_REG;

/********************/
/* Internal signals */
/********************/
// iter.
wire					iter_wr_en;


wire	[31:0]			iter_din;

wire					iter_rd_en;
wire					iter_full;
wire					iter_empty;

// output to spi
wire	[23:0]			iter_dout;


// For later implentation: iterator and SPI

/**********************/
/* Begin Architecture */
/**********************/

// Iterator
iter_pvp
    #(
        // Data width.
        .B	(32),
        
        // iter depth.
        .N	(4)
    )
    iter_pvp_i
	( 
        .rstn	(aresetn	),
        .clk 	(aclk		),

        // Write I/F.
        .wr_en 	(iter_wr_en	),
        .din    (iter_din	),  // assign in pvp_fsm (dac1 automatically - we'll add logic when we need to for loop through everything)
        
        // Read I/F.
        .rd_en 	(iter_rd_en), // fed into fsm
        .dout  	(iter_dout	),

		.full   (iter_full_i), // fed into fsm
		.empty  (iter_empty_i) // fed into fsm
    );

assign iter_wr_en	= s1_axis_tvalid_i;
assign m_axis_tdata_o = iter_rd_en ? iter_din[23:0] : 0;
assign select = iter_rd_en ? c_mux : 0;

// custom fsm gen. 
pvp_fsm_gen 
	pvp_fsm_gen_i
	(
		// Reset and clock.
		.rstn				(aresetn			),
		.clk				(aclk				),

    	// AXIS Slave to queue waveforms.
		.data_i	    (s1_axis_tdata 		),
		.tvalid_i	(s1_axis_tvalid		),

		// Iterator interface with FSM
		.iter_wr_en_o	(iter_wr_en			),
		.iter_rd_en_o	(iter_rd_en			),
		.iter_empty_i	(iter_empty			),
		.iter_full_i	(iter_full	     	),

        .iter_din_o   (iter_din),
        .c_mux_o 		(c_mux)
	);


// Assign outputs.
assign s1_axis_tready_o	= iter_full;

endmodule

