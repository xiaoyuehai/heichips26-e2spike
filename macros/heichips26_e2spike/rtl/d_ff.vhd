----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/07/26 22:41:05
-- Design Name: 
-- Module Name: d_ff - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity d_ff is
  generic(
    w_WIDTH     : integer := 8
  );
  Port (
    clk         : in std_logic;
    rst         : in std_logic;
    d           : in std_logic_vector(w_WIDTH-1 downto 0);
    q           : out std_logic_vector(w_WIDTH-1 downto 0)
  );
end d_ff;

architecture Behavioral of d_ff is

begin
    process(clk, rst)
    begin
        if rst = '1' then
            q <= (others => '0');
        elsif rising_edge(clk) then
            q <= d;
        end if;
    end process;

end Behavioral;
