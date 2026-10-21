# Uclu koyu seramik set - kase basli uzun vazo, kup basli vazo, basik
# disk basli kucuk vazo; fotograftaki dizilisle yere yerlestirilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo14_koyu_uclu.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.
# Ondeki iki vazo kameraya yakin oldugu icin perspektif payi (size) dusuldu.

module DarkTrio
  extend self

  SCALE = 45.0 / 753.0 # uzun vazo 45 cm
  WALL  = 7.0          # agizdaki cidar (px)

  # profile: alttan yukari [z, dis yari cap] (px)
  # mouth: agiz ic yari capi, depth: agizdan iceri derinlik
  # size: perspektif duzeltmesi, pos: [x, y] cm
  VASES = [
    {
      name: 'Kase Basli Uzun', color: [74, 66, 62], size: 1.0, pos: [0.0, 0.0],
      mouth: 104, depth: 230,
      profile: [
        [0, 95], [8, 108], [18, 114], [28, 116], [178, 117], [308, 109],
        [328, 107], [348, 104], [368, 99], [388, 94], [398, 90], [418, 83],
        [438, 77], [458, 69], [468, 65.5], [478, 64.5], [488, 74], [498, 88],
        [508, 104], [518, 117], [528, 128.5], [538, 138], [548, 145.5],
        [558, 151], [568, 155], [578, 157.5], [588, 160], [608, 162.5],
        [618, 162.5], [628, 162], [638, 160.5], [648, 158], [658, 156],
        [668, 152], [678, 148], [688, 144], [698, 140], [708, 135.5],
        [718, 131], [728, 126], [738, 121.5], [748, 112.5], [753, 110]
      ]
    },
    {
      name: 'Kup Basli', color: [76, 68, 64], size: 0.9302, pos: [14.2, -14.6],
      mouth: 158, depth: 220,
      profile: [
        [0, 45], [5, 64], [15, 93.5], [25, 102], [45, 107.5], [65, 109],
        [105, 112], [125, 112], [145, 110.5], [165, 108], [185, 102],
        [195, 95.5], [205, 84.5], [215, 68], [225, 70], [235, 92.5],
        [245, 113.5], [255, 130], [265, 141], [275, 152], [285, 160],
        [295, 164], [305, 166], [320, 166.5], [537, 166.5]
      ]
    },
    {
      name: 'Disk Basli Kucuk', color: [80, 72, 68], size: 0.9091, pos: [-11.6, -19.0],
      mouth: 45, depth: 150,
      profile: [
        [0, 70], [12, 112], [32, 122], [52, 124], [172, 124], [182, 121],
        [192, 116], [197, 110], [207, 95], [214, 86], [222, 92], [232, 110],
        [242, 124], [252, 139], [262, 152], [272, 162], [282, 169],
        [292, 175], [302, 177], [312, 178], [322, 178], [332, 175],
        [342, 170], [352, 164], [362, 157], [372, 148], [382, 137],
        [392, 123], [402, 104], [409, 75], [414, 52]
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - koyu uclu vazo seti olusturuluyor..."
    model.start_operation('Koyu Uclu Vazo Seti', true)
    root = model.active_entities.add_group
    root.name = 'Koyu Uclu Vazo Seti'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Koyu_#{v[:name].tr(' ', '_')}", v[:color])
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

DarkTrio.run if defined?(Sketchup)
