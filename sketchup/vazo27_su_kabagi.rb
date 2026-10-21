# Siyah su kabagi vazo - iki bogumlu (alt buyuk, ust kucuk) kum dokulu vazo,
# ince boyun ve hafif egik agiz; bogumlar hafifce birbirine gore kayik.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo27_su_kabagi.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module GourdVase
  extend self

  SCALE = 30.0 / 484.0 # vazo 30 cm
  WALL  = 6.0          # cidar (px)

  # profile: alttan yukari [z, dis yari cap] (px) - fotograftan her 6 pikselde bir
  # axis: [z, dx] eksen kaymasi (ust bogum saga, alt bogum sola kayik)
  # top: [agiz yuksekligi, egim], depth: agiz derinligi, size, pos: [x, y] px
  VASES = [
    {
      name: 'Siyah Su Kabagi', color: [40, 40, 40], size: 1.0, pos: [0, 0], depth: 150,
      top: [482, 0.06],
      axis: [
        [0, 0], [17, 0.0], [41, -1.0], [65, -3.5], [89, -4.5], [113, -4.5], [137, -5.0],
        [161, -2.0], [185, -3.0], [209, -2.5], [233, -1.5], [257, 0.5], [281, 33.5], [305, 30.0],
        [329, 30.5], [353, 31.5], [377, 31.0], [401, 28.0], [425, 16.5], [449, 15.0], [473, 15.0],
        [484, 15]
      ],
      profile: [
        [0, 40], [2, 46], [5, 49.5], [9, 51], [13, 52], [17, 52.0], [23, 53.0],
        [29, 55.0], [35, 57.5], [41, 60.0], [47, 63.5], [53, 67.0], [59, 71.0], [65, 75.5],
        [71, 80.0], [77, 84.5], [83, 89.0], [89, 93.5], [95, 98.0], [101, 102.0], [107, 106.0],
        [113, 109.5], [119, 113.5], [125, 117.0], [131, 120.0], [137, 122.0], [143, 124.0], [149, 125.5],
        [155, 127.0], [161, 126.0], [167, 128.0], [173, 127.5], [179, 128.5], [185, 128.0], [191, 126.0],
        [197, 123.5], [203, 123.0], [209, 120.5], [215, 116.5], [221, 113.0], [227, 108.5], [233, 103.5],
        [239, 97.5], [245, 88.5], [251, 79.0], [257, 69.5], [263, 58.5], [269, 66.0], [275, 73.0],
        [281, 80.5], [287, 88.5], [293, 94.5], [299, 98.5], [305, 102.0], [311, 104.0], [317, 104.5],
        [323, 105.5], [329, 105.5], [335, 102.0], [341, 105.0], [347, 103.5], [353, 101.5], [359, 99.5],
        [365, 97.0], [371, 93.5], [377, 88.0], [383, 82.5], [389, 74.5], [395, 64.5], [401, 54.0],
        [407, 42.0], [413, 34.5], [419, 30.0], [425, 27.5], [431, 25.5], [437, 24.0], [443, 23.0],
        [449, 23.0], [455, 23.0], [461, 23.0], [467, 23.5], [473, 24.0], [479, 24.5], [484, 24]
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - su kabagi vazo olusturuluyor..."
    model.start_operation('Siyah Su Kabagi Vazo', true)
    root = model.active_entities.add_group
    root.name = 'Siyah Su Kabagi Vazo'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Kabak_#{v[:name].tr(' ', '_')}", v[:color])
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

GourdVase.run if defined?(Sketchup)
