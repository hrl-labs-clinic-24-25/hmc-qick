library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

entity iter is
    Generic
    (
        -- Data width.
        B : Integer := 32;
        
        -- iter depth.
        N : Integer := 32
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
end iter;

architecture rtl of iter is

-- Number of bits of depth.
constant THREE_N_SPI : Integer := Integer(32);
constant READ_THROUGH_SPI : Integer := Integer(4);

-- Dual port, single clock  BRAM.
component bram_simple_dp is
    Generic (
        -- Memory address size.
        N       : Integer := 32;
        -- Data width.
        B       : Integer := 32
    );
    Port ( 
        clk    	: in STD_LOGIC;
        ena     : in STD_LOGIC;
        enb     : in STD_LOGIC;
        wea     : in STD_LOGIC;
        addra   : in STD_LOGIC_VECTOR (N-1 downto 0);
        addrb   : in STD_LOGIC_VECTOR (N-1 downto 0);
        dia     : in STD_LOGIC_VECTOR (B-1 downto 0);
        dob     : out STD_LOGIC_VECTOR (B-1 downto 0)
    );
end component;

-- Pointers.
signal wptr   	: unsigned (4-1 downto 0); --write pointer
signal rptr   	: unsigned (READ_THROUGH_SPI-1 downto 0); --read pointer
signal rptr_initial: unsigned (READ_THROUGH_SPI-1 downto 0); --initial pointer position

-- Memory signals.
signal mem_wea	: std_logic;
signal mem_dob	: std_logic_vector (B-1 downto 0);

-- Flags.
signal full_i   : std_logic;
signal empty_i  : std_logic;

begin

-- iter memory.
mem_i : bram_simple_dp
    Generic map (
        -- Memory address size. DOUBLE CHECK SIZING -- make sure that if its 1/3 of the initial, it can still be used
        N       => READ_THROUGH_SPI,
        -- Data width.
        B       => B
    )
    Port map ( 
        clk    	=> clk						,
        ena     => '1'						,
        enb     => rd_en					,
        wea     => mem_wea					,
        addra   => std_logic_vector(wptr)	,
        addrb   => std_logic_vector(rptr)	,
        dia     => din						,
        dob     => mem_dob
    );

-- Memory connections.
mem_wea <= 	wr_en when full_i = '0' else
			'0';

-- Full/empty signals.
full_i 	<=  '1' when wptr = 4 else 
            '0';           
empty_i	<= 	'1' when wptr = 0 else
			'0';

-- wr_clk registers.
process (clk)
begin
    if ( rising_edge(clk) ) then
        if ( rstn = '0' ) then
            wptr <= (others => '0');
            rptr    <= (others => '0');
            rptr_initial <= (others => '0');
        else
            -- Write.
            if ( wr_en = '1' and full_i = '0' ) then
                -- Write data.
                
                -- Increment pointer.
                wptr <= wptr + 1;
            end if;

            -- Read.
            if ( rd_en = '1' and empty_i = '0' ) then
                -- Read data.
                
                if rptr = N-1 then
                    rptr <= rptr_initial; -- Reset rptr
                else
                    rptr <= rptr + 1; -- Increment pointer.
                end if;
            end if;
        end if;
    end if;
end process;

-- Assign outputs.
dout   	<= mem_dob;
full    <= full_i;
empty   <= empty_i;

end rtl;

