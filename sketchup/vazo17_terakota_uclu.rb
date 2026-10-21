# Terakota uclu set - halkali boyunlu iki kadeh vazo ve kase basli vazo;
# fotograftaki dizilisle yere yerlestirilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo17_terakota_uclu.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.
# Ondeki iki vazo kameraya yakin oldugu icin perspektif payi (size) dusuldu.

module TerracottaTrio
  extend self

  SCALE = 30.0 / 408.0 # sol vazo 30 cm
  WALL  = 5.0          # cidar (px)

  # profile: alttan yukari [z, dis yari cap] (px) - halkalar dahil
  # axis: [z, dx] eksenin yana kaymasi (vazo hafif egik duruyorsa)
  # top: [agiz yuksekligi, egim], depth: agizdan iceri derinlik
  # size: perspektif duzeltmesi, pos: [x, y] px
  VASES = [
    {
      name: 'Kadeh Uzun', color: [178, 102, 76], size: 1.0, pos: [-167, 0], depth: 150,
      top: [408, 0.0],
      axis: [[0, 0], [36, 0], [138, -4.5], [200, -6], [300, -9], [420, -9.5]],
      profile: [
        [0, 22], [6, 35], [12, 46], [18, 55], [24, 60.5], [30, 63], [36, 64],
        [60, 60.5], [90, 54.5], [120, 50], [138, 48], [145, 48.5], [152, 46],
        [157, 40], [160, 32], [162, 24], [164, 18], [170, 17.5], [172, 24],
        [175, 30], [183, 30], [186, 22], [188, 18], [193, 18], [196, 24],
        [198, 29.5], [205, 29.5], [207, 23], [209, 17], [216, 16],
        [222, 18.5], [228, 23.5], [234, 29.5], [240, 36], [246, 40],
        [258, 45.5], [270, 49], [282, 52.5], [294, 55], [306, 57], [318, 58],
        [330, 60], [348, 60.5], [366, 60], [378, 59.5], [390, 57],
        [402, 53.5], [408, 51], [420, 50]
      ]
    },
    {
      name: 'Kase Basli', color: [182, 104, 78], size: 0.8969, pos: [-12.6, -209], depth: 70,
      top: [308, 0.0],
      axis: [[0, 0], [400, 0]],
      profile: [
        [0, 20], [3, 28], [9, 43], [15, 54], [21, 62.5], [27, 68.5], [33, 73.5],
        [39, 74], [51, 73], [63, 71.5], [83, 68.5], [93, 66], [123, 66],
        [135, 64.5], [141, 63.5], [147, 58.5], [153, 46.5], [159, 34.5],
        [165, 31], [171, 30], [177, 36], [181, 47], [190, 47], [194, 35],
        [197, 22], [207, 22], [213, 23.5], [219, 26.5], [225, 35.5],
        [231, 42.5], [237, 59], [243, 69.5], [249, 78], [255, 83], [267, 90],
        [280, 89], [300, 87], [308, 86], [320, 85]
      ]
    },
    {
      name: 'Kadeh Genis', color: [180, 104, 80], size: 0.9461, pos: [145.7, -109], depth: 140,
      top: [389, 0.0],
      axis: [[0, 0], [160, 0], [250, 5], [400, 9]],
      profile: [
        [0, 14], [3, 25], [7, 34], [13, 45], [19, 52.5], [31, 61], [49, 62.5],
        [61, 62], [73, 61], [91, 57], [109, 57], [121, 55.5], [133, 53],
        [151, 48.5], [157, 48], [165, 43], [170, 32], [174, 24], [182, 24],
        [186, 32], [189, 46], [200, 46], [203, 40], [206, 32], [209, 40],
        [212, 46.5], [220, 46.5], [223, 35], [226, 21], [241, 21],
        [247, 24.5], [253, 29.5], [259, 35], [265, 42.5], [271, 48],
        [283, 56], [295, 63.5], [307, 68], [319, 71.5], [331, 72.5],
        [343, 73], [355, 72], [367, 71], [373, 67.5], [379, 66],
        [385, 63.5], [391, 62], [400, 61]
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - terakota uclu vazo seti olusturuluyor..."
    model.start_operation('Terakota Uclu Vazo Seti', true)
    root = model.active_entities.add_group
    root.name = 'Terakota Uclu Vazo Seti'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Terakota_#{v[:name].tr(' ', '_')}", v[:color])
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

TerracottaTrio.run if defined?(Sketchup)
