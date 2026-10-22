# Antrasit uclu set - ayakli konik sise, konik kaideli uzun boyunlu vazo ve
# basik genis kase vazo; mat gri, fotograftaki dizilisle yerlestirilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo34_antrasit_uclu.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module SlateTrio
  extend self

  SCALE = 35.0 / 307.0 # uzun boyunlu vazo 35 cm
  WALL  = 5.0          # cidar (px)

  # profile: alttan yukari [z, dis yari cap] (px); basamaklar icin yakin noktalar
  # axis: [z, dx] eksen kaymasi, top: [agiz yuksekligi, egim]
  # depth: agizdan iceri oyuk, size: perspektif payi, pos: [x, y] px
  VASES = [
    {
      name: 'Konik Sise', color: [80, 88, 94], size: 1.0, pos: [-115, 0], depth: 120,
      top: [246, 0.0], axis: [[0, 0], [400, 0]],
      profile: [
        [0, 43], [2, 44], [24, 44], [26, 48], [28, 58], [32, 65], [40, 63],
        [92, 51], [128, 43], [170, 35], [190, 28.5], [196, 26], [230, 26], [246, 26]
      ]
    },
    {
      name: 'Uzun Boyunlu', color: [78, 86, 92], size: 1.06, pos: [0, 150], depth: 180,
      top: [307, 0.0], axis: [[0, 0], [400, 0]],
      profile: [
        [0, 63], [2, 65], [37, 65], [39, 95], [41, 104], [44, 108], [48, 107],
        [54, 103], [60, 96], [66, 87], [72, 78], [78, 62.5], [84, 53], [90, 44.5],
        [96, 33], [100, 30], [200, 29.5], [300, 28.5], [307, 28.5]
      ]
    },
    {
      name: 'Basik Kase', color: [84, 92, 98], size: 0.97, pos: [188, -60], depth: 60,
      top: [108, 0.0], axis: [[0, 0], [400, 0]],
      profile: [
        [0, 118], [2, 125], [6, 130], [14, 134], [22, 135], [45, 135], [62, 133.5],
        [68, 131], [72, 126], [75, 118], [76.5, 72], [78, 66], [80, 64.5], [106, 64.5],
        [108, 64]
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - antrasit uclu vazo seti olusturuluyor..."
    model.start_operation('Antrasit Uclu Vazo Seti', true)
    root = model.active_entities.add_group
    root.name = 'Antrasit Uclu Vazo Seti'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Antrasit_#{v[:name].tr(' ', '_')}", v[:color])
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

SlateTrio.run if defined?(Sketchup)
