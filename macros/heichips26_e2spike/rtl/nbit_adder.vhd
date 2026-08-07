----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/07/24 17:35:39
-- Design Name: 
-- Module Name: nbit_adder - Behavioral
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

entity nbit_adder is
  generic(
    w_WIDTH     : integer := 8
  );
  Port ( 
    a           : in std_logic_vector(w_WIDTH-1 downto 0);
    b           : in std_logic_vector(w_WIDTH-1 downto 0);
    cin         : in std_logic;
    sum         : out std_logic_vector(w_WIDTH-1 downto 0);
    cout        : out std_logic
  );
end nbit_adder;

architecture Behavioral of nbit_adder is

    signal result   : unsigned(w_WIDTH downto 0);
    signal cin_ext  : unsigned(w_WIDTH downto 0);
begin

    cin_ext <= to_unsigned(1, w_WIDTH + 1) when cin = '1' else
               to_unsigned(0, w_WIDTH + 1);

    result <= ('0' & unsigned(a)) +
              ('0' & unsigned(b)) +
              cin_ext;

    sum  <= std_logic_vector(result(w_WIDTH-1 downto 0));
    cout <= result(w_WIDTH);

end Behavioral;
