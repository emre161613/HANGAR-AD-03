# Kum saati vazo - genis kase ust, ince asimetrik boyun, can gibi genisleyen
# govde; kaba dokulu kirmizi kil.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo21_kum_saati.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module HourglassVase
  extend self

  SCALE = 30.0 / 770.0 # vazo 30 cm
  WALL  = 10.0         # cidar (px)

  # profile: alttan yukari [z, yari cap] (px)
  # axis: [z, dx] eksen kaymasi - fotograftaki asimetrik boyun ve kase alti
  # flat: derinlik/genislik orani (1 = yuvarlak kesit, kucuk = yassi vazo)
  # depth: agizdan iceri oyuk, lift: taban yuksekligi, pos: [x, y] px
  VASES = [
    {
      name: 'Kum Saati Vazo', color: [140, 62, 46], size: 1.0, pos: [0, 0], lift: 0,
      depth: 210, flat: 1.0,
      top: [770, 0.0],
      axis: [
        [0, 0], [345, 3], [425, -1], [445, -10], [465, -22], [485, -30],
        [499, -36], [511, -28], [525, -12], [545, 2], [585, 10], [625, 15],
        [800, 17]
      ],
      profile: [
        [0, 194], [4, 198.5], [10, 199], [65, 196], [125, 192], [185, 183.5],
        [245, 171], [305, 154.5], [365, 131.5], [385, 120], [405, 104],
        [425, 87], [445, 67.5], [465, 56.5], [475, 56], [485, 59], [493, 72],
        [499, 88], [505, 105], [511, 130], [517, 153], [525, 174], [545, 198],
        [565, 209.5], [585, 216], [625, 221], [665, 221.5], [705, 220.5],
        [745, 218.5], [760, 215.5], [766, 211], [770, 205]
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
    [ax + r * Math.cos(phi), (v[:flat] || 1.0) * r * Math.sin(phi), z]
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
    top = pr.last[0]
    phis = Array.new(N_AROUND) { |i| 2 * Math::PI * i / N_AROUND }
    ring = ->(r, z) { phis.map { |phi| point(v, r, phi, z) } }
    # satirlar profilin kendi noktalarinda: basamaklar keskin kalir
    outer = pr.map { |z, r| ring.call(r, z) }
    tris = []
    fan(point(v, 0, 0, 0.0), outer[0], tris, true)
    (outer.size - 1).times { |k| strip(outer[k + 1], outer[k], tris) }
    if v[:depth].zero?
      fan(point(v, 0, 0, top), outer.last, tris)
      return tris
    end
    floor = top - v[:depth]
    inner = pr.select { |z, _| z >= floor }.reverse.map { |z, r| ring.call(r - WALL, z) }
    inner << ring.call(interp(pr, floor) - WALL, floor) unless pr.any? { |z, _| z == floor }
    strip(inner[0], outer.last, tris)
    (inner.size - 1).times { |k| strip(inner[k + 1], inner[k], tris) }
    fan(point(v, 0, 0, floor), inner.last, tris)
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - kum saati vazo olusturuluyor..."
    model.start_operation('Kum Saati Vazo', true)
    root = model.active_entities.add_group
    root.name = 'Kum Saati Vazo'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "KumSaati_#{v[:name].tr(' ', '_')}", v[:color])
      add_mesh(grp.entities, vase_tris(v), mat, SCALE * v[:size])
      soften(grp.entities, 0.6) # ~35 derece
      x, y = v[:pos].map { |c| c * SCALE }
      lift = v[:lift] * SCALE
      grp.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x.cm, y.cm, lift.cm)))
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

HourglassVase.run if defined?(Sketchup)
