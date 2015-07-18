--------------------------------------------------------------------------------
-- Engineer:      Mike Field <hamster@snap.net.nz>
-- Description:   Converts VGA signals into DVID bitstreams.
--
--                data_load_clock is 2x pixel_clock (used to load the 5:1 serialisers)
--                ioclock is serialiser output clock
--
--                'blank' should be asserted during the non-display 
--                portions of the frame
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

entity dvid_out is
  port(
    pixel_clock     : in  std_logic;
    data_load_clock : in  std_logic;
    ioclock         : in  std_logic;
    serdes_strobe   : in  std_logic;
    red_p           : in  std_logic_vector (7 downto 0);
    green_p         : in  std_logic_vector (7 downto 0);
    blue_p          : in  std_logic_vector (7 downto 0);
    blank           : in  std_logic;
    hsync           : in  std_logic;
    vsync           : in  std_logic;
    red_s           : out std_logic;
    green_s         : out std_logic;
    blue_s          : out std_logic;
    clock_s         : out std_logic
  );
end dvid_out;

architecture Behavioral of dvid_out is
  component tmds_encoder
    port(
      clk     : in  std_logic;
      data    : in  std_logic_vector(7 downto 0);
      c       : in  std_logic_vector(1 downto 0);
      blank   : in  std_logic;
      encoded : out std_logic_vector(9 downto 0)
    );
  end component;

  component tmds_out_fifo
    port(
      wr_clk     : in  std_logic;
      rd_clk     : in  std_logic;
      din        : in  std_logic_vector(29 downto 0);
      wr_en      : in  std_logic;
      rd_en      : in  std_logic;
      dout       : out std_logic_vector(29 downto 0);
      full       : out std_logic;
      empty      : out std_logic;
      prog_empty : out std_logic
    );
  end component;

  component output_serialiser
    port(
      clk_load   : in  std_logic;
      clk_output : in  std_logic;
      strobe     : in  std_logic;
      ser_data   : in  std_logic_vector(4 downto 0);
      ser_output : out std_logic
    );
  end component;

  signal encoded_red, encoded_green, encoded_blue : std_logic_vector(9 downto 0);
  signal latched_red, latched_green, latched_blue : std_logic_vector(9 downto 0) := (others => '0');
  signal ser_in_red,  ser_in_green,  ser_in_blue, ser_in_clock   : std_logic_vector(4 downto 0) := (others => '0');
  signal fifo_in       : std_logic_vector(29 downto 0);
  signal fifo_out      : std_logic_vector(29 downto 0);
  signal rd_enable     : std_logic := '0';
  signal not_ready_yet : std_logic;

  constant c_red       : std_logic_vector(1 downto 0) := (others => '0');
  constant c_green     : std_logic_vector(1 downto 0) := (others => '0');
  signal   c_blue      : std_logic_vector(1 downto 0);

begin
  -- Send the pixels to the encoder
  c_blue <= vsync & hsync;
  tmds_encoder_red:   tmds_encoder port map(clk => pixel_clock, data => red_p,   c => c_red,   blank => blank, encoded => encoded_red);
  tmds_encoder_green: tmds_encoder port map(clk => pixel_clock, data => green_p, c => c_green, blank => blank, encoded => encoded_green);
  tmds_encoder_blue:  tmds_encoder port map(clk => pixel_clock, data => blue_p,  c => c_blue,  blank => blank, encoded => encoded_blue);

  -- Then to a small FIFO
  fifo_in <= encoded_red & encoded_green & encoded_blue;

  out_fifo: tmds_out_fifo
    port map(
      wr_clk => pixel_clock,
      din    => fifo_in,
      wr_en  => '1',
      full   => open,

      rd_clk     => data_load_clock,
      rd_en      => rd_enable,
      dout       => fifo_out,
      empty      => open,
      prog_empty => not_ready_yet
    );

  -- Now at a x2 clock, send the data from the fifo to the serialisers
  process(data_load_clock)
  begin
    if rising_edge(data_load_clock) then
      if not_ready_yet = '0' then
        if rd_enable = '1' then
          ser_in_red   <= fifo_out(29 downto 25);
          ser_in_green <= fifo_out(19 downto 15);
          ser_in_blue  <= fifo_out( 9 downto  5);
          ser_in_clock <= "11111";
          rd_enable <= '0';
        else
          ser_in_red   <= fifo_out(24 downto 20);
          ser_in_green <= fifo_out(14 downto 10);
          ser_in_blue  <= fifo_out( 4 downto  0);
          ser_in_clock <= "00000";
          rd_enable <= '1';
        end if;
      end if;
    end if;
  end process;

  output_serialiser_r: output_serialiser port map(clk_load => data_load_clock, clk_output => ioclock, strobe => serdes_strobe, ser_data => ser_in_red,   ser_output => red_s);
  output_serialiser_g: output_serialiser port map(clk_load => data_load_clock, clk_output => ioclock, strobe => serdes_strobe, ser_data => ser_in_green, ser_output => green_s);
  output_serialiser_b: output_serialiser port map(clk_load => data_load_clock, clk_output => ioclock, strobe => serdes_strobe, ser_data => ser_in_blue,  ser_output => blue_s);
  output_serialiser_c: output_serialiser port map(clk_load => data_load_clock, clk_output => ioclock, strobe => serdes_strobe, ser_data => ser_in_clock, ser_output => clock_s);

end Behavioral;
