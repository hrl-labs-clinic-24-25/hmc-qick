library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity bram_pvp_dp is
    Generic (
        -- Memory address size.
        N       : Integer := 16;
        -- Data width.
        B       : Integer := 16
    );
    Port ( 
        clk    	: in STD_LOGIC;
        ena     : in STD_LOGIC;
        enb     : in STD_LOGIC;
        wea     : in STD_LOGIC;
        addra   : in STD_LOGIC_VECTOR (8 downto 0); // moves 9 bits along to go 24 bits (read in)
        addrb   : in STD_LOGIC_VECTOR (2 downto 0); // Move 3 bits along to go to 8 bits (read out)
        dia     : in STD_LOGIC_VECTOR (23 downto 0);
        dob     : out STD_LOGIC_VECTOR (7 downto 0)
    );
end bram_simple_dp;

architecture rtl of bram_simple_dp is

-- Ram type.
type ram_type is array (8 downto 0) of std_logic_vector (23 downto 0);
shared variable RAM : ram_type;

begin

process (clk)
begin
    if (clk'event and clk = '1') then
        if (ena = '1') then
            if (wea = '1') then
                RAM(conv_integer(addra)) := dia;
            end if;
        end if;
    end if;
end process;

process (clk)
begin
    if (clk'event and clk = '1') then
        if (enb = '1') then
            dob <= RAM(conv_integer(addrb));
        end if;
    end if;
end process;

end rtl;

