# Pencereli ikiz vazo - beyaz, ince uzun iki vazo; on yuzlerinde oval
# pencere, icleri turuncu sirli. Ince cidarli, agizlari acik.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo33_pencereli_ikiz.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module WindowPair
  extend self

  SCALE = 50.0 / 396.0 # soldaki vazo 50 cm
  WALL  = 4.0          # cidar kalinligi (px)
  STEP  = 3.0          # profil boyunca satir araligi (px)
  N_AROUND = 128
  INNER_COLOR = [214, 92, 34] # ic yuzey (turuncu sir)

  # profile: alttan yukari [z, yari cap, eksen x kaymasi] (px)
  # closed: true = ustu kapali, false = agzi acik
  # holes: [aci (derece; -90 = tam on), merkez z, yari genislik, yari yukseklik, egim (derece)] (px)
  # pos: [x, y] px
  VASES = [
    {
      name: 'Genis Pencereli', color: [236, 236, 236], pos: [0, 0], closed: false,
      profile: [
        [0, 38, 0], [3, 41, 0], [15, 42, 0], [40, 45, 0], [80, 48, 3], [120, 50, 5],
        [160, 54, 4], [190, 57, 2], [220, 58, -2], [260, 58, -2], [280, 55, 0],
        [300, 47, 2], [320, 36, 5], [340, 25, 5], [370, 19, 3], [396, 16.5, 3.5]
      ],
      holes: [[-79, 248, 46, 32, 22]]
    },
    {
      name: 'Dar Pencereli', color: [236, 236, 236], pos: [100, 90], closed: false,
      profile: [
        [0, 25, 0], [3, 27, 0], [10, 28.5, 0], [30, 32, -1], [60, 38, -2], [90, 42.5, -3],
        [130, 43.5, -3], [170, 42, -3], [210, 37, -2], [240, 31, 0], [270, 23, 2],
        [300, 18.5, 3], [330, 21.5, 3], [360, 24, 3], [388, 25, 3]
      ],
      holes: [[-79, 148, 28, 62, -4]]
    }
  ]

  # ---------- profil ----------

  # Olculen noktalardan duzgun profil: [r, z, cx] listesi, yay uzunlugu esit aralikli,
  # alt merkezden baslar (ve kapali vazoda ust merkezde biter)
  def outer_polyline(v)
    pr = v[:profile]
    dense = []
    (pr.size - 1).times do |i|
      z0, r0, c0 = pr[i]
      z1, r1, c1 = pr[i + 1]
      6.times do |k|
        t = k / 6.0
        dense << [r0 + (r1 - r0) * t, z0 + (z1 - z0) * t, c0 + (c1 - c0) * t]
      end
    end
    dense << [pr.last[1].to_f, pr.last[0].to_f, pr.last[2].to_f]
    dense = chaikin(dense, 3)
    pts = [[0.0, 0.0, dense.first[2]]] + dense
    resample(pts)
  end

  # Kose yumusatma (ilk/son nokta sabit)
  def chaikin(pts, n)
    n.times do
      out = [pts.first]
      (pts.size - 1).times do |i|
        a = pts[i]
        b = pts[i + 1]
        out << a.zip(b).map { |p, q| 0.75 * p + 0.25 * q }
        out << a.zip(b).map { |p, q| 0.25 * p + 0.75 * q }
      end
      out << pts.last
      pts = out
    end
    pts
  end

  def resample(pts)
    len = [0.0]
    (1...pts.size).each { |i| len << len[-1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]) }
    n = [(len[-1] / STEP).ceil, 2].max
    out = []
    k = 0
    (0..n).each do |m|
      target = len[-1] * m / n
      k += 1 while k < pts.size - 2 && len[k + 1] < target
      t = len[k + 1] == len[k] ? 0 : (target - len[k]) / (len[k + 1] - len[k])
      out << pts[k].zip(pts[k + 1]).map { |p, q| p + (q - p) * t }
    end
    out
  end

  # Ic yuzey: her noktayi profil normali boyunca WALL kadar iceri kaydir (gonye ile)
  def inner_polyline(outer, closed)
    n = outer.size
    outer.each_with_index.map do |(r, z, c), i|
      if i.zero?
        next [0.0, z + WALL, c]
      elsif i == n - 1 && closed
        next [0.0, z - WALL, c]
      end
      a = outer[[i - 1, 0].max]
      b = outer[[i + 1, n - 1].min]
      n1 = seg_normal(a, [r, z])
      n2 = seg_normal([r, z], b)
      nx = n1[0] + n2[0]
      nz = n1[1] + n2[1]
      l = Math.hypot(nx, nz)
      nx /= l
      nz /= l
      d = WALL / [nx * n1[0] + nz * n1[1], 0.3].max
      [[r - nx * d, 0.0].max, z - nz * d, c]
    end
  end

  # Profil parcasinin disa bakan normali (r, z duzleminde)
  def seg_normal(a, b)
    dr = b[0] - a[0]
    dz = b[1] - a[1]
    l = Math.hypot(dr, dz)
    l = 1.0 if l.zero?
    [dz / l, -dr / l]
  end

  # ---------- yuzey parametreleri ----------

  def lerp_row(poly, u)
    i = [[u.floor, 0].max, poly.size - 2].min
    t = u - i
    poly[i].zip(poly[i + 1]).map { |p, q| p + (q - p) * t }
  end

  def point(poly, u, phi)
    r, z, c = lerp_row(poly, u)
    [c + r * Math.cos(phi), r * Math.sin(phi), z]
  end

  def wrap(a)
    a = (a + Math::PI) % (2 * Math::PI) - Math::PI
    a
  end

  # Delik ici mi: (u, phi) noktasinin elips degeri (<1 icerde)
  def hole_value(outer, arclen, hole, u, phi)
    deg, zc, a, b, tilt = hole
    uc = u_at_z(outer, zc)
    r = lerp_row(outer, u)[0]
    s = wrap(phi - deg * Math::PI / 180) * r
    t = arc_at(arclen, u) - arc_at(arclen, uc)
    s, t = rotate(s, t, tilt)
    (s / a)**2 + (t / b)**2
  end

  def arc_lengths(poly)
    len = [0.0]
    (1...poly.size).each { |i| len << len[-1] + Math.hypot(poly[i][0] - poly[i - 1][0], poly[i][1] - poly[i - 1][1]) }
    len
  end

  def arc_at(len, u)
    i = [[u.floor, 0].max, len.size - 2].min
    len[i] + (len[i + 1] - len[i]) * (u - i)
  end

  def u_at_arc(len, s)
    i = 0
    i += 1 while i < len.size - 2 && len[i + 1] < s
    i + (s - len[i]) / (len[i + 1] - len[i])
  end

  def u_at_z(poly, z)
    i = 0
    i += 1 while i < poly.size - 2 && poly[i + 1][1] < z
    i + (z - poly[i][1]) / (poly[i + 1][1] - poly[i][1])
  end

  # Delik eksenlerini egim kadar dondur (yuzey uzerinde, derece)
  def rotate(s, t, tilt)
    return [s, t] unless tilt
    a = tilt * Math::PI / 180
    [s * Math.cos(a) + t * Math.sin(a), -s * Math.sin(a) + t * Math.cos(a)]
  end

  # ---------- govde ----------

  def vase_tris(v)
    outer = outer_polyline(v)
    inner = inner_polyline(outer, v[:closed])
    arclen = arc_lengths(outer)
    rows = outer.size
    phis = Array.new(N_AROUND) { |j| -Math::PI + 2 * Math::PI * j / N_AROUND }
    dphi = 2 * Math::PI / N_AROUND

    # hangi hucreler silinecek
    removed = Array.new(rows - 1) do |i|
      Array.new(N_AROUND) do |j|
        u = i + 0.5
        phi = phis[j] + dphi / 2
        v[:holes].index { |h| hole_value(outer, arclen, h, u, phi) < 1 }
      end
    end

    # kose (vertex) parametreleri: varsayilan grid; delik kenarindakiler elipse oturtulur
    uv = Array.new(rows) { |i| Array.new(N_AROUND) { |j| [i.to_f, phis[j]] } }
    rows.times do |i|
      N_AROUND.times do |j|
        cells = [[i - 1, j - 1], [i - 1, j], [i, j - 1], [i, j]].select { |a, _| a >= 0 && a < rows - 1 }
        hits = cells.map { |a, b| removed[a][b % N_AROUND] }
        next unless hits.compact.any? && hits.include?(nil)
        h = v[:holes][hits.compact.first]
        deg, zc, ha, hb, tilt = h
        uc = u_at_z(outer, zc)
        r = lerp_row(outer, i)[0]
        s = wrap(phis[j] - deg * Math::PI / 180) * r
        t = arc_at(arclen, i) - arc_at(arclen, uc)
        rs, rt = rotate(s, t, tilt)
        f = Math.sqrt((rs / ha)**2 + (rt / hb)**2)
        next if f < 1e-6
        s /= f
        t /= f
        nu = u_at_arc(arclen, arc_at(arclen, uc) + t)
        nr = lerp_row(outer, nu)[0]
        uv[i][j] = [nu, deg * Math::PI / 180 + s / nr]
      end
    end

    # Elipse oturtulan bir kose komsusuna cok yaklastiysa ikisini tek noktada birlestir
    # (aksi halde SketchUp'in atacagi kadar ince ucgenler olusur)
    rows.times do |i|
      N_AROUND.times do |j|
        [[i, j + 1], [i + 1, j], [i + 1, j + 1], [i + 1, j - 1]].each do |a2, b2|
          next if a2 >= rows
          b2 %= N_AROUND
          p = point(outer, *uv[i][j])
          q = point(outer, *uv[a2][b2])
          uv[a2][b2] = uv[i][j] if Math.sqrt((0..2).sum { |k| (p[k] - q[k])**2 }) < 0.6
        end
      end
    end

    o = uv.map { |row| row.map { |u, phi| point(outer, u, phi) } }
    n = uv.map { |row| row.map { |u, phi| point(inner, u, phi) } }
    tris = []
    itris = []
    (rows - 1).times do |i|
      N_AROUND.times do |j|
        next if removed[i][j]
        j2 = (j + 1) % N_AROUND
        tris << [o[i][j], o[i][j2], o[i + 1][j2]] << [o[i][j], o[i + 1][j2], o[i + 1][j]]
        itris << [n[i][j], n[i + 1][j2], n[i][j2]] << [n[i][j], n[i + 1][j], n[i + 1][j2]]
        # delik duvarlari: komsusu silinmis kenarlar
        sides = []
        sides << [[i, j], [i, j2]] if i > 0 && removed[i - 1][j]
        sides << [[i + 1, j2], [i + 1, j]] if i < rows - 2 && removed[i + 1][j]
        sides << [[i + 1, j], [i, j]] if removed[i][(j - 1) % N_AROUND]
        sides << [[i, j2], [i + 1, j2]] if removed[i][j2]
        sides.each do |(a1, b1), (a2, b2)|
          p1 = o[a1][b1]
          p2 = o[a2][b2]
          q1 = n[a1][b1]
          q2 = n[a2][b2]
          tris << [p2, p1, q1] << [p2, q1, q2]
        end
      end
    end
    unless v[:closed]
      # agiz kenari: dis ve ic son halkayi birlestir
      N_AROUND.times do |j|
        j2 = (j + 1) % N_AROUND
        a = o[rows - 1][j]
        b = o[rows - 1][j2]
        c = n[rows - 1][j2]
        d = n[rows - 1][j]
        tris << [a, b, c] << [a, c, d]
      end
    end
    @inner_tris = itris
    tris + itris
  end

  def cross(a, b)
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
  end

  def dot(a, b)
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
  end

  def good_triangle?(a, b, c)
    e1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]]
    e2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]]
    cr = cross(e1, e2)
    area2 = Math.sqrt(dot(cr, cr))
    edges = [[a, b], [b, c], [c, a]].map { |p, q| Math.sqrt((p[0] - q[0])**2 + (p[1] - q[1])**2 + (p[2] - q[2])**2) }
    edges.min * SCALE > 0.005 && area2 * SCALE * SCALE > 1e-5
  end

  # ---------- SketchUp ----------

  def add_mesh(ents, tris, mat)
    mesh = Geom::PolygonMesh.new(tris.size * 3, tris.size)
    index = {}
    tris.each do |tri|
      next unless good_triangle?(*tri)
      ids = tri.map do |v|
        key = v.map { |c| (c * 1e4).round }
        index[key] ||= mesh.add_point(Geom::Point3d.new((v[0] * SCALE).cm, (v[1] * SCALE).cm, (v[2] * SCALE).cm))
      end
      next if ids.uniq.size < 3
      mesh.add_polygon(*ids)
    end
    ents.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE, mat, mat)
  end

  # Egri yuzeylerde ince kenarlari yumusat, delik ve agiz kenarlarini keskin birak
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - pencereli ikiz vazo olusturuluyor..."
    model.start_operation('Pencereli Ikiz Vazo', true)
    orange = material(model, 'Pencereli_Ic_Turuncu', INNER_COLOR)
    root = model.active_entities.add_group
    root.name = 'Pencereli Ikiz Vazo'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Pencereli_#{v[:name].tr(' ', '_')}", v[:color])
      all = vase_tris(v)
      inner = @inner_tris
      add_mesh(grp.entities, all.first(all.size - inner.size), mat)
      add_mesh(grp.entities, inner, orange)
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

WindowPair.run if defined?(Sketchup)
