#!/usr/bin/env ruby
#
# spid.rb
#
# A simple Spider Solitair game that is played on the command line
#
# Usage: at the prompt type  h  to get the online help
#
#   Copyright 2010 - 2012 Michael Ulm
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.

#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'optparse'
require 'yaml'

# Search paths for the config file
# Name your config file as one of these to automatically load it
DefaultConfigFiles = ['~/.spidrc', '~/spidrc', './config.yml']

# Default values are used if no config file is found or the options are not defined in it
#
# List of default constants
NrSuit = 4
NrVals = 13
NrColumns = 10
NrDecks = 2
NrDraws = 5

# show surface development index
ShowSDI = true

# List of default values for command line options
SuitColor = [1, 2, 3, 4]
SuitFGColor = [37, 30, 30, 37]

# Value class holding individual card values
# Naming was done to keep consistent with the French vocabulary used in Solitair gaiming
class Valeur
  attr_reader :suit, :val

  @@colors = SuitColor
  @@colors_fg = SuitFGColor
  @@color_output = true

  def initialize(nr, visible)
    @suit, @val = nr.divmod(NrVals)
    @visible = visible
  end

  def state
    [@suit, @val]
  end

  def set_visible
    @visible = true
  end

  def hidden?
    ! @visible
  end

  def visible?
    @visible
  end

  def to_s
    if @visible
      if @@color_output
        "\e[38;05;#{@@colors_fg[@suit]};48;5;#{@@colors[@suit]}m #{@val.to_s(NrVals)}\e[0m"
      else
        "#{@suit.to_s(NrSuit)}#{@val.to_s(NrVals)}"
      end
    else
      "XX"
    end
  end

  # sets the display colors for color display
  def self.set_colors(colors)
    return unless colors
    if Array === colors && colors.size == 4
      @@colors = colors.map {|c| c.to_i}
    else
      throw 'Wrong color definition used in Valeur#set_colors'
    end
  end

  # sets the display foreground colors for color display
  def self.set_fg_colors(colors)
    return unless colors
    if Array === colors && colors.size == 4
      @@colors_fg = colors.map {|c| c.to_i}
    else
      throw 'Wrong color definition used in Valeur#set_fg_colors'
    end
  end

  def self.set_unicolor
    @@color_output = false
  end
end

