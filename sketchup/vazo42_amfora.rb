# Amfora - ayakli kure govde (ustu kapakli), havada duran bag-kulplu boyun:
# iki kulp govdenin omzundan yukselip boynun agiz kenarini tutar.
# Govdenin alti mavi, ustu metalik siyah; aradaki sinir dalgali.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo42_amfora.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi (x - 585, 1365 - y); SCALE ile cm'ye cevrilir.

module Amphora
  extend self

  SCALE = 40.0 / 720.0 # toplam yukseklik 40 cm

  # Govde: alttan yukari [z, yari cap] (px); ustu duz kapakla kapali
  BODY = [
    [0, 74], [3, 78], [38, 76], [46, 82], [52, 100], [60, 130], [70, 160],
    [85, 178], [105, 199], [145, 228], [185, 245], [225, 254], [265, 257],
    [285, 256], [325, 244], [365, 221], [385, 204], [405, 189], [418, 176],
    [424, 150], [426, 122], [430, 118], [440, 118], [442, 112]
  ]

  # Boyun (havada): alttan yukari [z, yari cap] (px); agzi acik
  NECK = [
    [560, 68], [564, 76], [572, 79], [582, 76], [592, 66], [610, 60], [635, 62],
    [660, 72], [684, 95], [700, 118], [712, 126], [718, 124]
  ]
  NECK_WALL  = 8.0
  NECK_DEPTH = 110.0

  # Kulplar: [x, z] yol noktalari (govde omzundan agiz kenarina), boru yari capi
  HANDLE_R = 17.0
  HANDLES = [
    [[-158, 405], [-168, 440], [-195, 480], [-225, 545], [-250, 615], [-250, 675],
     [-228, 705], [-190, 716], [-150, 712], [-127, 702]],
    [[158, 405], [168, 440], [195, 500], [227, 575], [240, 645], [230, 695],
     [200, 716], [160, 714], [127, 702]]
  ]

  # Renkler; mavi ile siyah arasindaki dalgali sinir (z = taban + dalga)
  BLUE  = [74, 128, 150]
  BLACK = [38, 36, 36]
  WAVE  = [305.0, 16.0, 8.0] # taban z, 3 ve 7 tepeli dalga genlikleri

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

  # Kapali govde (ayakli kure, duz kapak)
  def body_tris
    pr = smooth(BODY)
    rings = pr.map { |z, r| ring(r, z) }
    tris = []
    fan([0.0, 0.0, 0.0], rings.first, tris, true)
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    fan([0.0, 0.0, pr.last[0]], rings.last, tris)
    tris
  end

  # Ici bos, agzi acik boyun
  def neck_tris
    pr = smooth(NECK)
    top = pr.last[0]
    outer = pr.map { |z, r| ring(r, z) }
    inner = pr.select { |z, _| z >= top - NECK_DEPTH }.reverse.map { |z, r| ring(r - NECK_WALL, z) }
    tris = []
    fan([0.0, 0.0, pr.first[0]], outer.first, tris, true)
    (outer.size - 1).times { |k| strip(outer[k + 1], outer[k], tris) }
    strip(inner.first, outer.last, tris)
    (inner.size - 1).times { |k| strip(inner[k + 1], inner[k], tris) }
    fan([0.0, 0.0, inner.last[0][2]], inner.last, tris)
    tris
  end

  # Kulp: yol boyunca dairesel kesitli boru, uclari kapali
  def handle_tris(path)
    pts = smooth(path, 8).map { |x, z| [x, 0.0, z] }
    up = [0.0, 1.0, 0.0] # yol x-z duzleminde; y her zaman yola dik
    rings = pts.each_with_index.map do |p, i|
      a = pts[[i - 1, 0].max]
      b = pts[[i + 1, pts.size - 1].min]
      t = norm(sub(b, a))
      u = up
      w = cross(t, u)
      Array.new(N_TUBE) do |k|
        ang = 2 * Math::PI * k / N_TUBE
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

  # Govde ucgeninin rengi: dalgali sinirin alti mavi
  def body_color(t)
    x = (t[0][0] + t[1][0] + t[2][0]) / 3.0
    y = (t[0][1] + t[1][1] + t[2][1]) / 3.0
    z = (t[0][2] + t[1][2] + t[2][2]) / 3.0
    phi = Math.atan2(y, x)
    edge = WAVE[0] + WAVE[1] * Math.sin(3 * phi + 0.7) + WAVE[2] * Math.sin(7 * phi + 2.1)
    z < edge ? :blue : :black
  end

  # Tum parcalar: [ad, {renk => ucgenler}]
  def parts
    [
      ['Govde', body_tris.group_by { |t| body_color(t) }],
      ['Boyun', { black: orient(neck_tris) }],
      ['Sol Kulp', { black: handle_tris(HANDLES[0]) }],
      ['Sag Kulp', { black: handle_tris(HANDLES[1]) }]
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - amfora olusturuluyor..."
    list = parts
    model.start_operation('Amfora', true)
    mats = { blue: material(model, 'Amfora_Mavi', BLUE), black: material(model, 'Amfora_Siyah', BLACK) }
    root = model.active_entities.add_group
    root.name = 'Amfora'
    list.each do |name, groups|
      grp = root.entities.add_group
      grp.name = name
      groups.each { |key, tris| add_mesh(grp.entities, tris, mats[key]) }
      soften(grp.entities, 0.6) # ~35 derece
    end
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Amfora hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

Amphora.run if defined?(Sketchup)
