module signal_gen_top 
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
		m_axis_tdata_o		,

		// Registers.
		START_ADDR_REG		,
		WE_REG
	);

/**************/
/* Parameters */
/**************/

/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

input 	[49:0]			s1_axis_tdata_i;
input					s1_axis_tvalid_i;
output					s1_axis_tready_o;

input					m_axis_tready_i;
output					m_axis_tvalid_o;
output	[N_DDS*16-1:0]	m_axis_tdata_o;

input   [31:0]  		START_ADDR_REG;
input           		WE_REG;

/********************/
/* Internal signals */
/********************/
// Fifo.
wire					fifo_wr_en;
wire	[23:0]			fifo_din;
wire					fifo_rd_en;
wire					fifo_full;
wire					fifo_empty;

wire					iter_rd_en;
wire					iter_empty_i;
wire	[23:0]			iter_din;

// output to spi
wire	[7:0]			fifo_dout;
wire	[7:0]			iter_dout_o;


// For later implentation: iterator and SPI

/**********************/
/* Begin Architecture */
/**********************/

// Fifo (normal).
fifo
    #(
        // Data width.
        .B	(24),
        
        // Fifo depth.
        .N	(256)
    )
    fifo_i
	( 
        .rstn	(aresetn	),
        .clk 	(aclk		),

        // Write I/F.
        .wr_en 	(fifo_wr_en	),
        .din    (fifo_din	),
        
        // Read I/F.
        .rd_en 	(fifo_rd_en	),
        .dout  	(fifo_dout	),
        
        // Flags.
        .full   (fifo_full	),
        .empty  (fifo_empty	)
    );

// Iterator
iterator
iter
    #(
        // Data width.
        .B	(24),
        
        // Fifo depth.
        .N	(256)
    )
    iter_i
	( 
        .rstn	(aresetn	),
        .clk 	(aclk		),

        // Write I/F.
        .wr_en 	(fifo_wr_en	),
        .din    (fifo_din	),
        
        // Read I/F.
        .rd_en 	(fifo_rd_en	),
        .dout  	(fifo_dout	),
        
        // Flags.
        .start   (iter_start	)
    );

assign fifo_wr_en	= s1_axis_tvalid_i;
assign fifo_din		= s1_axis_tdata_i;

// custom fsm gen. 
pvp_fsm_gen 
	#(
		.N		(N		),
		.N_DDS	(N_DDS	)
	)
	pvp_fsm_gen_i
	(
		// Reset and clock.
		.rstn				(aresetn			),
		.clk				(aclk				),

		
    	// AXIS Slave to queue waveforms.
		.s1_axis_tdata_i	(s1_axis_tdata 		),
		.s1_axis_tvalid_i	(s1_axis_tvalid		),
		.s1_axis_tready_o	(s1_axis_tready		),

		// Fifo interface with FSM
		.fifo_rd_en_o		(fifo_rd_en			),
		.fifo_empty_i		(fifo_empty			),
		.fifo_din_o 		(fifo_din			),

		// Iterator interface with FSM
		.iter_rd_en_o		(iter_rd_en			),
		.iter_empty_i		(iter_empty			),
		.iter_din_o 		(iter_din			),

		// FOR LATER IMPLEMENTATION: FIFO_DOUT -> SPI_DIN
	);


// Assign outputs.
assign s1_axis_tready_o	= ~fifo_full;

endmodule

