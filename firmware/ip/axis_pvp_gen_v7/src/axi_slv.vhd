library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_slv is
	Generic 
	(
		DATA_WIDTH	: integer	:= 32;
		ADDR_WIDTH	: integer	:= 7
	);
	Port 
	(
		aclk			: in std_logic;
		aresetn			: in std_logic;

		-- Write Address Channel.
		awaddr			: in std_logic_vector(ADDR_WIDTH-1 downto 0);
		awprot			: in std_logic_vector(2 downto 0);
		awvalid			: in std_logic;
		awready			: out std_logic;

		-- Write Data Channel.
		wdata			: in std_logic_vector(DATA_WIDTH-1 downto 0);
		wstrb			: in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		wvalid			: in std_logic;
		wready			: out std_logic;

		-- Write Response Channel.
		bresp			: out std_logic_vector(1 downto 0);
		bvalid			: out std_logic;
		bready			: in std_logic;

		-- Read Address Channel.
		araddr			: in std_logic_vector(ADDR_WIDTH-1 downto 0);
		arprot			: in std_logic_vector(2 downto 0);
		arvalid			: in std_logic;
		arready			: out std_logic;

		-- Read Data Channel.
		rdata			: out std_logic_vector(DATA_WIDTH-1 downto 0);
		rresp			: out std_logic_vector(1 downto 0);
		rvalid			: out std_logic;
		rready			: in std_logic;

		-- Registers.
		START_VAL_0_REG 	: out std_logic_vector (19 downto 0);
		START_VAL_1_REG 	: out std_logic_vector (19 downto 0);
		START_VAL_2_REG 	: out std_logic_vector (19 downto 0);
		START_VAL_3_REG 	: out std_logic_vector (19 downto 0);

		STEP_SIZE_0_REG 	: out std_logic_vector (19 downto 0);
		STEP_SIZE_1_REG 	: out std_logic_vector (19 downto 0);
		STEP_SIZE_2_REG 	: out std_logic_vector (19 downto 0);
		STEP_SIZE_3_REG 	: out std_logic_vector (19 downto 0);

		DEMUX_0_REG 		: out std_logic_vector (4 downto 0);
		DEMUX_1_REG 		: out std_logic_vector (4 downto 0);
		DEMUX_2_REG 		: out std_logic_vector (4 downto 0);
		DEMUX_3_REG 		: out std_logic_vector (4 downto 0);

		DAC_0_GROUP_REG 		: out std_logic_vector (1 downto 0);
		DAC_1_GROUP_REG 		: out std_logic_vector (1 downto 0);
		DAC_2_GROUP_REG 		: out std_logic_vector (1 downto 0);
		DAC_3_GROUP_REG 		: out std_logic_vector (1 downto 0);

		DAC_0_DIRECTION_REG 	: out std_logic_vector (0 downto 0);
		DAC_1_DIRECTION_REG 	: out std_logic_vector (0 downto 0);
		DAC_2_DIRECTION_REG 	: out std_logic_vector (0 downto 0);
		DAC_3_DIRECTION_REG 	: out std_logic_vector (0 downto 0);

		------------------------------------------------------------
		
		CTRL_REG  				: out std_logic_vector (3 downto 0);
		MODE_REG				: out std_logic_vector (1 downto 0);
		CONFIG_REG     			: out std_logic_vector (28 downto 0);

		------------------------------------------------------------

		DWELL_CYCLES_REG 		: out std_logic_vector (31 downto 0);
		CYCLES_TILL_READOUT_REG : out std_logic_vector (15 downto 0);
		PVP_WIDTH_REG 			: out std_logic_vector (9 downto 0);
		NUM_DIMS_REG 			: out std_logic_vector (2 downto 0);

		-------------------------------------------------------------
		TRIGGER_USER_REG     : out std_logic_vector (0 downto 0);
		QUIT_PVP_REG         : out std_logic_vector (0 downto 0);
		DONE_REG     		 : in  std_logic_vector (0 downto 0)
		

	);
end axi_slv;

