----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz<
--
-- Module Name:    dvid_serdes - Behavioral
-- Description: Generating a DVI-D 720p signal using the OSERDES2 serialisers
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

entity dvid_serdes is
  port(
    mt9d111_d     : in    std_logic_vector(7 downto 0);
    mt9d111_xclk  : out   std_logic;
    mt9d111_pclk  : in    std_logic;
    mt9d111_href  : in    std_logic;
    mt9d111_vsync : in    std_logic;
    mt9d111_sda   : inout std_logic;
    mt9d111_scl   : out   std_logic;

    clk50      : in  std_logic;
    tmds_out_p : out std_logic_vector(3 downto 0);
    tmds_out_n : out std_logic_vector(3 downto 0);
    btns       : in  std_logic_vector(3 downto 0);
    leds       : out std_logic_vector(1 downto 0)
  );
end dvid_serdes;

architecture Behavioral of dvid_serdes is
  signal pixel_clock_t     : std_logic;
  signal data_load_clock_t : std_logic;
  signal ioclock_t         : std_logic;
  signal serdes_strobe_t   : std_logic;

--  signal red_mux : std_logic_vector(7 downto 0);

  signal red_t   : std_logic_vector(7 downto 0);
  signal green_t : std_logic_vector(7 downto 0);
  signal blue_t  : std_logic_vector(7 downto 0);
  signal blank_t : std_logic;
  signal hsync_t : std_logic;
  signal vsync_t : std_logic;

  signal tmds_out_red_t   : std_logic;
  signal tmds_out_green_t : std_logic;
  signal tmds_out_blue_t  : std_logic;
  signal tmds_out_clock_t : std_logic;

  signal capture_addr : std_logic_vector(14 downto 0);
  signal capture_data : std_logic_vector(7 downto 0);
  signal capture_we   : std_logic_vector(0 downto 0);
  signal resend       : std_logic;
  signal config_finished :std_logic;

  component mt9d111_controller
    port(
      clk   : IN    std_logic;
      resend: IN    std_logic;
      config_finished : out std_logic;
      siod  : INOUT std_logic;
      sioc  : OUT   std_logic;
      xclk  : OUT   std_logic
    );
  end component;

  component mt9d111_capture
    port(
      pclk  : in  std_logic;
      vsync : in  std_logic;
      href  : in  std_logic;
      d     : in  std_logic_vector(7 downto 0);
      addr  : out std_logic_vector(14 downto 0);
      dout  : out std_logic_vector(7 downto 0);
      we    : out std_logic
    );
  end component;

  component vga_gen
    port(
      clk75   : in  std_logic;
      red     : out std_logic_vector(7 downto 0);
      green   : out std_logic_vector(7 downto 0);
      blue    : out std_logic_vector(7 downto 0);
      blank   : out std_logic;
      hsync   : out std_logic;
      vsync   : out std_logic;
      pattern : in  std_logic_vector (3 downto 0)
    );
  end component;

  component clocking
    port(
      clk50m          : in  std_logic;
      pixel_clock     : out std_logic;
      data_load_clock : out std_logic;
      ioclock         : out std_logic;
      serdes_strobe   : out std_logic
    );
  end component;

  component dvid_out
    port(
      pixel_clock     : in std_logic;
      data_load_clock : in std_logic;
      ioclock         : in std_logic;
      serdes_strobe   : in std_logic;
      red_p           : in std_logic_vector(7 downto 0);
      green_p         : in std_logic_vector(7 downto 0);
      blue_p          : in std_logic_vector(7 downto 0);
      blank           : in std_logic;
      hsync           : in std_logic;
      vsync           : in std_logic;
      red_s           : out std_logic;
      green_s         : out std_logic;
      blue_s          : out std_logic;
      clock_s         : out std_logic
    );
  end component;

begin
--debug
  leds(0) <= hsync_t;
  leds(1) <= vsync_t;

  i_mt9d111_controller: mt9d111_controller port map(
    clk   => clk50,
    xclk  => mt9d111_xclk,
    sioc  => mt9d111_scl,
    siod  => mt9d111_sda,
    resend => resend,
    config_finished => config_finished
  );

  i_mt9d111_capture: mt9d111_capture port map(
    pclk  => mt9d111_pclk,
    vsync => mt9d111_vsync,
    href  => mt9d111_href,
    d     => mt9d111_d,
    addr  => capture_addr,
    dout  => capture_data,
    we    => capture_we(0)
  );

  Inst_clocking: clocking port map(
    clk50m          => clk50,
    pixel_clock     => pixel_clock_t,
    data_load_clock => data_load_clock_t,
    ioclock         => ioclock_t,
    serdes_strobe   => serdes_strobe_t
  );

  i_vga_gen: vga_gen port map(
    clk75   => pixel_clock_t,
    red     => green_t,
    green   => red_t,
    blue    => blue_t,
    blank   => blank_t,
    hsync   => hsync_t,
    vsync   => vsync_t,
    pattern => btns
  );

  i_dvid_out: dvid_out port map(
    pixel_clock     => pixel_clock_t,
    data_load_clock => data_load_clock_t,
    ioclock         => ioclock_t,
    serdes_strobe   => serdes_strobe_t,

    red_p   => red_t,
    green_p => green_t,
    blue_p  => blue_t,
    blank   => blank_t,
    hsync   => hsync_t,
    vsync   => vsync_t,

    red_s   => tmds_out_red_t,
    green_s => tmds_out_green_t,
    blue_s  => tmds_out_blue_t,
    clock_s => tmds_out_clock_t
  );

  OBUFDS_blue  : OBUFDS port map( O => tmds_out_p(0), OB => tmds_out_n(0), I => tmds_out_blue_t);
  OBUFDS_red   : OBUFDS port map( O => tmds_out_p(1), OB => tmds_out_n(1), I => tmds_out_green_t);
  OBUFDS_green : OBUFDS port map( O => tmds_out_p(2), OB => tmds_out_n(2), I => tmds_out_red_t);
  OBUFDS_clock : OBUFDS port map( O => tmds_out_p(3), OB => tmds_out_n(3), I => tmds_out_clock_t);
end Behavioral;
