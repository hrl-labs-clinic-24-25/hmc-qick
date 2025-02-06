library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity iter_axi is
    Generic
    (
        -- Data width.
        B : Integer := 16;
        
        -- iter depth.
        N : Integer := 4
    );
    Port
    ( 
        rstn	: in std_logic;
        clk 	: in std_logic;

        -- Write I/F.
        wr_en  	: in std_logic;
        din     : in std_logic_vector (B-1 downto 0);
        
        -- Read I/F.
        rd_en  	: in std_logic;
        dout   	: out std_logic_vector (B-1 downto 0);
        
        -- Flags.
        full    : out std_logic;        
        empty   : out std_logic
    );
end iter_axi;

architecture rtl of iter_axi is

-- iter.
component iter is
    Generic
    (
        -- Data width.
        B : Integer := 16;
        
        -- iter depth.
        N : Integer := 4
    );
    Port
    ( 
        rstn	: in std_logic;
        clk 	: in std_logic;

        -- Write I/F.
        wr_en  	: in std_logic;
        din     : in std_logic_vector (B-1 downto 0);
        
        -- Read I/F.
        rd_en  	: in std_logic;
        dout   	: out std_logic_vector (B-1 downto 0);
        
        -- Flags.
        full    : out std_logic;        
        empty   : out std_logic
    );
end component;

-- iter read to AXI adapter.
component rd2axi is
    Generic
    (
        -- Data width.
        B : Integer := 16
    );
    Port
    ( 
        rstn		: in std_logic;
        clk 		: in std_logic;

        -- iter Read I/F.
        iter_rd_en 	: out std_logic;
        iter_dout  	: in std_logic_vector (B-1 downto 0);
        iter_empty  : in std_logic;
        
        -- Read I/F.
        rd_en 		: in std_logic;
        dout  		: out std_logic_vector (B-1 downto 0);
        empty  		: out std_logic
    );
end component;

signal rd_en_i  : std_logic;
signal dout_i   : std_logic_vector (B-1 downto 0);     
signal empty_i  : std_logic;

begin

-- iter.
iter_pvp_i : iter
    Generic map
    (
        -- Data width.
        B => B,
        
        -- iter depth.
        N => N
    )
    Port map
    ( 
        rstn	=> rstn		,
        clk 	=> clk 		,

        -- Write I/F.
        wr_en  	=> wr_en  	,
        din     => din     	,
        
        -- Read I/F.
        rd_en  	=> rd_en_i	,
        dout   	=> dout_i	,
        
        -- Flags.
        full    => full		,
        empty   => empty_i
    );

-- iter read to AXI adapter.
rd2axi_i : rd2axi
    Generic map
    (
        -- Data width.
        B => B
    )
    Port map
    ( 
        rstn		=> rstn		,
        clk 		=> clk		,

        -- iter Read I/F.
        iter_rd_en 	=> rd_en_i	,
        iter_dout  	=> dout_i	,
        iter_empty  => empty_i	,
        
        -- Read I/F.
        rd_en 		=> rd_en	,
        dout  		=> dout		,
        empty  		=> empty	
    );

end rtl;