architecture rtl of axi_slv is

	-- AXI4LITE signals
	signal axi_awaddr	: std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rdata	: std_logic_vector(DATA_WIDTH-1 downto 0);
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

	-- Example-specific design signals
	-- local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	-- ADDR_LSB is used for addressing 32/64 bit registers/memories
	-- ADDR_LSB = 2 for 32 bits (n downto 2)
	-- ADDR_LSB = 3 for 64 bits (n downto 3)
	constant ADDR_LSB  : integer := (DATA_WIDTH/32)+ 1;
	constant OPT_MEM_ADDR_BITS : integer := 4;
	------------------------------------------------
	---- Signals for user logic register space example
	--------------------------------------------------
	---- Number of Slave Registers 32
	signal slv_reg0		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg1		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg2		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg3		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg4		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg5		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg6		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg7		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg8		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg9		:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg10	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg11	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg12	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg13	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg14	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg15	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg16	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg17	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg18	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg19	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg20	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg21	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg22	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg23	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg24	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg25	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg26	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg27	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg28	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg29	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg30	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg31	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal slv_reg_rden	: std_logic;
	signal slv_reg_wren	: std_logic;
	signal reg_data_out	:std_logic_vector(DATA_WIDTH-1 downto 0);
	signal byte_index	: integer;
	signal aw_en	: std_logic;

