----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/08/07 09:51:22
-- Design Name: 
-- Module Name: learning_top - Structural
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

entity learning_top is
    generic(
        w_WIDTH     : integer := 3
    );
    port(
        clk         : in std_logic;
        rst         : in std_logic;
        learn_en    : in std_logic;
        Vmem        : in std_logic_vector(15 downto 0);
        spk_post    : in std_logic;
        spk_pre     : in std_logic;
        w           : in std_logic_vector(w_WIDTH-1 downto 0);
        w_next      : out std_logic_vector(w_WIDTH-1 downto 0)
    );
end learning_top;

architecture Structural of learning_top is

    component ca_counter is
        port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            spk_post    : in  std_logic;
            leak_event  : in  std_logic;
            ca          : out std_logic_vector(2 downto 0)
        );  
    end component;
    
    component comparator is
        port (
            ca          : in  std_logic_vector(2 downto 0);
            Vmem        : in  std_logic_vector(15 downto 0);
            up          : out std_logic;
            down        : out std_logic
        );
    end component;
    
    component sdsp_top is
        generic (
            w_WIDTH     : integer := 8
        );
        Port ( 
            -- Input ports
            up          : in std_logic;
            down        : in std_logic;
            spk_pre     : in std_logic;
            bist        : in std_logic;
            w           : in std_logic_vector(w_WIDTH-1 downto 0);
            -- Output ports
            w_next      : out std_logic_vector(w_WIDTH-1 downto 0);
            -- Clk and rst
            clk         : in std_logic;
            rst         : in std_logic
        );
    end component;
    
    signal ca           : std_logic_vector(2 downto 0);
    signal up           : std_logic;
    signal down         : std_logic;
    signal w_new        : std_logic_vector(w_WIDTH-1 downto 0);

begin

    inst_ca_counter : ca_counter
        port map (
            clk         => clk,
            rst         => rst,
            spk_post    => spk_post,
            leak_event  => '0', -- Ca counter leakage disabled
            ca          => ca
        );
        
    inst_comparator : comparator
        port map (
            ca          => ca,
            Vmem        => Vmem,
            up          => up,
            down        => down
        );
        
    inst_sdsp_top : sdsp_top
        generic map(
            w_WIDTH     => w_WIDTH
        )
        port map(
            up          => up,
            down        => down,
            spk_pre     => spk_pre,
            bist        => '0', -- Bistability events disabled
            w           => w,
            w_next      => w_new,
            clk         => clk,
            rst         => rst
        );
        
    process(clk, rst)
    begin
        if rst = '1' then
            w_next <= w;
        elsif rising_edge(clk) then
            if learn_en = '1' then
                w_next <= w_new;
            else
                w_next <= w;
            end if;
        end if;
    end process;

end Structural;
