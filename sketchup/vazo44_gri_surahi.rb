# Gri surahi - ayakli, keskin kenarli disk govde; uzun silindir boyun, egik agiz;
# boynun ustunden cikip govdeye inen ucgen, kare kesitli kirik kulp.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo44_gri_surahi.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi (x - 266, 612 - y); SCALE ile cm'ye cevrilir.

module GreyPitcher
  extend self

  SCALE = 35.0 / 479.0 # vazo 35 cm

  # Govde + boyun: alttan yukari [z, yari cap] (px); agzi acik, egik kesilmis
  BODY = [
    [0, 57], [3, 59], [28, 58], [32, 62], [40, 76], [55, 101], [70, 123],
    [85, 140], [92, 147], [100, 148], [104, 143], [110, 124], [118, 100], [128, 78],
    [138, 60], [146, 52], [160, 49], [300, 50], [420, 52], [478, 53]
  ]
  WALL  = 6.0
  DEPTH = 330.0 # agizdan iceri oyuk
  TOP_SLOPE = -0.1 # agiz kesimi: saga dogru alcalir (z = tepe + egim * x)

  # Kulp: kare kesitli kirik cizgi [x, z] (px)
  HANDLE_R     = 15.5 # kare kesitin yari kosegeni
  HANDLE_SIDES = 4
  HANDLES = [
    [[30, 446], [96, 434], [142, 410], [76, 160], [42, 136]]
  ]

  BLACK = [118, 120, 126]

  N_AROUND = 128
  N_TUBE   = 24

  # ---------- yardimcilar ----------

  def smooth(pr, per = 4)
    pr = pr.map { |a, b| [a.to_f, b.to_f] }
    out = []
    (pr.size - 1).times do |i|
      p0 = pr[[i - 1, 0].max]
      p1 = pr[i]
      p2 = pr[i + 1]
      p3 = pr[[i + 2, pr.size - 1].min]
      per.times do |k|
        t = k.to_f / per
        out << [0, 1].map do |c|
          0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t +
                 (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t * t +
                 (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t**3)
        end
      end
    end
    out << pr.last
    out
  end

  def ring(r, z, n = N_AROUND)
    Array.new(n) do |i|
      a = 2 * Math::PI * i / n
      [r * Math.cos(a), r * Math.sin(a), z]
    end
  end

  def strip(a, b, list)
    n = a.size
    n.times do |i|
      j = (i + 1) % n
      list << [a[i], b[i], b[j]] << [a[i], b[j], a[j]]
    end
  end

  def fan(center, rg, list, flip = false)
    n = rg.size
    n.times do |i|
      j = (i + 1) % n
      list << (flip ? [center, rg[j], rg[i]] : [center, rg[i], rg[j]])
    end
  end

  def sub(a, b)
    [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
  end

  def cross(a, b)
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
  end

  def dot(a, b)
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
  end

  def norm(a)
    l = Math.sqrt(dot(a, a))
    [a[0] / l, a[1] / l, a[2] / l]
  end

  # ---------- parcalar ----------

  # Ici bos, agzi acik govde
  def body_tris
    pr = smooth(BODY)
    top = pr.last[0]
    outer = pr.map { |z, r| ring(r, z) }
    inner = pr.select { |z, _| z >= top - DEPTH }.reverse.map { |z, r| ring(r - WALL, z) }
    # agiz kenari egik kesim
    slant = ->(rg) { rg.map { |x, y, z| [x, y, z + TOP_SLOPE * x] } }
    outer[-1] = slant.call(outer[-1])
    inner[0] = slant.call(inner[0])
    tris = []
    fan([0.0, 0.0, 0.0], outer.first, tris, true)
    (outer.size - 1).times { |k| strip(outer[k + 1], outer[k], tris) }
    strip(inner.first, outer.last, tris)
    (inner.size - 1).times { |k| strip(inner[k + 1], inner[k], tris) }
    fan([0.0, 0.0, inner.last[0][2]], inner.last, tris)
    tris
  end

  # Kulp: yol boyunca dairesel kesitli boru, uclari kapali
  def handle_tris(path)
    pts = path.map { |x, z| [x.to_f, 0.0, z.to_f] }
    up = [0.0, 1.0, 0.0] # yol x-z duzleminde; y her zaman yola dik
    rings = pts.each_with_index.map do |p, i|
      a = pts[[i - 1, 0].max]
      b = pts[[i + 1, pts.size - 1].min]
      t = norm(sub(b, a))
      u = up
      w = cross(t, u)
      Array.new(HANDLE_SIDES) do |k|
        ang = 2 * Math::PI * k / HANDLE_SIDES + Math::PI / HANDLE_SIDES
        c = Math.cos(ang) * HANDLE_R
        s = Math.sin(ang) * HANDLE_R
        [p[0] + w[0] * c + u[0] * s, p[1] + w[1] * c + u[1] * s, p[2] + w[2] * c + u[2] * s]
      end
    end
    tris = []
    (rings.size - 1).times { |k| strip(rings[k], rings[k + 1], tris) }
    fan(pts.first, rings.first, tris)
    fan(pts.last, rings.last, tris, true)
    orient(tris)
  end

  # Isaretli hacim negatifse ucgenleri ters cevir
  def orient(tris)
    vol = tris.sum { |a, b, c| dot(a, cross(b, c)) }
    vol < 0 ? tris.map(&:reverse) : tris
  end

  # Tum parcalar: [ad, {renk => ucgenler}]
  def parts
    [
      ['Govde', { black: body_tris }],
      ['Kulp', { black: handle_tris(HANDLES[0]) }]
    ]
  end

  # ---------- SketchUp ----------

  def add_mesh(ents, tris, mat)
    mesh = Geom::PolygonMesh.new(tris.size * 3, tris.size)
    index = {}
    tris.each do |tri|
      ids = tri.map do |v|
        key = v.map { |c| (c * 1e4).round }
        index[key] ||= mesh.add_point(Geom::Point3d.new((v[0] * SCALE).cm, (v[1] * SCALE).cm, (v[2] * SCALE).cm))
      end
      next if ids.uniq.size < 3
      mesh.add_polygon(*ids)
    end
    ents.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE, mat, mat)
  end

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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - gri surahi olusturuluyor..."
    list = parts
    model.start_operation('Gri Surahi', true)
    mats = { black: material(model, 'Surahi_Gri', BLACK) }
    root = model.active_entities.add_group
    root.name = 'Gri Surahi'
    list.each do |name, groups|
      grp = root.entities.add_group
      grp.name = name
      groups.each { |key, tris| add_mesh(grp.entities, tris, mats[key]) }
      soften(grp.entities, 0.5) # ~30 derece; kulp ve kenar koseleri keskin kalir
    end
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Surahi hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

GreyPitcher.run if defined?(Sketchup)
