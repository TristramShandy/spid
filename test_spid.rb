#!/usr/bin/env ruby

require './spid'
require 'test/unit'
require 'enumerator'

class PermutationTester < Test::Unit::TestCase
  def setup
    @perm_0 = [[2, 0, 1], [3, 0, 2], [5, 2, 0], [7, 1, 0]]
    @path_0 = [2]
    @x_0 = @perm_0[0][1]
    @y_0 = @perm_0[0][2]
    @perm_1 = [[2, 0, 1], [3, 0, 4], [5, 2, 0], [7, 1, 0], [11, 0, 4], [13, 3, 2], [17, 1, 3], [19, 2, 0]]
    @perm_2 = [[2, 0, 1], [3, 0, 2], [5, 2, 0], [7, 1, 0], [11, 0, 2], [13, 3, 2], [17, 1, 3], [19, 2, 0], [23, 0, 1], [29, 2, 0]]
  end

  def test_find_path_recursive_nopath2
    @perm_0[3][2] = 2
    assert_false(find_path_recursive([[0, 0, 1], [1, 0, 2], [2, 0, 3]], @x_0, @y_0, @path_0, 1))
  end

  def test_find_path_recursive_simple2
    assert_true(find_path_recursive(@perm_0, @x_0, @y_0, @path_0, 1))
    assert_equal(2, @path_0.size)
    assert_equal(2, @path_0[0])
    assert_equal(7, @path_0[1])
  end

  def test_find_path_recursive_nopath4
    @perm_0[2][2] = 3
    assert_false(find_path_recursive(@perm_0, @x_0, @y_0, @path_0, 3))
  end

  def test_find_path_recursive_path4
    assert_true(find_path_recursive(@perm_1, @x_0, @y_0, @path_0, 3))
    assert_equal(4, @path_0.size)
    assert_equal(2, @path_0[0])
    assert_equal(17, @path_0[1])
    assert_equal(13, @path_0[2])
    assert_equal(5, @path_0[3])
  end

  def test_get_cycle_base2
    path = get_cycle(@perm_0, 2)
    assert_equal(2, path.size)
    assert_equal(2, path[0])
    assert_equal(7, path[1])
  end

  def test_sort_clear_empty
    assert_true(sort_clear([]).empty?)
  end

  def test_sort_clear_base
    cycles = sort_clear(@perm_2)
    assert_equal(4, cycles.size)
    assert_equal(2, cycles[0].size)
    assert_equal(2, cycles[1].size)
    assert_equal(2, cycles[2].size)
    assert_equal(4, cycles[3].size)

    assert_equal(2, cycles[0][0])
    assert_equal(7, cycles[0][1])

    assert_equal(3, cycles[1][0])
    assert_equal(5, cycles[1][1])

    assert_equal(11, cycles[2][0])
    assert_equal(19, cycles[2][1])

    assert_equal(13, cycles[3][0])
    assert_equal(29, cycles[3][1])
    assert_equal(23, cycles[3][2])
    assert_equal(17, cycles[3][3])
  end
end

class TableauTester < Test::Unit::TestCase
  def autofinish_tableau(ar)
    ar.map do |str|
      str.split('').enum_for(:each_with_index).map do |ch, i|
        suit = ch.to_i
        nr = suit * NrVals + i
        Valeur.new(nr, true)
      end.reverse
    end
  end

  def setup
    @tab7 = Tableau.new(false)
    ar7 = ['',
           '3223222200000',
           '3333333333332',
           '2112133333223',
           '1330320000000',
           '0000000022222',
           '',
           '2222212222311',
           '',
           '0001001111133']
    @tab7.set_tableau(autofinish_tableau(ar7))
  end

  def test_autofinish_prelim
    assert_true(@tab7.autofinish_possible?)
    assert_equal(0, @tab7.get_first_empty)
    filled = @tab7.get_filled
    assert_equal(7, filled.size)
    assert_equal(1, filled[0])
    assert_equal(2, filled[1])
    assert_equal(3, filled[2])
    assert_equal(4, filled[3])
    assert_equal(5, filled[4])
    assert_equal(7, filled[5])
    assert_equal(9, filled[6])
  end

  def test_autofinish_single_with7
    filled = @tab7.get_filled
    to_clear_0 = @tab7.autofinish_clear_info(12, filled)
    assert_equal(3, to_clear_0.size)
    assert_equal([1, 3, 2], to_clear_0[0])
    assert_equal([3, 2, 1], to_clear_0[1])
    assert_equal([4, 1, 3], to_clear_0[2])

    sorted = sort_clear(to_clear_0)
    assert_equal([[1, 3, 4]], sorted)

    i_empty = @tab7.get_first_empty
    @tab7.cycle_map_maximal(sorted[0], i_empty)
    to_clear_1 = @tab7.autofinish_clear_info(12, filled)
    assert_true(to_clear_1.empty?)
  end

  def test_autofinish_all_with7
    filled = @tab7.get_filled
    info = @tab7.autofinish
    assert_equal({2=>4, 3=>3, 4=>2}, info)
    filled.each do |i|
      assert_true(@tab7.remove(i))
    end
    assert_true(@tab7.empty?)
  end

  def test_autofinish_empty
    tab = Tableau.new(true)
    tab.set_tableau(Array.new(NrColumns) {[]})
    assert_true(tab.empty?)
    assert_true(tab.autofinish_possible?)
    info = tab.autofinish
    assert_true(info.empty?)
  end
end

