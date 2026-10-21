# Dortlu vazo seti - krem sise, gri silindir sise, koyu kahve kure, acik kahve
# iki bogumlu vazo; fotograftaki dizilisle yere yerlestirilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo10_dortlu_set.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module VaseSet
  extend self

  SCALE = 35.0 / 830.0 # gri sise 35 cm
  WALL  = 6.0          # agizdaki cidar (px)

  # profile: alttan yukari [z, dis yari cap] (px)
  # mouth: agiz ic yari capi, depth: agizdan iceri derinlik
  # pos: [x, y] cm, size: on siradakiler fotografta yakin oldugu icin kucultulur
  VASES = [
    {
      name: 'Krem Sise', color: [226, 206, 176], size: 1.0, pos: [-12.0, 8.0],
      mouth: 48, depth: 260,
      profile: [
        [0, 98], [10, 111], [25, 119], [45, 122], [125, 126], [225, 127],
        [325, 126], [375, 123], [425, 116], [465, 106], [525, 90], [575, 77],
        [625, 66], [665, 60], [725, 54], [740, 56], [747, 60], [755, 58]
      ]
    },
    {
      name: 'Gri Sise', color: [142, 127, 112], size: 1.0, pos: [2.5, 12.0],
      mouth: 62, depth: 200,
      profile: [
        [0, 158], [6, 165], [12, 166], [640, 166], [650, 161], [659, 153],
        [667, 141], [675, 121], [683, 92], [687, 79], [715, 77], [815, 76],
        [830, 76]
      ]
    },
    {
      name: 'Koyu Kahve Kure', color: [96, 62, 50], size: 0.93, pos: [-5.0, -10.0],
      mouth: 16, depth: 110,
      profile: [
        [0, 62], [8, 85], [32, 103], [72, 143], [112, 162], [152, 170],
        [192, 172], [232, 170], [272, 160], [312, 138], [332, 118], [352, 85],
        [367, 50], [377, 31], [400, 28], [432, 27]
      ]
    },
    {
      name: 'Acik Kahve Vazo', color: [166, 136, 106], size: 0.93, pos: [12.0, -3.0],
      mouth: 76, depth: 140,
      profile: [
        [0, 68], [10, 82], [40, 112], [70, 128], [110, 135], [150, 134],
        [190, 127], [230, 111], [260, 104], [290, 108], [310, 120], [350, 127],
        [370, 123], [390, 112], [420, 95], [450, 70], [480, 60], [510, 63],
        [530, 73], [550, 82], [562, 90], [570, 88]
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - dortlu vazo seti olusturuluyor..."
    model.start_operation('Dortlu Vazo Seti', true)
    root = model.active_entities.add_group
    root.name = 'Dortlu Vazo Seti'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Set_#{v[:name].tr(' ', '_')}", v[:color])
      add_mesh(grp.entities, vase_tris(v), mat, SCALE * v[:size])
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

VaseSet.run if defined?(Sketchup)
