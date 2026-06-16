# frozen_string_literal: true

# Regression tests for CabinetMaker::Calc
# Run from Terminal:  ruby test_calc.rb
# (from inside the cabinet_maker/ folder)

require "minitest/autorun"
require_relative "calc"

class TestCabinetCalc < Minitest::Test
  def default_opts
    {
      name: "TestCab",
      width_mm: 600.0,
      height_mm: 760.0,
      depth_mm: 560.0,
      case_thk_mm: 18.0,
      back_thk_mm: 6.0,
      groove_width_mm: 6.5,
      groove_depth_mm: 8.0,
      back_setback_mm: 18.0,
      stretcher_width_mm: 100.0
    }
  end

  def result
    @result ||= CabinetMaker::Calc.compute_parts(default_opts)
  end

  def derived
    result[:derived]
  end

  def parts
    result[:parts]
  end

  def find_part(type)
    parts.find { |p| p[:attrs][:part_type] == type }
  end

  # --- No errors on valid input ---
  def test_no_error_on_defaults
    assert_nil result[:error]
  end

  # --- Derived dimensions ---
  def test_internal_width
    assert_equal 564.0, derived[:internal_w]
  end

  def test_back_panel_width_includes_grooves
    # internal_w + 2 * groove_depth = 564 + 16 = 580
    assert_equal 580.0, derived[:back_panel_w]
  end

  def test_back_panel_height_includes_groove
    # (h - t) + groove_depth = (760 - 18) + 8 = 750
    assert_equal 750.0, derived[:back_panel_h]
  end

  def test_back_panel_back_face_y
    # d - setback = 560 - 18 = 542
    assert_equal 542.0, derived[:back_panel_back_face_y]
  end

  def test_back_panel_front_face_y
    # back_face_y - bt = 542 - 6 = 536
    assert_equal 536.0, derived[:back_panel_front_face_y]
  end

  # --- v0.4 regression: vertical stretcher top coplanar with sides ---
  def test_rear_vert_stretcher_top_equals_side_height
    assert_equal 760.0, derived[:rear_vert_origin_z]
  end

  # --- v0.6 regression: back panel wider than stretchers ---
  def test_back_panel_wider_than_stretchers
    back = find_part("back")
    stretcher = find_part("stretcher_top_front")
    assert_operator back[:length_x], :>, stretcher[:length_x],
      "Back panel should be wider than stretchers (groove extensions)"
  end

  # --- Part count ---
  def test_seven_parts_generated
    assert_equal 7, parts.length
  end

  # --- Back panel origin includes groove offset ---
  def test_back_panel_origin_x
    back = find_part("back")
    # t - groove_d = 18 - 8 = 10
    assert_equal 10.0, back[:origin][0]
  end

  def test_back_panel_origin_z
    back = find_part("back")
    # t - groove_d = 18 - 8 = 10
    assert_equal 10.0, back[:origin][2]
  end

  # --- Stretcher positions ---
  def test_top_front_stretcher_at_top
    s = find_part("stretcher_top_front")
    # h - t = 760 - 18 = 742
    assert_equal 742.0, s[:origin][2]
  end

  def test_top_rear_stretcher_y
    s = find_part("stretcher_top_rear")
    # back_panel_front_face_y - stretcher_w = 536 - 100 = 436
    assert_equal 436.0, s[:origin][1]
  end

  # --- Invalid input ---
  def test_error_on_zero_internal_width
    opts = default_opts.merge(width_mm: 30.0, case_thk_mm: 18.0)
    result = CabinetMaker::Calc.compute_parts(opts)
    refute_nil result[:error]
  end

  def test_error_on_bad_setback
    opts = default_opts.merge(back_setback_mm: 600.0)
    result = CabinetMaker::Calc.compute_parts(opts)
    refute_nil result[:error]
  end
end