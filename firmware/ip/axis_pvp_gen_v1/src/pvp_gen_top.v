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
		m_axis_tready_i		,
		m_axis_tvalid_o		,
		m_axis_tdata_o
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

input					m_axis_tready_i;
output					m_axis_tvalid_o;
output	[23:0]      	m_axis_tdata_o;

input           		WE_REG;

/********************/
/* Internal signals */
/********************/
// iter.
wire					iter_wr_en;


wire	[23:0]			iter_din_1;

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
        .N	(256)
    )
    iter_pvp_i
	( 
        .rstn	(aresetn	),
        .clk 	(aclk		),

        // Write I/F.
        .wr_en 	(iter_wr_en	),
        .din    (iter_din	),  // assign in pvp_fsm (dac1 automatically - we'll add logic when we need to for loop through everything)
        
        // Read I/F.
        .rd_en 	(iter_rd_en_o), // fed into fsm
        .dout  	(iter_dout	),

		.full   (iter_full_i), // fed into fsm
		.empty  (iter_empty_i) // fed into fsm
    );

assign iter_wr_en	= s1_axis_tvalid_i;

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

        .iter_din_1_o   (iter_din_1),
        .iter_din_2_o   (iter_din_2),
        .iter_din_3_o   (iter_din_3),
        .iter_din_4_o   (iter_din_4),

        .c_mux_1_o   (c_mux_1),
        .c_mux_2_o   (c_mux_2),
        .c_mux_3_o   (c_mux_3),
        .c_mux_4_o   (c_mux_4)
	);


// Assign outputs.
assign s1_axis_tready_o	= ~iter_full;

endmodule