# This class holds the tableau (i.e. the full status) of the current game.
class Tableau
  attr_reader :draws

  def initialize(open_spider, xtra_hard = false)
    @open_spider = open_spider
    @base = NrSuit * NrVals
    @draws = 0

    begin
      @columns = Array.new(NrColumns) {Array.new}
      @shuffled = (0...(@base * NrDecks)).map {|i| i % @base}.sort_by {rand}
      @pos = (@base * NrDecks - NrDraws * NrColumns)
      @pos.times do |i|
        @columns[i % NrColumns] << Valeur.new(@shuffled[i], @open_spider)
      end
      @columns.each {|a_col| a_col[-1].set_visible if a_col[-1]}
    end while xtra_hard && sdi != 0
  end

  def set_debug
    @debug = true
  end

  def draw
    if @draws < NrDraws
      @draws += 1
      NrColumns.times do |i_col|
        @columns[i_col] << Valeur.new(@shuffled[@pos], true)
        @pos += 1
      end
      true
    else
      false
    end
  end

  def max_column_size
    @columns.map {|c| c.size}.max
  end

  # get the values of the future draws
  def get_draw(offset)
    @shuffled[@pos + offset * NrColumns, NrColumns].map {|s| Valeur.new(s, true)}
  end

  def to_s
    (0...max_column_size).map {|i_row| (0...NrColumns).map {|i_col| @columns[i_col][i_row].to_s.rjust(2)}.join(' ')}.join("\n")
  end

  def nr_invisible
    @columns.inject(0) {|s, a_column| s + a_column.inject(0) {|t, c| t + (c.hidden? ? 1 : 0)}}
  end

  # returns the number of visible valeurs of the given value
  def nr_val_visible(val)
    @columns.inject(0) {|s, a_column| s + a_column.inject(0) {|t, c| t + (c.visible? && c.val == val ? 1 : 0)}}
  end

  # check if a column of the given length maps to the target
  def maps?(col_source, length, col_target)
    puts "maps? called with (#{col_source}, #{length}, #{col_target})" if @debug
    return true if length < 1

    source_col = @columns[col_source]
    return false if length > source_col.size

    pos = source_col.size - 1
    current_suit, current_val = source_col[pos].state
    (1...length).each do |i|
      val = source_col[pos - i]
      return false if val.hidden?
      return false if val.suit != current_suit
      return false if val.val != current_val + i
    end

    target_col = @columns[col_target]
    return true if target_col.empty?
    return (source_col[pos - length + 1].val + 1 == target_col.last.val)
  end

  # map a column of the given length to the target
  def map(col_source, length, col_target)
    puts "map called with (#{col_source}, #{length}, #{col_target})" if @debug
    if maps?(col_source, length, col_target)
      @columns[col_target].concat(@columns[col_source][(-length)..-1])
      @columns[col_source] = @columns[col_source][0...(-length)]
      @columns[col_source].last.set_visible unless @columns[col_source].empty?
      puts "map succeeded" if @debug
      return true
    else
      return false
    end
  end

  # map a column of maximal length to the target
  # returns the size of the mapped subcolumn
  def map_maximal(col_source, col_target)
    puts "map_maximal called with (#{col_source}, #{col_target})" if @debug
    max_length = max_map_length(col_source)
    source_valeur = @columns[col_source].last
    target_valeur = @columns[col_target].last
    possible_length = (source_valeur && target_valeur ? target_valeur.val - source_valeur.val : max_length)

    length = [possible_length, max_length].min

    puts "map_maximal determined length at #{length}" if @debug

    map(col_source, length, col_target) if length > 0
    length
  end

  # returns the longest possible length that the given column can move
  def max_map_length(col)
    source_col = @columns[col]
    return 0 if source_col.empty?

    pos = source_col.size - 1
    current_suit, current_val = source_col[pos].state
    max_length = 1
    pos -= 1
    while pos >= 0 && source_col[pos].visible? && source_col[pos].suit == current_suit && source_col[pos].val == current_val + max_length
      pos -= 1
      max_length += 1
    end
    max_length
  end

  # remove full set on the column
  # returns true if successful, false otherwise
  def remove(col)
    source_col = @columns[col]
    return false if source_col.length < NrVals
    pos = source_col.length - 1
    current_suit = source_col[pos].suit
    NrVals.times do |i_val|
      return false if source_col[pos].suit != current_suit
      return false if source_col[pos].val != i_val
      return false if source_col[pos].hidden?
      pos -= 1
    end

    @columns[col] = @columns[col][0...(- NrVals)]
    @columns[col].last.set_visible unless @columns[col].empty?

    return true
  end

  # Returns the surface development index of the tableau.
  # This value describes the number of possible first level improvements.
  def sdi
    hi = Array.new(NrVals, 0)
    lo = Array.new(NrVals, 0)

    @columns.each do |col|
      unless col.empty?
        value = col.last.val
        lo[value] += 1
        pos = col.size - 2
        while pos >= 0 && ! col[pos].hidden? && col[pos].val == value + 1
          value = col[pos].val
          pos -= 1
        end
        hi[value] += 1
      end
    end

    puts "sdi has \n #{lo.inspect} and \n #{hi.inspect}" if @debug
    hi[0..-2].zip(lo[1..-1]).inject(0) {|s, (x, y)| s + [x, y].min}
  end
end

def display(tab, open_spider, show_sdi)
  header = (0...NrColumns).map {|col| col.to_s.rjust(2)}.join(' ') + "   (#{tab.draws})"
  header += " [#{tab.sdi}]" if show_sdi

  puts header
  puts tab
  if open_spider
    puts
    (NrDraws - tab.draws).times do |i|
      puts tab.get_draw(i).map{|v| v.to_s.rjust(2)}.join(' ')
    end
  end
  puts
end

def help
  puts "Commands"
  puts "  (a1)(b1)[(a2)(b2)...] move from columns ai to columns bi as much as possible"
  puts "  m(a)(n)(b)    move n from column a to column b"
  puts "  s(a)(b)(c)    swap a and b using free column c. equivalent to the moves ac ba cb"
  puts "  x(a)(b)(c)    extended move from a to c using empty b moving 2 stacks"
  puts "  x(a)(b)(c)(d) extended move from a to d using empty b and c moving 4 stacks"
  puts "  y(a)(b)(c)(d) extended move from a to d using empty b and c but only move 3 stacks"
  puts "  r(a)          remove column a"
  puts "  rr            remove all possible columns"
  puts "  i             display number of invisibles"
  puts "  v             display list of numbers of visible values"
  puts "  h             display this help"
  puts "  c(v)          display number of visible values v"
  puts "  q             quit"
end

