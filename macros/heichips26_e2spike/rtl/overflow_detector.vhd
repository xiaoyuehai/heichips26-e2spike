----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/07/24 17:35:39
-- Design Name: 
-- Module Name: overflow_detector - Behavioral
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

entity overflow_detector is
  Port ( 
    a       : in std_logic;
    cin     : in std_logic;
    carry   : in std_logic;
    y       : out std_logic
  );
end overflow_detector;

architecture Behavioral of overflow_detector is

begin

    y <= (cin and (not a) and carry) or ((not cin) and a and (not carry));

end Behavioral;
