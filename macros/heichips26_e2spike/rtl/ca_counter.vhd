----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/08/06 17:41:06
-- Design Name: 
-- Module Name: ca_counter - Behavioral
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

entity ca_counter is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        spk_post   : in  std_logic;
        leak_event : in  std_logic;
        ca         : out std_logic_vector(2 downto 0) -- Width need to be optimized as configurable generic values
    );
end entity ca_counter;

architecture behavioral of ca_counter is

    signal ca_reg    : unsigned(2 downto 0);
    signal event_sel : std_logic_vector(1 downto 0);

    constant CA_MIN : unsigned(2 downto 0) := "000";
    constant CA_MAX : unsigned(2 downto 0) := "111";

begin

    event_sel <= spk_post & leak_event;

    process(clk, rst)
    begin
        if rst = '1' then
            ca_reg <= CA_MIN;

        elsif rising_edge(clk) then

            case event_sel is

                when "10" =>
                    if ca_reg < CA_MAX then
                        ca_reg <= ca_reg + 1;
                    end if;

                when "01" =>
                    if ca_reg > CA_MIN then
                        ca_reg <= ca_reg - 1;
                    end if;

                when others =>
                    null;

            end case;

        end if;
    end process;

    ca <= std_logic_vector(ca_reg);

end architecture behavioral;
