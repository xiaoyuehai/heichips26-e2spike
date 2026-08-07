----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/08/06 21:24:50
-- Design Name: 
-- Module Name: comparator - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity comparator is
    port (
        ca   : in  std_logic_vector(2 downto 0);   -- Width need to be optimized as configurable generic values
        Vmem : in  std_logic_vector(15 downto 0);  -- Width need to be optimized as configurable generic values
        up   : out std_logic;
        down : out std_logic
    );
end entity comparator;

architecture Behavioral of comparator is

    -- The widths need to be optimized as configurable generic values later
    constant THETA1 : unsigned(2 downto 0)  := "001";
    constant THETA2 : unsigned(2 downto 0)  := "011";
    constant THETA3 : unsigned(2 downto 0)  := "110";
    constant THETAM : unsigned(15 downto 0) := "0000000000001001";

begin

    up <= '1' when
            unsigned(ca) >= THETA1 and
            unsigned(ca) <  THETA3 and
            unsigned(Vmem) >= THETAM
          else '0';

    down <= '1' when
              unsigned(ca) >= THETA1 and
              unsigned(ca) <  THETA2 and
              unsigned(Vmem) < THETAM
            else '0';

end Behavioral;
