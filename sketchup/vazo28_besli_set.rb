# Besli seramik set - bej sise, kiremit ve bej tabakli kaideler, kiremit ve
# acik bej kadeh vazolar; fotograftaki dizilisle yere yerlestirilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo28_besli_set.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module FiveSet
  extend self

  SCALE = 40.0 / 433.0 # en uzun (tabakli bej) vazo 40 cm
  WALL  = 4.0          # cidar (px)

  # profile: alttan yukari [z, dis yari cap] (px)
  # axis: [z, dx] eksen kaymasi, top: [agiz yuksekligi, egim]
  # depth: agizdan iceri oyuk (tabakli olanlarda sig tabak), size: perspektif payi,
  # pos: [x, y] px
  VASES = [
    {
      name: 'Bej Sise', color: [214, 200, 180], size: 1.04, pos: [-279, 60], depth: 150,
      top: [312, 0.0], axis: [[0, 0], [500, 0]],
      profile: [
        [0, 52], [3, 55], [11, 60], [19, 65], [27, 68], [35, 72], [43, 75],
        [59, 75], [75, 73], [91, 70], [107, 65], [123, 63], [139, 58], [155, 54],
        [171, 50], [187, 45], [203, 40], [219, 35], [235, 29], [251, 24], [267, 18],
        [283, 17], [291, 18], [299, 23], [305, 30], [308, 33], [312, 32]
      ]
    },
    {
      name: 'Kiremit Tabakli', color: [120, 58, 42], size: 1.02, pos: [-127, 70], depth: 22,
      top: [358, 0.0], axis: [[0, 0], [500, 0]],
      profile: [
        [0, 58], [3, 61], [7, 60], [31, 52], [63, 42], [119, 33], [207, 26],
        [295, 22], [303, 48], [311, 67], [319, 74], [335, 77], [351, 78], [358, 78]
      ]
    },
    {
      name: 'Bej Tabakli Uzun', color: [196, 186, 170], size: 1.0, pos: [24, 0], depth: 28,
      top: [433, 0.0], axis: [[0, 0], [500, 0]],
      profile: [
        [0, 62], [4, 64], [8, 63], [16, 62], [24, 59], [40, 57], [72, 50],
        [128, 39.5], [216, 28.5], [312, 18], [340, 19], [360, 20.5], [368, 37], [375, 69],
        [383, 82], [392, 88], [416, 91], [425, 92], [433, 91]
      ]
    },
    {
      name: 'Kiremit Kadeh', color: [132, 58, 44], size: 1.0, pos: [195, 100], depth: 160,
      top: [358, 0.0], axis: [[0, 0], [500, 0]],
      profile: [
        [0, 38], [6, 38], [30, 37], [62, 34], [118, 26.5], [174, 18], [180, 22],
        [195, 40], [215, 55], [240, 62], [262, 63], [300, 59], [318, 56], [350, 52],
        [358, 54]
      ]
    },
    {
      name: 'Acik Bej Kadeh', color: [208, 200, 188], size: 1.0, pos: [275, -20], depth: 120,
      top: [269, 0.0], axis: [[0, 0], [500, 0]],
      profile: [
        [0, 24], [4, 24.5], [18, 24], [34, 23], [50, 21.5], [82, 17.5], [110, 15],
        [118, 16], [122, 24], [130, 31], [138, 43], [146, 50], [154, 55], [170, 57.5],
        [200, 58], [237, 57], [260, 56], [269, 56]
      ]
    }
  ]

  N_AROUND = 96
  N_ROWS   = 80

  # Monoton kubik egri (Fritsch-Carlson): r(z) hic geri katlanmaz
  def smooth_profile(table, per = 6)
    zs = table.map { |z, _| z.to_f }
    rs = table.map { |_, r| r.to_f }
    n = zs.size
    d = (0...n - 1).map { |i| (rs[i + 1] - rs[i]) / (zs[i + 1] - zs[i]) }
    m = Array.new(n) do |i|
      if i.zero? then d[0]
      elsif i == n - 1 then d[-1]
      elsif d[i - 1] * d[i] <= 0 then 0.0
      else (d[i - 1] + d[i]) / 2
      end
    end
    (n - 1).times do |i|
      next if d[i].zero?
      a = m[i] / d[i]
      b = m[i + 1] / d[i]
      s = a * a + b * b
      next unless s > 9
      t = 3 / Math.sqrt(s)
      m[i] = t * a * d[i]
      m[i + 1] = t * b * d[i]
    end
    out = []
    (n - 1).times do |i|
      h = zs[i + 1] - zs[i]
      steps = [[(h / 6.0).ceil, 1].max, per].min
      steps.times do |k|
        t = k.to_f / steps
        h00 = 2 * t**3 - 3 * t**2 + 1
        h10 = t**3 - 2 * t**2 + t
        h01 = -2 * t**3 + 3 * t**2
        h11 = t**3 - t**2
        out << [zs[i] + h * t, h00 * rs[i] + h10 * h * m[i] + h01 * rs[i + 1] + h11 * h * m[i + 1]]
      end
    end
    out << [zs[-1], rs[-1]]
    out
  end

  def interp(pr, z)
    (pr.size - 1).times do |i|
      z0, r0 = pr[i]
      z1, r1 = pr[i + 1]
      next if z1 == z0
      return r0 + (r1 - r0) * (z - z0) / (z1 - z0) if z >= z0 && z <= z1
    end
    z < pr[0][0] ? pr[0][1] : pr[-1][1]
  end

  def point(v, r, phi, z)
    ax = interp(v[:axis].map { |a, b| [a.to_f, b.to_f] }, z)
    [ax + r * Math.cos(phi), r * Math.sin(phi), z]
  end

  def top_z(v, x)
    v[:top][0] + v[:top][1] * x
  end

  # Bu acida meridyenin egik agiz duzlemini kestigi yukseklik
  def find_top(v, phi)
    lo = 0.0
    hi = v[:profile].last[0].to_f
    60.times do
      mid = (lo + hi) / 2
      p = point(v, yield(mid), phi, mid)
      if mid < top_z(v, p[0]) then lo = mid else hi = mid end
    end
    (lo + hi) / 2
  end

  def strip(ring_a, ring_b, list)
    n = ring_a.size
    n.times do |i|
      j = (i + 1) % n
      list << [ring_a[i], ring_b[i], ring_b[j]]
      list << [ring_a[i], ring_b[j], ring_a[j]]
    end
  end

  def fan(center, rg, list, flip = false)
    n = rg.size
    n.times do |i|
      j = (i + 1) % n
      list << (flip ? [center, rg[j], rg[i]] : [center, rg[i], rg[j]])
    end
  end

  # Kapali govde: taban, dis yuz, egik agiz halkasi, ic yuz, ic taban (px)
  def vase_tris(v)
    pr = smooth_profile(v[:profile])
    outer_r = ->(z) { interp(pr, z) }
    inner_r = ->(z) { interp(pr, z) - WALL }
    phis = Array.new(N_AROUND) { |i| 2 * Math::PI * i / N_AROUND }
    tops_o = phis.map { |phi| find_top(v, phi) { |z| outer_r.call(z) } }
    tops_i = phis.map { |phi| find_top(v, phi) { |z| inner_r.call(z) } }
    floor = v[:top][0] - v[:depth]
    outer = Array.new(N_ROWS + 1) do |k|
      phis.each_with_index.map do |phi, i|
        z = tops_o[i] * k / N_ROWS
        point(v, outer_r.call(z), phi, z)
      end
    end
    rows_in = (N_ROWS * v[:depth] / v[:top][0].to_f).ceil
    inner = Array.new(rows_in + 1) do |k|
      phis.each_with_index.map do |phi, i|
        z = tops_i[i] - (tops_i[i] - floor) * k / rows_in
        point(v, inner_r.call(z), phi, z)
      end
    end
    tris = []
    fan(point(v, 0, 0, 0.0), outer[0], tris, true)
    N_ROWS.times { |k| strip(outer[k + 1], outer[k], tris) }
    strip(inner[0], outer[N_ROWS], tris)
    rows_in.times { |k| strip(inner[k + 1], inner[k], tris) }
    fan(point(v, 0, 0, floor), inner[rows_in], tris)
    tris
  end

  def cross(a, b)
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
  end

  def dot(a, b)
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
  end

  def good_triangle?(a, b, c, s)
    e1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]]
    e2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]]
    cr = cross(e1, e2)
    area2 = Math.sqrt(dot(cr, cr))
    edges = [[a, b], [b, c], [c, a]].map { |p, q| Math.sqrt((p[0] - q[0])**2 + (p[1] - q[1])**2 + (p[2] - q[2])**2) }
    edges.min * s > 0.005 && area2 * s * s > 1e-5
  end

  # ---- SketchUp ----
  def add_mesh(ents, tris, mat, s)
    mesh = Geom::PolygonMesh.new(tris.size * 3, tris.size)
    index = {}
    tris.each do |tri|
      next unless good_triangle?(*tri, s)
      ids = tri.map do |v|
        key = v.map { |c| (c * 1e6).round }
        index[key] ||= mesh.add_point(Geom::Point3d.new((v[0] * s).cm, (v[1] * s).cm, (v[2] * s).cm))
      end
      next if ids.uniq.size < 3
      mesh.add_polygon(*ids)
    end
    ents.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE, mat, mat)
  end

  # Yuvarlak yuzlerde ince kenarlari yumusat, agiz kenarlarini keskin birak
  def soften(ents, max_angle)
    ents.grep(Sketchup::Edge).each do |e|
      next unless e.faces.size == 2
      a = e.faces[0].normal.angle_between(e.faces[1].normal)
      if a < max_angle
        e.soft = true
        e.smooth = true
      end
    end
  end

  def material(model, name, rgb)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  def run
    model = Sketchup.active_model
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - besli vazo seti olusturuluyor..."
    model.start_operation('Besli Vazo Seti', true)
    root = model.active_entities.add_group
    root.name = 'Besli Vazo Seti'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Besli_#{v[:name].tr(' ', '_')}", v[:color])
      add_mesh(grp.entities, vase_tris(v), mat, SCALE * v[:size])
      soften(grp.entities, 0.6) # ~35 derece
      x, y = v[:pos].map { |c| c * SCALE }
      grp.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x.cm, y.cm, 0)))
    end
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Set hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

FiveSet.run if defined?(Sketchup)
