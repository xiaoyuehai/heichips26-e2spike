----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/07/21 18:18:47
-- Design Name: 
-- Module Name: sdsp_top - Behavioral
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

entity sdsp_top is

-- Generic values that are configurable for users
  generic(
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
end sdsp_top;

architecture Structural of sdsp_top is

    component delta_w_generator is
        generic(
            w_WIDTH     : integer :=8
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
    end component;
    
    component overflow_detector is
          Port ( 
            a       : in std_logic;
            cin     : in std_logic;
            carry   : in std_logic;
            y       : out std_logic
          );
    end component;
    
    component nbit_adder is
        generic(
            w_WIDTH     : integer := 8
        );
        port(
            a           : in std_logic_vector(w_WIDTH-1 downto 0);
            b           : in std_logic_vector(w_WIDTH-1 downto 0);
            cin         : in std_logic;
            sum         : out std_logic_vector(w_WIDTH-1 downto 0);
            cout        : out std_logic
        );
    end component;
    
    component mux is
        generic(
            w_WIDTH     : integer := 8
        );
        port(
            a       : in std_logic_vector(w_WIDTH-1 downto 0);
            b       : in std_logic_vector(w_WIDTH-1 downto 0);
            sel     : in std_logic;
            o       : out std_logic_vector(w_WIDTH-1 downto 0)
        );
    end component;
    
    component d_ff is
        generic(
            w_WIDTH     : integer := 8
        );
        port(
            clk         : in std_logic;
            rst         : in std_logic;
            d           : in std_logic_vector(w_WIDTH-1 downto 0);
            q           : out std_logic_vector(w_WIDTH-1 downto 0)
        );
    end component;
    
    signal cin          : std_logic;
    signal cout         : std_logic;
    signal delta_w      : std_logic_vector(w_WIDTH-1 downto 0);
    signal sel          : std_logic;
    signal sum          : std_logic_vector(w_WIDTH-1 downto 0);
    signal w_new        : std_logic_vector(w_WIDTH-1 downto 0);

begin

    u1_delta_w_generator: delta_w_generator
        generic map(
            w_WIDTH     => w_WIDTH
        )
        port map(
            up          => up,
            down        => down,
            spk_pre     => spk_pre,
            bist        => bist,
            w_msb       => w(w_WIDTH-1),
            delta_w     => delta_w,
            cin         => cin
        );
    
    u2_overflow_detector: overflow_detector
        port map(
            a           => delta_w(0),
            cin         => cin,
            carry       => cout,
            y           => sel
        );
    
    u3_nbit_adder: nbit_adder
        generic map(
            w_WIDTH     => w_WIDTH
        )
        port map(
            a           => delta_w,
            b           => w,
            cin         => cin,
            sum         => sum,
            cout        => cout
        );
        
    u4_mux: mux
        generic map(
            w_WIDTH     => w_WIDTH
        )
        port map(
            a           => sum,
            b           => w,
            sel         => sel,
            o           => w_new
        );
        
    u5_d_ff: d_ff
        generic map(
            w_WIDTH     => w_WIDTH
        )
        port map(
            clk         => clk,
            rst         => rst,
            d           => w_new,
            q           => w_next
        );

end Structural;
