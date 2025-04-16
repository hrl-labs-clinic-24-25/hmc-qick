library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Updated to work with a stack of 32 values.
-- bRAM has the potential to be implemented into pvp_fsm in the future, where it can replace no_mem_sweep.
-- In order to do this, the user must make sure there's enough address memory to hold the values being loaded.

entity iter_pvp is
    Generic
    (
        -- Data width.
        B : Integer := 32;
        
        -- Iterator depth.
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
        top    : out std_logic;        
        base   : out std_logic;
        full   : out std_logic
    );
end iter_pvp;

architecture rtl of iter_pvp is

-- Number of bits of depth.
constant N_LOG2 : Integer := Integer(ceil(log2(real(N))));

-- Dual port, single clock  BRAM.
component bram_pvp is
    Generic (
        -- Memory address size.
        N       : Integer := 8;
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
signal wptr   	: unsigned (N_LOG2-1 downto 0);
signal rptr   	: unsigned (N_LOG2-1 downto 0);

-- Memory signals.
signal mem_wea	: std_logic;
signal mem_dob	: std_logic_vector (B-1 downto 0);

-- Flags.
signal top_i   : std_logic; -- when rptr is at the top of the list
signal base_i  : std_logic; -- when rptr is at the base of the list

signal full_i   : std_logic; -- internal logic for when iterator is full

begin

-- Iterator memory.
mem_i : bram_pvp
    Generic map (
        -- Memory address size.
        N       => N_LOG2,
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
mem_wea <= 	wr_en when (wptr <= N) else
			'0';

-- Full (i.e. you can write to bram right now)
full_i  <= '1' when (wptr = N-1) else 
            '0';

-- Top/base signals.
top_i <= '1' when (rptr = (N + 1)) else
            '0';  -- when rptr is at the top 

base_i <= '1' when (rptr = 0) else
            '0';  -- when rptr is at the base

-- wr_clk registers.
process (clk)
begin
    if ( rising_edge(clk) ) then
        if ( rstn = '0' ) then
            wptr <= (others => '0');
            rptr    <= (others => '0');
        else
            -- Write.
            if ( wr_en = '1' and full_i = '0' ) then
                -- Write data.
                
                -- Increment pointer.
                wptr <= wptr + 1;
            else
                wptr <= wptr;
            end if;

            -- Read.
            if ( rd_en = '1' ) then
                -- Read data.
                
                -- Increment pointer.
                if (top_i = '1') then
                    rptr <= (others => '0');
                else 
                    rptr <= rptr + 1;
                end if;
            end if;
        end if;
    end if;
end process;

-- Assign outputs.
dout   	<= mem_dob;
full    <= full_i;

top    <= top_i;
base   <= base_i;

end rtl;

