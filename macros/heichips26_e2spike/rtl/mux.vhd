----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/07/24 17:55:03
-- Design Name: 
-- Module Name: mux - Behavioral
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

entity mux is
  generic(
    w_WIDTH     : integer := 8
  );
  Port ( 
    a       : in std_logic_vector(w_WIDTH-1 downto 0);
    b       : in std_logic_vector(w_WIDTH-1 downto 0);
    sel     : in std_logic;
    o       : out std_logic_vector(w_WIDTH-1 downto 0)
  );
end mux;

architecture Behavioral of mux is

begin
    o <= a when sel = '0' else b;

end Behavioral;
