#!/usr/bin/env ruby
#
# spidsolver.rb
#
# A Solver for the Spider Solitair game as implemented in spid.rb
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

require 'spid'

def usage
  puts "usage: spidsolve nr"
  puts "  Will try to solve nr games and reports the results"
  puts "  This is work in progress"
  puts "  I plan to implement many more features in the future"
end

class SpidSolver < Tableau
  def initialize
    super(false)
  end

  # main function implementing the basic solver strategy
  def solve
    # main loop
    until solved?
      color_cleaner
      unless improve
        # no improvement found
        if @draws < NrDraws
          setup_draw
          draw
        else
          # was not able to solve
          return false
        end
      end
    end

    return true
  end

  protected

  def solved?
    @columns.inject(true) {|t, column| t && column.empty?}
  end

  # TODO
  def color_cleaner
  end

  # TODO
  def improve
    # check if removal is possible
    NrColumns.times do |col|
      return true if remove(col)
    end

    return false
  end

  # TODO
  def setup_draw
  end
end

if $0 == __FILE__
  if ARGV.size != 1
    usage
    exit 0
  end

  solved = 0
  ARGV[0].to_i.times do
    s = SpidSolver.new
    solved += 1 if s.solve
  end

  puts solved
end
