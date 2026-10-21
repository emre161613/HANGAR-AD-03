# Uclu vazo seti - siyah sise, adacayi yesili kure (huni boyunlu), vizon
# basik kure (bir yani duz kesilmis); fotograftaki dizilisle yere yerlestirilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo11_uclu_set.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module VaseTrio
  extend self

  SCALE = 30.0 / 647.0 # siyah sise 30 cm
  WALL  = 6.0          # agizdaki cidar (px)

  # profile: alttan yukari [z, dis yari cap] (px)
  # mouth: agiz ic yari capi, depth: agizdan iceri derinlik
  # pos: [x, y] cm
  # facet: [nx, ny, nz, uzaklik] - bu duzlemin disinda kalan kisim duz kesilir (px)
  VASES = [
    {
      name: 'Siyah Sise', color: [44, 44, 46], pos: [-7.2, 1.5],
      mouth: 34, depth: 200,
      profile: [
        [0, 70], [2, 80], [12, 113], [22, 121], [40, 122.5], [372, 122.5],
        [382, 121], [412, 114], [432, 106.5], [452, 96], [472, 82], [492, 65],
        [502, 57], [512, 51], [522, 47.5], [542, 45], [592, 44], [616, 44],
        [624, 47], [632, 49], [642, 48.5], [647, 45]
      ]
    },
    {
      name: 'Yesil Kure', color: [124, 133, 120], pos: [-0.8, -9.0],
      mouth: 52, depth: 140,
      profile: [
        [0, 47], [10, 66.8], [25, 86.5], [40, 100.2], [55, 110.3], [70, 117.6],
        [85, 122.6], [100, 125.7], [115, 127], [130, 126.4], [145, 124.1],
        [160, 119.9], [175, 113.5], [190, 104.6], [205, 92.5], [220, 75.7],
        [235, 49.4], [253, 48], [273, 50], [303, 54], [333, 59], [353, 60.5],
        [363, 61], [366, 60]
      ]
    },
    {
      name: 'Vizon Kure', color: [134, 116, 104], pos: [8.2, 2.5],
      mouth: 28, depth: 120,
      facet: [-0.50, -0.75, -0.43, 118.0],
      profile: [
        [0, 55], [7, 73], [17, 95], [27, 109], [37, 119], [47, 127], [57, 132],
        [67, 136], [87, 141], [107, 144], [127, 144], [147, 142], [167, 138],
        [187, 129], [207, 119], [227, 102], [247, 80], [257, 70], [267, 54],
        [272, 44], [285, 41], [297, 41], [305, 43], [309, 41]
      ]
    }
  ]

  N_AROUND = 96

  # Profili yumusat: r(z) icin monoton kubik egri (Fritsch-Carlson).
  # Yukseklik hep artar, bu yuzden yuzey hicbir yerde geri katlanmaz.
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
      steps = [[(h / 12.0).ceil, 1].max, per].min
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

  def ring(r, z)
    Array.new(N_AROUND) do |i|
      a = 2 * Math::PI * i / N_AROUND
      [r * Math.cos(a), r * Math.sin(a), z]
    end
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

  # Kapali donel govde: taban, dis yuz, agiz halkasi, agiz ici, oyuk tabani (px)
  def vase_tris(v)
    pr = smooth_profile(v[:profile])
    top = pr.last[0]
    bottom_in = top - v[:depth]
    # ic yuz: agizda mouth, asagida dis yuzden WALL iceride
    inner = (0..24).map do |k|
      z = top - v[:depth] * k / 24.0
      r = [v[:mouth].to_f, interp(pr, z) - WALL].min
      [z, r]
    end
    rings = pr.map { |z, r| ring(r, z) } + inner.map { |z, r| ring(r, z) }
    tris = []
    fan([0.0, 0.0, 0.0], rings.first, tris, true)
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    fan([0.0, 0.0, bottom_in], rings.last, tris)
    v[:facet] ? tris.map { |t| t.map { |p| flatten(p, v[:facet]) } } : tris
  end

  # Duzlemin disina tasan noktayi duzleme indir (yuzeyin o kismi duz olur)
  def flatten(p, facet)
    nx, ny, nz, d = facet
    l = Math.sqrt(nx * nx + ny * ny + nz * nz)
    n = [nx / l, ny / l, nz / l]
    c = [0.0, 0.0, 120.0] # govdenin merkezi civari
    over = (p[0] - c[0]) * n[0] + (p[1] - c[1]) * n[1] + (p[2] - c[2]) * n[2] - d
    return p if over <= 0
    [p[0] - n[0] * over, p[1] - n[1] * over, p[2] - n[2] * over]
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - uclu vazo seti olusturuluyor..."
    model.start_operation('Uclu Vazo Seti', true)
    root = model.active_entities.add_group
    root.name = 'Uclu Vazo Seti'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Set_#{v[:name].tr(' ', '_')}", v[:color])
      add_mesh(grp.entities, vase_tris(v), mat, SCALE)
      soften(grp.entities, 0.6) # ~35 derece
      x, y = v[:pos]
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

VaseTrio.run if defined?(Sketchup)
