# frozen_string_literal: true

# Cabinet Maker v0.7
# Fixes:
# - v0.3: Back panel origin corrected (occludes rear horizontal stretcher)
# - v0.4: Rear vertical stretcher top now coplanar with side tops
# - v0.5: Version number shown in menu items
# - v0.6: Back panel width/height includes groove depth (let into sides + bottom)
# - v0.7: Version stamped in cutlist CSV output and default filename
#
# Frameless cabinet generator (metric) with:
# - 18mm sides & bottom
# - No top panel
# - (2) top stretchers (front + rear), 18mm thick x 100mm wide
# - (1) rear vertical stretcher behind the back, same size as the top stretchers
# - 6mm back panel captured in grooves in sides + bottom
# - Back panel plane set 18mm in from cabinet back edge (default)
# - Cutlist export to CSV
#
# SketchUp Pro 2025/2026 (Mac/Win). Install in Plugins folder for permanence.

require "sketchup"
require "csv"

module CabinetMaker
  extend self

  PLUGIN_NAME = "Cabinet Maker"
  VERSION = "0.7"
  DICT = "cabinet_maker"

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

  # ---------- Units ----------
  def mm(x)
    x.to_f.mm
  end

  def to_mm(len)
    (len.to_f / 1.mm)
  end

  # ---------- UI ----------
  def menu
    UI.menu("Extensions").add_submenu("#{PLUGIN_NAME} v#{VERSION}")
  end

  def prompt_new_cabinet
    prompts = [
      "Name",
      "Outside width (mm)",
      "Side height (mm)",
      "Outside depth (mm)",
      "Case thickness (mm)",
      "Back thickness (mm)",
      "Back groove width (mm)",
      "Back groove depth (mm)",
      "Back setback from rear edge (mm)",
      "Stretcher width (mm)"
    ]

    defaults = [
      DEFAULTS[:name],
      DEFAULTS[:width_mm],
      DEFAULTS[:height_mm],
      DEFAULTS[:depth_mm],
      DEFAULTS[:case_thk_mm],
      DEFAULTS[:back_thk_mm],
      DEFAULTS[:groove_width_mm],
      DEFAULTS[:groove_depth_mm],
      DEFAULTS[:back_setback_mm],
      DEFAULTS[:stretcher_width_mm]
    ]

    input = UI.inputbox(prompts, defaults, "New Frameless Cabinet")
    return unless input

    opts = {
      name: input[0].to_s,
      width_mm: input[1].to_f,
      height_mm: input[2].to_f,
      depth_mm: input[3].to_f,
      case_thk_mm: input[4].to_f,
      back_thk_mm: input[5].to_f,
      groove_width_mm: input[6].to_f,
      groove_depth_mm: input[7].to_f,
      back_setback_mm: input[8].to_f,
      stretcher_width_mm: input[9].to_f
    }

    make_frameless_cabinet(opts)
  end

  def prompt_export_cutlist
    model = Sketchup.active_model
    default_name = "cutlist_v#{VERSION}.csv"
    path = UI.savepanel("Export Cutlist CSV", nil, default_name)
    return unless path

    rows = collect_cutlist_rows(model)
    export_cutlist_csv(path, rows)

    UI.messagebox("Exported cutlist:\n#{path}\n\nRows: #{rows.length}")
  end

  # ---------- Geometry helpers ----------
  def add_part_component(parent_ents, part_name, length_x, length_y, thickness_z, origin, xaxis, yaxis)
    model = Sketchup.active_model
    defs = model.definitions

    definition = defs.add(part_name)
    e = definition.entities

    pts = [
      ORIGIN,
      Geom::Point3d.new(length_x, 0, 0),
      Geom::Point3d.new(length_x, length_y, 0),
      Geom::Point3d.new(0, length_y, 0)
    ]
    face = e.add_face(pts)
    face.reverse! if face.normal.z < 0
    face.pushpull(thickness_z)

    tr = Geom::Transformation.axes(origin, xaxis, yaxis)
    parent_ents.add_instance(definition, tr)
  end

  def set_attrs(inst, attrs = {})
    attrs.each { |k, v| inst.set_attribute(DICT, k.to_s, v) }
  end

  def cabinet_group_entities
    model = Sketchup.active_model
    model.active_entities.add_group
  end

  # ---------- Cabinet builder ----------
  def make_frameless_cabinet(opts)
    model = Sketchup.active_model
    model.start_operation("Make Frameless Cabinet", true)

    name = opts[:name]

    w = mm(opts[:width_mm])
    h = mm(opts[:height_mm])
    d = mm(opts[:depth_mm])

    t = mm(opts[:case_thk_mm])
    bt = mm(opts[:back_thk_mm])

    groove_w = mm(opts[:groove_width_mm])
    groove_d = mm(opts[:groove_depth_mm])

    setback = mm(opts[:back_setback_mm])
    stretcher_w = mm(opts[:stretcher_width_mm])

    # Derived
    internal_w = w - 2.0 * t

    # Back panel actual size (extends into grooves in sides and bottom)
    back_panel_w = internal_w + 2.0 * groove_d
    back_panel_h = (h - t) + groove_d

    # Back plane Y coordinate (measured from cabinet front at Y=0):
    back_panel_back_face_y = d - setback
    back_panel_front_face_y = back_panel_back_face_y - bt

    if internal_w <= 0
      UI.messagebox("Width too small relative to case thickness.")
      model.abort_operation
      return
    end

    if back_panel_back_face_y <= 0 || back_panel_back_face_y >= d
      UI.messagebox("Back setback places the back plane outside cabinet depth. Check setback and depth.")
      model.abort_operation
      return
    end

    # Create container group
    g = cabinet_group_entities
    g.name = name
    ents = g.entities

    # Coordinate convention:
    # X = width (left to right)
    # Y = depth (front to back)
    # Z = height (bottom to top)

    # ----- Sides -----
    left = add_part_component(
      ents,
      "#{name} - Side L",
      d, h, t,
      Geom::Point3d.new(0, 0, 0),
      Geom::Vector3d.new(0, 1, 0),
      Geom::Vector3d.new(0, 0, 1)
    )
    set_attrs(left,
      part_type: "side",
      material: "plywood",
      thickness_mm: opts[:case_thk_mm],
      cabinet_name: name
    )

    right = add_part_component(
      ents,
      "#{name} - Side R",
      d, h, t,
      Geom::Point3d.new(w - t, 0, 0),
      Geom::Vector3d.new(0, 1, 0),
      Geom::Vector3d.new(0, 0, 1)
    )
    set_attrs(right,
      part_type: "side",
      material: "plywood",
      thickness_mm: opts[:case_thk_mm],
      cabinet_name: name
    )

    # ----- Bottom -----
    bottom = add_part_component(
      ents,
      "#{name} - Bottom",
      internal_w, d, t,
      Geom::Point3d.new(t, 0, 0),
      Geom::Vector3d.new(1, 0, 0),
      Geom::Vector3d.new(0, 1, 0)
    )
    set_attrs(bottom,
      part_type: "bottom",
      material: "plywood",
      thickness_mm: opts[:case_thk_mm],
      cabinet_name: name
    )

    # ----- Back panel -----
    # Panel is let into grooves in both sides (groove_d each side) and bottom (groove_d).
    back = add_part_component(
      ents,
      "#{name} - Back",
      back_panel_w, back_panel_h, bt,
      Geom::Point3d.new(t - groove_d, back_panel_back_face_y, t - groove_d),
      Geom::Vector3d.new(1, 0, 0),
      Geom::Vector3d.new(0, 0, 1)
    )
    set_attrs(back,
      part_type: "back",
      material: "plywood_6mm",
      thickness_mm: opts[:back_thk_mm],
      cabinet_name: name,
      back_setback_mm: opts[:back_setback_mm],
      groove_width_mm: opts[:groove_width_mm],
      groove_depth_mm: opts[:groove_depth_mm]
    )

    # ----- Stretchers -----
    # Top front stretcher (horizontal)
    top_front = add_part_component(
      ents,
      "#{name} - Stretcher Top Front",
      internal_w, stretcher_w, t,
      Geom::Point3d.new(t, 0, h - t),
      Geom::Vector3d.new(1, 0, 0),
      Geom::Vector3d.new(0, 1, 0)
    )
    set_attrs(top_front,
      part_type: "stretcher_top_front",
      material: "plywood",
      thickness_mm: opts[:case_thk_mm],
      width_mm: opts[:stretcher_width_mm],
      cabinet_name: name
    )

    # Top rear stretcher (horizontal): back edge touches front face of back panel
    top_rear_y = back_panel_front_face_y - stretcher_w
    top_rear = add_part_component(
      ents,
      "#{name} - Stretcher Top Rear",
      internal_w, stretcher_w, t,
      Geom::Point3d.new(t, top_rear_y, h - t),
      Geom::Vector3d.new(1, 0, 0),
      Geom::Vector3d.new(0, 1, 0)
    )
    set_attrs(top_rear,
      part_type: "stretcher_top_rear",
      material: "plywood",
      thickness_mm: opts[:case_thk_mm],
      width_mm: opts[:stretcher_width_mm],
      cabinet_name: name
    )

    # Rear vertical stretcher (behind back panel):
    # - Back face flush with cabinet back (Y = d)
    # - Front face touches back panel back face
    # - Top flush with top of sides (Z = h)
    rear_vert = add_part_component(
      ents,
      "#{name} - Stretcher Rear Vertical",
      internal_w, stretcher_w, t,
      Geom::Point3d.new(t, d - t, h),
      Geom::Vector3d.new(1, 0, 0),
      Geom::Vector3d.new(0, 0, -1)
    )
    set_attrs(rear_vert,
      part_type: "stretcher_rear_vertical",
      material: "plywood",
      thickness_mm: opts[:case_thk_mm],
      width_mm: opts[:stretcher_width_mm],
      cabinet_name: name
    )

    if (opts[:back_setback_mm].to_f - opts[:case_thk_mm].to_f).abs > 0.01
      UI.messagebox("Note: Your back setback (#{opts[:back_setback_mm]}mm) differs from case thickness (#{opts[:case_thk_mm]}mm).\nThe back sandwich alignment is cleanest when setback == case thickness.")
    end

    # Tag cabinet group with metadata
    g.set_attribute(DICT, "cabinet_name", name)
    g.set_attribute(DICT, "width_mm", opts[:width_mm])
    g.set_attribute(DICT, "height_mm", opts[:height_mm])
    g.set_attribute(DICT, "depth_mm", opts[:depth_mm])

    model.commit_operation
    g
  rescue => e
    model.abort_operation
    UI.messagebox("Cabinet Maker error:\n#{e.class}: #{e.message}\n\n#{e.backtrace.first}")
    raise
  end

  # ---------- Cutlist ----------
  def collect_cutlist_rows(model)
    rows = []

    stack = model.entities.to_a
    until stack.empty?
      ent = stack.pop

      if ent.is_a?(Sketchup::Group)
        stack.concat(ent.entities.to_a)
        next
      end

      if ent.is_a?(Sketchup::ComponentInstance)
        dict = ent.attribute_dictionary(DICT, false)
        if dict
          bb = ent.bounds
          dims = [
            to_mm(bb.width),
            to_mm(bb.depth),
            to_mm(bb.height)
          ].sort.reverse

          rows << {
            part_name: ent.definition.name,
            cabinet_name: ent.get_attribute(DICT, "cabinet_name"),
            part_type: ent.get_attribute(DICT, "part_type"),
            material: ent.get_attribute(DICT, "material"),
            thickness_mm: ent.get_attribute(DICT, "thickness_mm"),
            length_mm: dims[0].round(2),
            width_mm: dims[1].round(2),
            depth_mm: dims[2].round(2)
          }
        end
      end
    end

    rows
  end

  def export_cutlist_csv(path, rows)
    grouped = rows.group_by do |r|
      [r[:cabinet_name], r[:material], r[:part_type], r[:thickness_mm], r[:length_mm], r[:width_mm], r[:depth_mm]]
    end

    CSV.open(path, "w") do |csv|
      csv << ["# Cabinet Maker v#{VERSION} cutlist"]
      csv << ["Cabinet", "Material", "Part Type", "Qty", "Thickness (mm)", "L (mm)", "W (mm)", "T (mm)", "Example Part Name"]
      grouped.each do |key, items|
        cabinet, material, part_type, thk, l, w, t = key
        csv << [cabinet, material, part_type, items.length, thk, l, w, t, items.first[:part_name]]
      end
    end
  end

  # ---------- Register menus ----------
  unless file_loaded?(__FILE__)
    menu.add_item("New Frameless Cabinet (Stretchers + Dado Back)") { prompt_new_cabinet }
    menu.add_separator
    menu.add_item("Export Cutlist CSV") { prompt_export_cutlist }
    file_loaded(__FILE__)
  end
end