begin
	-- I/O Connections assignments

	awreadY	<= axi_awready;
	wready	<= axi_wready;
	bresp	<= axi_bresp;
	bvalid	<= axi_bvalid;
	arreadY	<= axi_arready;
	rdata	<= axi_rdata;
	rresp	<= axi_rresp;
	rvalid	<= axi_rvalid;
	-- Implement axi_awready generation
	-- axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	-- de-asserted when reset is low.

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_awready <= '0';
	      aw_en <= '1';
	    else
	      if (axi_awready = '0' and awvalid = '1' and wvalid = '1' and aw_en = '1') then
	        -- slave is ready to accept write address when
	        -- there is a valid write address and write data
	        -- on the write address and data bus. This design 
	        -- expects no outstanding transactions. 
	           axi_awready <= '1';
	           aw_en <= '0';
	        elsif (bready = '1' and axi_bvalid = '1') then
	           aw_en <= '1';
	           axi_awready <= '0';
	      else
	        axi_awready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- Implement axi_awaddr latching
	-- This process is used to latch the address when both 
	-- S_AXI_AWVALID and S_AXI_WVALID are valid. 

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_awaddr <= (others => '0');
	    else
	      if (axi_awready = '0' and awvalid = '1' and wvalid = '1' and aw_en = '1') then
	        -- Write Address latching
	        axi_awaddr <= awaddr;
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_wready generation
	-- axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	-- S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	-- de-asserted when reset is low. 

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_wready <= '0';
	    else
	      if (axi_wready = '0' and wvalid = '1' and awvalid = '1' and aw_en = '1') then
	          -- slave is ready to accept write data when 
	          -- there is a valid write address and write data
	          -- on the write address and data bus. This design 
	          -- expects no outstanding transactions.           
	          axi_wready <= '1';
	      else
	        axi_wready <= '0';
	      end if;
	    end if;
	  end if;
	end process; 

	-- Implement memory mapped register select and write logic generation
	-- The write data is accepted and written to memory mapped registers when
	-- axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	-- select byte enables of slave registers while writing.
	-- These registers are cleared when reset (active low) is applied.
	-- Slave register write enable is asserted when valid address and data are available
	-- and the slave is ready to accept the write address and write data.
	slv_reg_wren <= axi_wready and wvalid and axi_awready and awvalid ;

	process (aclk)
	variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0); 
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      slv_reg0  <= (others => '0');
	      slv_reg1  <= (others => '0');
	      slv_reg2  <= (others => '0');
	      slv_reg3  <= (others => '0');
	      slv_reg4  <= (others => '0');
	      slv_reg5  <= (others => '0');
	      slv_reg6  <= (others => '0');
	      slv_reg7  <= (others => '0');
	      slv_reg8  <= (others => '0');
	      slv_reg9  <= (others => '0');
	      slv_reg10 <= (others => '0');
	      slv_reg11 <= (others => '0');
	      slv_reg12 <= (others => '0');
	      slv_reg13 <= (others => '0');
	      slv_reg14 <= (others => '0');
	      slv_reg15 <= (others => '0');
	      slv_reg16 <= (others => '0');
	      slv_reg17 <= (others => '0');
	      slv_reg18 <= (others => '0');
	      slv_reg19 <= (others => '0');
	      slv_reg20 <= (others => '0');
	      slv_reg21 <= (others => '0');
	      slv_reg22 <= (others => '0');
	      slv_reg23 <= (others => '0');
	      slv_reg24 <= (others => '0');
	      slv_reg25 <= (others => '0');
	      slv_reg26 <= (others => '0');
	      slv_reg27 <= (others => '0');
	      slv_reg28 <= (others => '0');
	      slv_reg29 <= (others => '0');
	      slv_reg30 <= (others => '0');
	      slv_reg31 <= (others => '0');
	    else
	      loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
	      if (slv_reg_wren = '1') then
	        case loc_addr is
	          when b"00000" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 0
	                slv_reg0(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"00001" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 1
	                slv_reg1(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"00010" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 2
	                slv_reg2(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"00011" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 3
	                slv_reg3(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"00100" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 4
	                slv_reg4(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"00101" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 5
	                slv_reg5(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"00110" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 6
	                slv_reg6(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"00111" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 7
	                slv_reg7(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"01000" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 8
	                slv_reg8(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"01001" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 9
	                slv_reg9(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"01010" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 10
	                slv_reg10(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"01011" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 11
	                slv_reg11(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"01100" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 12
	                slv_reg12(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"01101" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 13
	                slv_reg13(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"01110" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 14
	                slv_reg14(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"01111" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 15
	                slv_reg15(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;

	          when b"10000" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 16
	                slv_reg16(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"10001" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 17
	                slv_reg17(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"10010" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 18
	                slv_reg18(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"10011" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 19
	                slv_reg19(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"10100" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 20
	                slv_reg20(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"10101" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 21
	                slv_reg21(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"10110" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 22
	                slv_reg22(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"10111" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 23
	                slv_reg23(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"11000" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 24
	                slv_reg24(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"11001" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 25
	                slv_reg25(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"11010" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 26
	                slv_reg26(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"11011" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 27
	                slv_reg27(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"11100" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 28
	                slv_reg28(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"11101" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 29
	                slv_reg29(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"11110" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 30
	                slv_reg30(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when b"11111" =>
	            for byte_index in 0 to (DATA_WIDTH/8-1) loop
	              if ( wstrb(byte_index) = '1' ) then
	                -- Respective byte enables are asserted as per write strobes                   
	                -- slave registor 31
	                slv_reg31(byte_index*8+7 downto byte_index*8) <= wdata(byte_index*8+7 downto byte_index*8);
	              end if;
	            end loop;
	          when others =>
	            slv_reg0 <= slv_reg0;
	            slv_reg1 <= slv_reg1;
	            slv_reg2 <= slv_reg2;
	            slv_reg3 <= slv_reg3;
	            slv_reg4 <= slv_reg4;
	            slv_reg5 <= slv_reg5;
	            slv_reg6 <= slv_reg6;
	            slv_reg7 <= slv_reg7;
	            slv_reg8 <= slv_reg8;
	            slv_reg9 <= slv_reg9;
	            slv_reg10 <= slv_reg10;
	            slv_reg11 <= slv_reg11;
	            slv_reg12 <= slv_reg12;
	            slv_reg13 <= slv_reg13;
	            slv_reg14 <= slv_reg14;
	            slv_reg15 <= slv_reg15;
	            slv_reg16 <= slv_reg16;
	            slv_reg17 <= slv_reg17;
	            slv_reg18 <= slv_reg18;
	            slv_reg19 <= slv_reg19;
	            slv_reg20 <= slv_reg20;
	            slv_reg21 <= slv_reg21;
	            slv_reg22 <= slv_reg22;
	            slv_reg23 <= slv_reg23;
	            slv_reg24 <= slv_reg24;
	            slv_reg25 <= slv_reg25;
	            slv_reg26 <= slv_reg26;
	            slv_reg27 <= slv_reg27;
	            slv_reg28 <= slv_reg28;
	            slv_reg29 <= slv_reg29;
	            slv_reg30 <= slv_reg30;
	            slv_reg31 <= slv_reg31;
	        end case;
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement write response logic generation
	-- The write response and response valid signals are asserted by the slave 
	-- when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	-- This marks the acceptance of address and indicates the status of 
	-- write transaction.

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_bvalid  <= '0';
	      axi_bresp   <= "00"; --need to work more on the responses
	    else
	      if (axi_awready = '1' and awvalid = '1' and axi_wready = '1' and wvalid = '1' and axi_bvalid = '0'  ) then
	        axi_bvalid <= '1';
	        axi_bresp  <= "00"; 
	      elsif (bready = '1' and axi_bvalid = '1') then   --check if bready is asserted while bvalid is high)
	        axi_bvalid <= '0';                                 -- (there is a possibility that bready is always asserted high)
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arready generation
	-- axi_arready is asserted for one S_AXI_ACLK clock cycle when
	-- S_AXI_ARVALID is asserted. axi_awready is 
	-- de-asserted when reset (active low) is asserted. 
	-- The read address is also latched when S_AXI_ARVALID is 
	-- asserted. axi_araddr is reset to zero on reset assertion.

	process (aclk)
	begin
	  if rising_edge(aclk) then 
	    if aresetn = '0' then
	      axi_arready <= '0';
	      axi_araddr  <= (others => '1');
	    else
	      if (axi_arready = '0' and arvalid = '1') then
	        -- indicates that the slave has acceped the valid read address
	        axi_arready <= '1';
	        -- Read Address latching 
	        axi_araddr  <= araddr;           
	      else
	        axi_arready <= '0';
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arvalid generation
	-- axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	-- S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	-- data are available on the axi_rdata bus at this instance. The 
	-- assertion of axi_rvalid marks the validity of read data on the 
	-- bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	-- is deasserted on reset (active low). axi_rresp and axi_rdata are 
	-- cleared to zero on reset (active low).  
	process (aclk)
	begin
	  if rising_edge(aclk) then
	    if aresetn = '0' then
	      axi_rvalid <= '0';
	      axi_rresp  <= "00";
	    else
	      if (axi_arready = '1' and arvalid = '1' and axi_rvalid = '0') then
	        -- Valid read data is available at the read data bus
	        axi_rvalid <= '1';
	        axi_rresp  <= "00"; -- 'OKAY' response
	      elsif (axi_rvalid = '1' and rready = '1') then
	        -- Read data is accepted by the master
	        axi_rvalid <= '0';
	      end if;            
	    end if;
	  end if;
	end process;

	-- Implement memory mapped register select and read logic generation
	-- Slave register read enable is asserted when valid address is available
	-- and the slave is ready to accept the read address.
	slv_reg_rden <= axi_arready and arvalid and (not axi_rvalid) ;

	process (slv_reg0, slv_reg1, slv_reg2, slv_reg3, slv_reg4, slv_reg5, slv_reg6, slv_reg7, slv_reg8, slv_reg9, slv_reg10, slv_reg11, slv_reg12, slv_reg13, slv_reg14, slv_reg15, axi_araddr, aresetn, slv_reg_rden)
	variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
	begin
	    -- Address decoding for reading registers
	    loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
	    case loc_addr is
	      when b"00000" =>
	        reg_data_out <= slv_reg0;
	      when b"00001" =>
	        reg_data_out <= slv_reg1;
	      when b"00010" =>
	        reg_data_out <= slv_reg2;
	      when b"00011" =>
	        reg_data_out <= slv_reg3;
	      when b"00100" =>
	        reg_data_out <= slv_reg4;
	      when b"00101" =>
	        reg_data_out <= slv_reg5;
	      when b"00110" =>
	        reg_data_out <= slv_reg6;
	      when b"00111" =>
	        reg_data_out <= slv_reg7;
	      when b"01000" =>
	        reg_data_out <= slv_reg8;
	      when b"01001" =>
	        reg_data_out <= slv_reg9;
	      when b"01010" =>
	        reg_data_out <= slv_reg10;
	      when b"01011" =>
	        reg_data_out <= slv_reg11;
	      when b"01100" =>
	        reg_data_out <= slv_reg12;
	      when b"01101" =>
	        reg_data_out <= slv_reg13;
	      when b"01110" =>
	        reg_data_out <= slv_reg14;
	      when b"01111" =>
	        reg_data_out <= slv_reg15;
	      when b"10000" =>
	        reg_data_out <= slv_reg16;
	      when b"10001" =>
	        reg_data_out <= slv_reg17;
	      when b"10010" =>
	        reg_data_out <= slv_reg18;
	      when b"10011" =>
	        reg_data_out <= slv_reg19;
	      when b"10100" =>
	        reg_data_out <= slv_reg20;
	      when b"10101" =>
	        reg_data_out <= slv_reg21;
	      when b"10110" =>
	        reg_data_out <= slv_reg22;
	      when b"10111" =>
	        reg_data_out <= slv_reg23;
	      when b"11000" =>
	        reg_data_out <= slv_reg24;
	      when b"11001" =>
	        reg_data_out <= slv_reg25;
	      when b"11010" =>
	        reg_data_out <= slv_reg26;
	      when b"11011" =>
	        reg_data_out <= slv_reg27;
	      when b"11100" =>
	        reg_data_out <= slv_reg28;
	      when b"11101" =>
	        reg_data_out <= DONE_REG; --slv_reg29;
	      when b"11110" =>
	        reg_data_out <= slv_reg30;
	      when b"11111" =>
	        reg_data_out <= slv_reg31;
	      when others =>
	        reg_data_out  <= (others => '0');
	    end case;
	end process; 

	-- Output register or memory read data
	process( aclk ) is
	begin
	  if (rising_edge (aclk)) then
	    if ( aresetn = '0' ) then
	      axi_rdata  <= (others => '0');
	    else
	      if (slv_reg_rden = '1') then
	        -- When there is a valid read address (S_AXI_ARVALID) with 
	        -- acceptance of read address by the slave (axi_arready), 
	        -- output the read dada 
	        -- Read address mux
	          axi_rdata <= reg_data_out;     -- register read data
	      end if;   
	    end if;
	  end if;
	end process;


	-- Register Map.
	START_VAL_0_REG <= slv_reg0(19 downto 0);
	START_VAL_1_REG <= slv_reg1(19 downto 0);
	START_VAL_2_REG <= slv_reg2(19 downto 0);
	START_VAL_3_REG <= slv_reg3(19 downto 0);

	STEP_SIZE_0_REG <= slv_reg4(19 downto 0);
	STEP_SIZE_1_REG <= slv_reg5(19 downto 0);
	STEP_SIZE_2_REG <= slv_reg6(19 downto 0);
	STEP_SIZE_3_REG <= slv_reg7(19 downto 0);

	DEMUX_0_REG <= slv_reg8(4 downto 0);
	DEMUX_1_REG <= slv_reg9(4 downto 0);
	DEMUX_2_REG <= slv_reg10(4 downto 0);
	DEMUX_3_REG <= slv_reg11(4 downto 0);

	DAC_0_GROUP_REG <= slv_reg12(1 downto 0);
	DAC_1_GROUP_REG <= slv_reg13(1 downto 0);
	DAC_2_GROUP_REG <= slv_reg14(1 downto 0);
	DAC_3_GROUP_REG <= slv_reg15(1 downto 0);

	DAC_0_DIRECTION_REG <= slv_reg16(0 downto 0);
	DAC_1_DIRECTION_REG <= slv_reg17(0 downto 0);
	DAC_2_DIRECTION_REG <= slv_reg18(0 downto 0);
	DAC_3_DIRECTION_REG <= slv_reg19(0 downto 0);

	------------------------------------------------------------
	
	CTRL_REG <= slv_reg20(3 downto 0);
	MODE_REG <= slv_reg21(1 downto 0);
	CONFIG_REG <= slv_reg22(28 downto 0);

	------------------------------------------------------------

	DWELL_CYCLES_REG <= slv_reg23(31 downto 0);
	CYCLES_TILL_READOUT_REG <= slv_reg24(15 downto 0);
	PVP_WIDTH_REG <= slv_reg25(9 downto 0);
	NUM_DIMS_REG <= slv_reg26(2 downto 0);

	------------------------------------------------------------

	TRIGGER_USER_REG <= slv_reg27(0 downto 0);
	QUIT_PVP_REG <= slv_reg28(0 downto 0);
	-- DONE_REG is also here


end rtl;