if $0 == __FILE__
  # parse command line options
  options = {}

  optparse = OptionParser.new do |opts|
    opts.banner = "usage: ruby spid.rb [options]"

    options[:open] = false
    opts.on('-o', '--open', 'Play Open Spider variant') do
      options[:open] = true
    end

    options[:colors] = nil
    opts.on('-c', '--colors c1,c2,c3,c4', "Color codes of the color display. default #{SuitColor.join(',')}") do |cols|
      if cols =~ /(\d+),(\d+),(\d+),(\d+)/
        options[:colors] = [$1, $2, $3, $4].map {|c| c.to_i}
      else
        puts "Wrong format for colors"
        exit
      end
    end

    options[:fg_colors] = nil
    opts.on('-f', '--foreground c1,c2,c3,c4', "Color codes of the foreground colors. default #{SuitFGColor.join(',')}") do |cols|
      if cols =~ /(\d+),(\d+),(\d+),(\d+)/
        options[:fg_colors] = [$1, $2, $3, $4].map {|c| c.to_i}
      else
        puts "Wrong format for colors"
        exit
      end
    end

    options[:unicolor] = false
    opts.on('-u', '--unicolor', "Set output to display without colors") do
      options[:unicolor] = true
    end

    options[:seed] = false
    opts.on('-s', '--seed nr', 'Seed random number generator with nr' ) do |nr|
      options[:seed] = nr.to_i
    end

    options[:xtra_hard] = false
    opts.on('-x', '--xtra', "Extra hard starting hands (for masochists only)") do
      options[:xtra_hard] = true
    end

    options[:debug] = false
    opts.on('-d', '--debug', 'Display debug messages' ) do
      options[:debug] = true
    end

    options[:config] = DefaultConfigFiles
    opts.on('-k', '--config config_file', 'Use the given config file' ) do |conf|
      options[:config] = [conf]
    end

    opts.on('-h', '--help', 'Display this help' ) do
      puts opts
      exit
    end
  end

  optparse.parse!

  config = {}
  options[:config].each do |conf|
    full_name = File.expand_path(conf)
    puts "checking #{full_name}"
    if File.exists?(full_name)
      puts "found #{full_name}"
      config = YAML.load_file(full_name)
      break
    end
  end

  puts config.inspect

  Valeur.set_colors(options[:colors] || config["suit_color"])
  Valeur.set_fg_colors(options[:fg_colors] || config["suit_fg_color"])
  Valeur.set_unicolor if options[:unicolor]

  srand(options[:seed]) if options[:seed]

  tab = Tableau.new(options[:open], options[:xtra_hard])
  tab.set_debug if options[:debug]

  # display options
  show_sdi = ShowSDI
  show_sdi = config["show_sdi"] unless config["show_sdi"].nil?
  show_open = options[:open]

  display(tab, show_open, show_sdi)
  continue = true
  while continue
    user_input = gets
    redisplay = true
    case user_input
    when /^(\d)(\d)/
      temp_input = user_input.dup
      temp_length = 2
      while temp_length > 0 && temp_input =~ /^(\d)(\d)/
        temp_length = tab.map_maximal($1.to_i, $2.to_i)
        temp_input = temp_input[2..-1]
      end
    when /^d/
      tab.draw
      puts "Draw #{tab.draws}"
    when /^m(\d)(\d)(\d)/
      tab.map($1.to_i, $2.to_i,$3.to_i)
    when /^r(\d)/
      if tab.remove($1.to_i)
        puts "Removed"
      else
        puts "Unable to remove"
      end
    when /^rr/
      NrColumns.times do |col|
        while tab.remove(col); end
      end
      puts "Removed"
    when /^i/
      puts "invisible: #{tab.nr_invisible}"
      redisplay = false
    when /^c(.)/
      # WARNING This only works atm. for NrVals < 17
      puts "nr #{$1}: #{tab.nr_val_visible($1.hex)}"
      redisplay = false
    when /^v/
      puts (0...NrVals).map {|a_val| a_val.to_s(NrVals)}.join(' ')
      puts (0...NrVals).map {|a_val| tab.nr_val_visible(a_val)}.join(' ')
      redisplay = false
    when /^h/
      help
      redisplay = false
    when /^q/
      continue = false
      redisplay = false
    when /^s(\d)(\d)(\d)/
      tab.map_maximal($1.to_i, $3.to_i)
      tab.map_maximal($2.to_i, $1.to_i)
      tab.map_maximal($3.to_i, $2.to_i)
    when /^x(\d)(\d)(\d)(\d)/
      tab.map_maximal($1.to_i, $2.to_i)
      tab.map_maximal($1.to_i, $3.to_i)
      tab.map_maximal($2.to_i, $3.to_i)
      tab.map_maximal($1.to_i, $2.to_i)
      tab.map_maximal($1.to_i, $4.to_i)
      tab.map_maximal($2.to_i, $4.to_i)
      tab.map_maximal($3.to_i, $2.to_i)
      tab.map_maximal($3.to_i, $4.to_i)
      tab.map_maximal($2.to_i, $4.to_i)
    when /^x(\d)(\d)(\d)/
      tab.map_maximal($1.to_i, $2.to_i)
      tab.map_maximal($1.to_i, $3.to_i)
      tab.map_maximal($2.to_i, $3.to_i)
    when /^y(\d)(\d)(\d)(\d)/
      tab.map_maximal($1.to_i, $2.to_i)
      tab.map_maximal($1.to_i, $3.to_i)
      tab.map_maximal($1.to_i, $4.to_i)
      tab.map_maximal($3.to_i, $4.to_i)
      tab.map_maximal($2.to_i, $4.to_i)
    else
      puts "Unrecognized command"
    end
    display(tab, show_open, show_sdi) if redisplay
  end
end
