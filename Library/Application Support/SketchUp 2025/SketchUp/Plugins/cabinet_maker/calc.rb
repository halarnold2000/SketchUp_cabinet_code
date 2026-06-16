# frozen_string_literal: true

# CabinetMaker::Calc — pure math, no SketchUp dependency.
# All values in mm. Returns part specs as plain Ruby hashes.

module CabinetMaker
  module Calc
    extend self

    DEFAULTS = {
      name: "Cabinet",
      width_mm: 600.0,
      height_mm: 760.0,
      depth_mm: 560.0,
      case_thk_mm: 18.0,
      back_thk_mm: 6.0,
      groove_width_mm: 6.5,
      groove_depth_mm: 8.0,
      back_setback_mm: 18.0,
      stretcher_width_mm: 100.0
    }.freeze

    # Returns a hash with:
    #   :parts => array of part hashes (each with dimensions, origin, axes, attrs)
    #   :derived => hash of intermediate computed values (for test assertions)
    #   :error => string if inputs are invalid, nil otherwise
    def compute_parts(opts)
      name = opts[:name] || DEFAULTS[:name]

      w  = opts[:width_mm].to_f
      h  = opts[:height_mm].to_f
      d  = opts[:depth_mm].to_f
      t  = opts[:case_thk_mm].to_f
      bt = opts[:back_thk_mm].to_f
      groove_d = opts[:groove_depth_mm].to_f
      setback  = opts[:back_setback_mm].to_f
      stretcher_w = opts[:stretcher_width_mm].to_f

      internal_w = w - 2.0 * t

      return { error: "Width too small relative to case thickness." } if internal_w <= 0

      back_panel_back_face_y = d - setback
      back_panel_front_face_y = back_panel_back_face_y - bt

      if back_panel_back_face_y <= 0 || back_panel_back_face_y >= d
        return { error: "Back setback places the back plane outside cabinet depth." }
      end

      back_panel_w = internal_w + 2.0 * groove_d
      back_panel_h = (h - t) + groove_d

      top_rear_y = back_panel_front_face_y - stretcher_w

      derived = {
        internal_w: internal_w,
        back_panel_w: back_panel_w,
        back_panel_h: back_panel_h,
        back_panel_back_face_y: back_panel_back_face_y,
        back_panel_front_face_y: back_panel_front_face_y,
        top_rear_y: top_rear_y,
        rear_vert_origin_z: h,
        rear_vert_origin_y: d - t
      }

      parts = []

      # Side L
      parts << {
        part_name: "#{name} - Side L",
        length_x: d, length_y: h, thickness: t,
        origin: [0, 0, 0],
        xaxis: [0, 1, 0], yaxis: [0, 0, 1],
        attrs: { part_type: "side", material: "plywood",
                 thickness_mm: t, cabinet_name: name }
      }

      # Side R
      parts << {
        part_name: "#{name} - Side R",
        length_x: d, length_y: h, thickness: t,
        origin: [w - t, 0, 0],
        xaxis: [0, 1, 0], yaxis: [0, 0, 1],
        attrs: { part_type: "side", material: "plywood",
                 thickness_mm: t, cabinet_name: name }
      }

      # Bottom
      parts << {
        part_name: "#{name} - Bottom",
        length_x: internal_w, length_y: d, thickness: t,
        origin: [t, 0, 0],
        xaxis: [1, 0, 0], yaxis: [0, 1, 0],
        attrs: { part_type: "bottom", material: "plywood",
                 thickness_mm: t, cabinet_name: name }
      }

      # Back panel
      parts << {
        part_name: "#{name} - Back",
        length_x: back_panel_w, length_y: back_panel_h, thickness: bt,
        origin: [t - groove_d, back_panel_back_face_y, t - groove_d],
        xaxis: [1, 0, 0], yaxis: [0, 0, 1],
        attrs: { part_type: "back", material: "plywood_6mm",
                 thickness_mm: bt, cabinet_name: name,
                 back_setback_mm: setback,
                 groove_width_mm: opts[:groove_width_mm].to_f,
                 groove_depth_mm: groove_d }
      }

      # Stretcher Top Front
      parts << {
        part_name: "#{name} - Stretcher Top Front",
        length_x: internal_w, length_y: stretcher_w, thickness: t,
        origin: [t, 0, h - t],
        xaxis: [1, 0, 0], yaxis: [0, 1, 0],
        attrs: { part_type: "stretcher_top_front", material: "plywood",
                 thickness_mm: t, width_mm: stretcher_w, cabinet_name: name }
      }

      # Stretcher Top Rear
      parts << {
        part_name: "#{name} - Stretcher Top Rear",
        length_x: internal_w, length_y: stretcher_w, thickness: t,
        origin: [t, top_rear_y, h - t],
        xaxis: [1, 0, 0], yaxis: [0, 1, 0],
        attrs: { part_type: "stretcher_top_rear", material: "plywood",
                 thickness_mm: t, width_mm: stretcher_w, cabinet_name: name }
      }

      # Stretcher Rear Vertical
      parts << {
        part_name: "#{name} - Stretcher Rear Vertical",
        length_x: internal_w, length_y: stretcher_w, thickness: t,
        origin: [t, d - t, h],
        xaxis: [1, 0, 0], yaxis: [0, 0, -1],
        attrs: { part_type: "stretcher_rear_vertical", material: "plywood",
                 thickness_mm: t, width_mm: stretcher_w, cabinet_name: name }
      }

      { parts: parts, derived: derived, error: nil }
    end
  end
end