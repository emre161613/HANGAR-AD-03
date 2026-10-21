# Dalgali agizli yumurta vazolar - gri, siyah ve krem; ince cidarli,
# agiz kenari dalgali kesilmis uc vazo; fotograftaki dizilisle yerlestirilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo18_dalgali_agiz.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.
# Kameraya uzak/yakin duran vazolar icin perspektif payi (size) uygulandi.

module WavyRims
  extend self

  SCALE = 50.0 / 535.0 # siyah vazo ~50 cm
  WALL  = 4.0          # cidar (px)

  # profile: alttan yukari [z, dis yari cap] (px)
  # rim: dalgali agiz kenari [z0, a, b, c, d] (fotograftaki kenar cizgisine uyduruldu) ->
  #      yukseklik = z0 + a*cos(t) + b*sin(t) + c*cos(2t) + d*sin(2t)  (t: +X'ten aci, +Y arka)
  # depth: agizdan iceri derinlik, size: perspektif duzeltmesi, pos: [x, y] px
  VASES = [
    {
      name: 'Gri Yumurta', color: [196, 190, 182], size: 0.9690, pos: [-295, -47], depth: 300,
      rim: [356.3, 11.1, 11.1, -2.4, -10.4],
      axis: [[0, 0], [400, 0]],
      profile: [
        [0, 27], [7, 47.5], [22, 62.5], [42, 76.5], [62, 87.5], [102, 102.5],
        [142, 111], [202, 117], [262, 117.5], [302, 115], [342, 108],
        [372, 103], [400, 99]
      ]
    },
    {
      name: 'Siyah Yumurta', color: [52, 52, 54], size: 1.0, pos: [16, 0], depth: 450,
      rim: [524.7, -16.7, 19.6, -0.7, -3.7],
      axis: [[0, 0], [600, 0]],
      profile: [
        [0, 46], [8, 62], [20, 76], [45, 90], [75, 107], [120, 131.5], [165, 145.5],
        [225, 154.5], [285, 157], [360, 153.5], [420, 146.5], [480, 135.5],
        [525, 119], [560, 105]
      ]
    },
    {
      name: 'Krem Uzun', color: [222, 214, 196], size: 1.0627, pos: [332, 94], depth: 400,
      rim: [463.9, 28.8, 10.5, 1.2, -7.2],
      axis: [[0, 0], [520, 0]],
      profile: [
        [0, 30], [8, 42], [20, 53], [40, 66.5], [60, 75.5], [100, 82.5],
        [160, 86], [240, 86.5], [340, 86], [440, 86.5], [480, 86], [520, 84]
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

  def top_z(v, phi)
    z0, a, b, c, d = v[:rim]
    z0 + a * Math.cos(phi) + b * Math.sin(phi) + c * Math.cos(2 * phi) + d * Math.sin(2 * phi)
  end

  # Bu acida meridyenin dalgali agiz kenarina ulastigi yukseklik
  def find_top(v, phi)
    top_z(v, phi)
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
    floor = v[:rim][0] - v[:depth]
    outer = Array.new(N_ROWS + 1) do |k|
      phis.each_with_index.map do |phi, i|
        z = tops_o[i] * k / N_ROWS
        point(v, outer_r.call(z), phi, z)
      end
    end
    rows_in = (N_ROWS * v[:depth] / v[:rim][0].to_f).ceil
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - dalgali agizli vazolar olusturuluyor..."
    model.start_operation('Dalgali Agizli Vazolar', true)
    root = model.active_entities.add_group
    root.name = 'Dalgali Agizli Vazolar'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Dalgali_#{v[:name].tr(' ', '_')}", v[:color])
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

WavyRims.run if defined?(Sketchup)
