# Pliseli saksi - alt kase egik kesilmis, ustteki pliseli govde bu egik yuzeye oturuyor
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo4_pliseli_saksi.rb"
#
# Eksenler: X = sag, Y = derinlik (on yuz -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module PleatPot
  extend self

  SCALE = 0.07 # 1 px = 0.07 cm -> kase capi ~40 cm, yukseklik ~30 cm

  # ---- Ayak ----
  FOOT_R  = 124.0 # ust yari cap
  FOOT_R0 = 119.0 # alt yari cap
  FOOT_H  = 22.0

  # ---- Alt kase: fotograftaki siluetten [yukseklik, yari cap] ----
  BOWL_PROFILE = [
    [22, 126], [34, 145], [52, 176], [70, 205], [87, 228], [105, 245],
    [122, 259], [150, 275], [180, 284], [210, 288.5], [224, 289], [250, 288],
    [280, 283], [310, 272], [340, 255], [370, 230], [400, 195], [430, 140],
    [450, 70], [456, 0]
  ]

  # ---- Egik kesim duzlemi (ustteki govde buna oturur) ----
  TILT_X = 17.7   # saga dogru yukselme (derece)
  TILT_Y = 15.0   # arkaya dogru yukselme (derece)
  CREASE_TILT_Y = 8.0 # kirim halkasi arkaya dogru daha az egik
  BASE_X = -24.0  # ustteki govdenin taban merkezi (duzlem bu noktadan gecer)
  BASE_Y = 0.0
  BASE_Z = 271.0

  # ---- Ustteki pliseli govde ----
  # Pliler dikey; kirim halkasi ve taban kesim duzlemine paralel (egik),
  # ust yuz yatay kesilmis. Boylece solda uzun, sagda kisa pliler olusur.
  BOTTOM_R = 185.0 # tabandaki yari cap
  CREASE_H = 51.0  # tabandan kirima kadar (dusey)
  CREASE_R = 244.0 # kirimdaki yari cap
  FLAT_H   = 83.0  # kirimdan sonra dik giden kisim
  FLAT_R   = 246.0
  DOME_H   = 120.0 # sonra iceri kivrilan kubbe
  CUT_Z    = 410.0 # ust duz kesim yuksekligi
  PLEATS   = 40
  PLEAT_D  = 20.0  # pli derinligi
  # bir pli icindeki koseler (0..1): dis yuz, yan, oluk, yan
  PLEAT_U  = [0.0, 0.72, 0.78, 0.94]
  PLEAT_IN = [false, false, true, true]

  # ---- Agiz ----
  RIM_X     = -9.0
  RIM_Y     = 0.0
  RIM_R     = 177.0
  RIM_IN    = 163.0
  RIM_TOP   = 424.0
  SOIL_Z    = 395.0

  # ---- Cozunurluk ----
  N_AROUND = 160
  N_BOWL   = 40
  N_DOME   = 16

  def deg(a)
    a * Math::PI / 180
  end

  def add(a, b)
    [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
  end

  def mul(a, s)
    [a[0] * s, a[1] * s, a[2] * s]
  end

  def norm(a)
    l = Math.sqrt(a[0]**2 + a[1]**2 + a[2]**2)
    mul(a, 1.0 / l)
  end

  def cross(a, b)
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
  end

  def dot(a, b)
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
  end

  # Kesim duzleminin normali ve duzlemdeki iki eksen
  def frame
    @frame ||= begin
      n = norm([-Math.tan(deg(TILT_X)), -Math.tan(deg(TILT_Y)), 1.0])
      u = norm(cross([0.0, 1.0, 0.0], n))
      v = cross(n, u)
      [n, u, v]
    end
  end

  def base_point
    [BASE_X, BASE_Y, BASE_Z]
  end

  # Noktanin duzleme gore isaretli uzakligi (ust taraf +)
  def plane_side(p)
    dot(add(p, mul(base_point, -1)), frame[0])
  end

  # Iki noktadan bir kapali halka listesi yap: serit ucgenleri
  def strip(ring_a, ring_b, list)
    n = ring_a.size
    n.times do |i|
      j = (i + 1) % n
      list << [ring_a[i], ring_b[i], ring_b[j]]
      list << [ring_a[i], ring_b[j], ring_a[j]]
    end
  end

  def fan(center, ring, list, flip = false)
    n = ring.size
    n.times do |i|
      j = (i + 1) % n
      list << (flip ? [center, ring[j], ring[i]] : [center, ring[i], ring[j]])
    end
  end

  def circle(cx, cy, z, r, n = N_AROUND)
    Array.new(n) do |i|
      a = 2 * Math::PI * i / n
      [cx + r * Math.cos(a), cy + r * Math.sin(a), z]
    end
  end

  # ---- Alt kase + ayak ----
  # Kase profilini yumusak egriyle yogunlastir (Catmull-Rom)
  def bowl_profile
    @bowl_profile ||= begin
      pr = BOWL_PROFILE.map { |z, r| [z.to_f, r.to_f] }
      out = []
      (pr.size - 1).times do |i|
        p0 = pr[[i - 1, 0].max]
        p1 = pr[i]
        p2 = pr[i + 1]
        p3 = pr[[i + 2, pr.size - 1].min]
        8.times do |k|
          t = k / 8.0
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
  end

  def bowl_r(z)
    pr = bowl_profile
    (pr.size - 1).times do |i|
      z0, r0 = pr[i]
      z1, r1 = pr[i + 1]
      return r0 + (r1 - r0) * (z - z0) / (z1 - z0) if z >= z0 && z <= z1
    end
    z < pr[0][0] ? pr[0][1] : 0.0
  end

  def bowl_point(z, phi)
    r = bowl_r(z)
    [r * Math.cos(phi), r * Math.sin(phi), z]
  end

  def bowl_tris
    tris = []
    z0 = FOOT_H.to_f
    rings = Array.new(N_BOWL + 1) { [] }
    N_AROUND.times do |i|
      phi = 2 * Math::PI * i / N_AROUND
      lo = z0
      hi = BOWL_PROFILE.last[0].to_f
      60.times do
        mid = (lo + hi) / 2
        if plane_side(bowl_point(mid, phi)) < 0 then lo = mid else hi = mid end
      end
      cut = (lo + hi) / 2
      (0..N_BOWL).each do |k|
        rings[k] << bowl_point(z0 + (cut - z0) * k / N_BOWL, phi)
      end
    end
    # kesim kenarini tam duzleme oturt
    n = frame[0]
    rings[N_BOWL] = rings[N_BOWL].map { |p| add(p, mul(n, -plane_side(p))) }
    N_BOWL.times { |k| strip(rings[k + 1], rings[k], tris) }
    # ust duz yuz (raf)
    c = rings[N_BOWL].inject([0.0, 0.0, 0.0]) { |s, p| add(s, p) }
    c = mul(c, 1.0 / N_AROUND)
    c = add(c, mul(n, -plane_side(c)))
    fan(c, rings[N_BOWL], tris)
    # alt yuz ve ayak
    foot_top = circle(0.0, 0.0, FOOT_H, FOOT_R)
    strip(rings[0], foot_top, tris)
    foot_bot = circle(0.0, 0.0, 0.0, FOOT_R0)
    strip(foot_top, foot_bot, tris)
    fan([0.0, 0.0, 0.0], foot_bot, tris, true)
    tris
  end

  # ---- Pliseli govde ----
  # yerel profil: [h, r] tabandan yukari
  def profile
    pts = [[0.0, BOTTOM_R], [CREASE_H, CREASE_R], [CREASE_H + FLAT_H * 0.5, FLAT_R]]
    top = CREASE_H + FLAT_H
    (0..N_DOME).each do |k|
      t = k.to_f / N_DOME
      hp = DOME_H * Math.sin(t * Math::PI / 2)
      pts << [top + hp, FLAT_R * Math.sqrt([1 - (hp / DOME_H)**2, 0.0].max)]
    end
    pts
  end

  def pleat_angles
    list = []
    PLEATS.times do |p|
      PLEAT_U.each_with_index do |u, k|
        list << [2 * Math::PI * (p + u) / PLEATS, PLEAT_IN[k]]
      end
    end
    list
  end

  # Kesim duzleminin (x, y) noktasindaki yuksekligi
  def plane_z(x, y)
    BASE_Z + Math.tan(deg(TILT_X)) * (x - BASE_X) + Math.tan(deg(TILT_Y)) * (y - BASE_Y)
  end

  # Kirim halkasinin duzlemi
  def crease_z(x, y)
    BASE_Z + CREASE_H + Math.tan(deg(TILT_X)) * (x - BASE_X) + Math.tan(deg(CREASE_TILT_Y)) * (y - BASE_Y)
  end

  # Yukseklik, tabanda duzlemin kendisinden; yukarida kirim hizasindaki
  # duzlem yuksekliginden olculur (kirim halkasi duzleme paralel kalsin)
  def body_point(h, r, psi)
    c = Math.cos(psi)
    s = Math.sin(psi)
    x = BASE_X + r * c
    y = BASE_Y + r * s
    ref = h > 0 ? crease_z(BASE_X + CREASE_R * c, BASE_Y + CREASE_R * s) - CREASE_H : plane_z(x, y)
    # agzin dis kenarinin icine girmesin
    dx = x - RIM_X
    dy = y - RIM_Y
    d = Math.hypot(dx, dy)
    min_d = RIM_R + 6
    if d < min_d
      x = RIM_X + dx * min_d / d
      y = RIM_Y + dy * min_d / d
    end
    [x, y, ref + h]
  end

  def body_tris
    tris = []
    prof = profile
    angles = pleat_angles
    # her aci icin meridyen; ust kesimde kirp
    meridians = angles.map do |psi, inner|
      pts = prof.map do |h, r|
        r -= PLEAT_D if inner
        body_point(h, r, psi)
      end
      out = [pts[0]]
      (1...pts.size).each do |k|
        a = pts[k - 1]
        b = pts[k]
        if b[2] >= CUT_Z
          t = (CUT_Z - a[2]) / (b[2] - a[2])
          cut = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, CUT_Z]
          # cok kisa kenar olusmasin: onceki noktaya cok yakinsa onun yerine gecsin
          if out.size > 1 && Math.hypot(cut[0] - a[0], cut[1] - a[1]) < 0.5 && (CUT_Z - a[2]) < 0.5
            out[-1] = cut
          else
            out << cut
          end
          break
        end
        out << b
      end
      out
    end
    count = meridians.size
    # yan yuzler: komsu meridyenler arasinda; kisa olanin son noktasina ucgen yelpaze
    count.times do |i|
      a = meridians[i]
      b = meridians[(i + 1) % count]
      m = [a.size, b.size].min
      (m - 1).times do |k|
        tris << [a[k], b[k], b[k + 1]]
        tris << [a[k], b[k + 1], a[k + 1]]
      end
      if a.size > b.size
        (m - 1...a.size - 1).each { |k| tris << [a[k], b[-1], a[k + 1]] }
      elsif b.size > a.size
        (m - 1...b.size - 1).each { |k| tris << [a[-1], b[k], b[k + 1]] }
      end
    end
    # taban (duzlem ustunde)
    bottom = meridians.map { |m| m[0] }
    fan([BASE_X, BASE_Y, BASE_Z], bottom, tris, true)
    # ust duz halka: pli ucu -> agiz dis kenari
    top = meridians.map { |m| m[-1] }
    rim = top.map do |p|
      a = Math.atan2(p[1] - RIM_Y, p[0] - RIM_X)
      [RIM_X + RIM_R * Math.cos(a), RIM_Y + RIM_R * Math.sin(a), CUT_Z]
    end
    strip(rim, top, tris)
    # agiz: dis duvar, ust halka, ic duvar
    rim_top = rim.map { |p| [p[0], p[1], RIM_TOP] }
    strip(rim_top, rim, tris)
    inner_top = rim.map do |p|
      a = Math.atan2(p[1] - RIM_Y, p[0] - RIM_X)
      [RIM_X + RIM_IN * Math.cos(a), RIM_Y + RIM_IN * Math.sin(a), RIM_TOP]
    end
    strip(inner_top, rim_top, tris)
    inner_bot = inner_top.map { |p| [p[0], p[1], SOIL_Z] }
    strip(inner_bot, inner_top, tris)
    [tris, inner_bot]
  end

  def soil_tris(inner_bot)
    tris = []
    fan([RIM_X, RIM_Y, SOIL_Z], inner_bot, tris)
    tris
  end

  def good_triangle?(a, b, c)
    e1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]]
    e2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]]
    cr = cross(e1, e2)
    area2 = Math.sqrt(dot(cr, cr))
    edges = [[a, b], [b, c], [c, a]].map { |p, q| Math.sqrt((p[0] - q[0])**2 + (p[1] - q[1])**2 + (p[2] - q[2])**2) }
    edges.min * SCALE > 0.005 && area2 * SCALE * SCALE > 1e-5
  end

  # Butun parcalar: [ad, [[ucgenler, renk], ...]]
  def parts
    body, inner_bot = body_tris
    [
      ['Alt Kase', [[bowl_tris, :cream]]],
      ['Pliseli Govde', [[body, :cream], [soil_tris(inner_bot), :soil]]]
    ]
  end

  # ---- SketchUp ----
  def add_mesh(ents, tris, mat)
    mesh = Geom::PolygonMesh.new(tris.size * 3, tris.size)
    index = {}
    tris.each do |tri|
      next unless good_triangle?(*tri)
      ids = tri.map do |v|
        key = v.map { |c| (c * 1e6).round }
        index[key] ||= mesh.add_point(Geom::Point3d.new((v[0] * SCALE).cm, (v[1] * SCALE).cm, (v[2] * SCALE).cm))
      end
      next if ids.uniq.size < 3
      mesh.add_polygon(*ids)
    end
    ents.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE, mat, mat)
  end

  # Kure gibi yuzeylerde ince kenarlari yumusat, keskin pli kenarlarini birak
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

  # Disari bakmayan yuzleri cevir: en ustteki yuz yukari bakmali
  def fix_normals(grp)
    faces = grp.entities.grep(Sketchup::Face)
    top = faces.max_by { |f| f.bounds.center.z }
    faces.each(&:reverse!) if top && top.normal.z < 0
  end

  def material(model, name, rgb)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  def run
    model = Sketchup.active_model
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - pliseli saksi olusturuluyor..."
    list = parts
    model.start_operation('Pliseli Saksi', true)
    mats = {
      cream: material(model, 'Saksi_Beyaz', [238, 234, 226]),
      soil: material(model, 'Saksi_Toprak', [86, 66, 50])
    }
    root = model.active_entities.add_group
    root.name = 'Pliseli Saksi'
    list.each do |name, pieces|
      grp = root.entities.add_group
      grp.name = name
      pieces.each { |tris, mat| add_mesh(grp.entities, tris, mats[mat]) }
      fix_normals(grp)
      soften(grp.entities, 0.35) # ~20 derece
    end
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Saksi hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

PleatPot.run if defined?(Sketchup)
