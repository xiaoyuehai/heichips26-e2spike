----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/07/24 17:35:39
-- Design Name: 
-- Module Name: delta_w_generator - Behavioral
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

entity delta_w_generator is
  generic(
    w_WIDTH     : integer := 8
  );
  Port ( 
    up          : in std_logic;
    down        : in std_logic;
    spk_pre     : in std_logic;
    bist        : in std_logic;
    w_msb       : in std_logic;
    delta_w     : out std_logic_vector(w_WIDTH-1 downto 0);
    cin         : out std_logic
  );
end delta_w_generator;

architecture Behavioral of delta_w_generator is

begin

    process(spk_pre, bist, w_msb, up, down)
    begin
        delta_w <= (others => '0');
        cin     <= '0';
    
        if spk_pre = '1' then
            if up = '1' then
                cin <= '1';
            elsif down = '1' then
                delta_w <= (others => '1');
            end if;
    
        elsif bist = '1' then
            if w_msb = '1' then
                cin <= '1';
            elsif w_msb = '0' then
                delta_w <= (others => '1');
            end if;
        end if;
    end process;

end Behavioral;
