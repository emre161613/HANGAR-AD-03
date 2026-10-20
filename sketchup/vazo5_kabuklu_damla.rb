# Kabuklu damla vazo - ic govde dikey yarikli damla, dis kabuk egik kesilmis
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo5_kabuklu_damla.rb"
#
# Eksenler: X = sag, Y = derinlik (on yuz -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module ShellVase
  extend self

  SCALE = 30.0 / 735.0 # toplam yukseklik 30 cm

  # ---- Dis kabuk: fotograftaki siluetten [yukseklik, yari cap] ----
  SHELL_PROFILE = [
    [0, 112], [5, 132], [15, 150], [35, 172], [65, 197], [115, 230],
    [165, 250], [215, 258], [255, 258], [295, 254], [335, 246], [375, 235],
    [415, 218], [455, 193], [495, 160], [530, 120], [555, 70], [565, 0]
  ]
  SHELL_T     = 16.0 # kabuk kalinligi
  SHELL_FLOOR = 24.0 # kabugun ic tabani

  # ---- Egik kesim: Z = CUT_Z0 + CUT_SX * X + CUT_SY * Y ----
  CUT_Z0 = 342.5
  CUT_SX = -1.0  # saga dogru 45 derece alcalir
  CUT_SY = 0.52  # arkaya dogru yukselir

  # ---- Ic govde (damla): [yukseklik, yari cap] ----
  BODY_PROFILE = [
    [35, 0], [40, 140], [70, 170], [115, 195], [165, 206], [215, 209],
    [265, 206], [315, 193], [365, 178], [415, 158], [455, 141], [495, 125],
    [535, 108], [575, 89], [595, 79], [630, 71], [665, 64], [697, 61], [735, 59]
  ]
  MOUTH_R     = 46.0  # agiz ic yari capi
  MOUTH_DEPTH = 60.0
  RIBS        = 36    # dikey serit sayisi
  GROOVE_W    = 5.5   # yarik genisligi
  GROOVE_D    = 12.0  # yarik derinligi
  GROOVE_TOP  = 697.0 # yariklar bu yukseklikte baslar (ustu duz bant)

  # ---- Cozunurluk ----
  N_SHELL  = 160
  N_OUTER  = 44
  N_INNER  = 30
  RIB_PTS  = 5 # serit yuzeyindeki ara nokta

  # Profili yumusak egriyle yogunlastir (Catmull-Rom), [z, r] listesi
  def smooth_profile(table, per = 6)
    pr = table.map { |z, r| [z.to_f, r.to_f] }
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

  def interp(pr, z)
    (pr.size - 1).times do |i|
      z0, r0 = pr[i]
      z1, r1 = pr[i + 1]
      next if z1 == z0
      return r0 + (r1 - r0) * (z - z0) / (z1 - z0) if z >= z0 && z <= z1
    end
    z < pr[0][0] ? pr[0][1] : pr[-1][1]
  end

  def shell_pr
    @shell_pr ||= smooth_profile(SHELL_PROFILE, 8)
  end

  def shell_outer_r(z)
    interp(shell_pr, z)
  end

  def shell_inner_r(z)
    shell_outer_r(z) - SHELL_T
  end

  def cut_z(x, y)
    CUT_Z0 + CUT_SX * x + CUT_SY * y
  end

  def ring_point(r, phi, z)
    [r * Math.cos(phi), r * Math.sin(phi), z]
  end

  # Meridyen boyunca kesim yuksekligi (alttan yukari ilk kesisim)
  def find_cut(phi, z_lo, z_hi)
    f = lambda do |z|
      p = ring_point(yield(z), phi, z)
      z - cut_z(p[0], p[1])
    end
    lo = z_lo
    hi = z_hi
    60.times do
      mid = (lo + hi) / 2
      if f.call(mid) < 0 then lo = mid else hi = mid end
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

  def fan(center, ring, list, flip = false)
    n = ring.size
    n.times do |i|
      j = (i + 1) % n
      list << (flip ? [center, ring[j], ring[i]] : [center, ring[i], ring[j]])
    end
  end

  # ---- Dis kabuk: kapali katı (dis yuz, kesim yuzu, ic yuz, ic taban, alt taban) ----
  def shell_tris
    tris = []
    z_top = SHELL_PROFILE.last[0].to_f - 1
    outer = Array.new(N_OUTER + 1) { [] }
    inner = Array.new(N_INNER + 1) { [] }
    N_SHELL.times do |i|
      phi = 2 * Math::PI * i / N_SHELL
      zo = find_cut(phi, 0.0, z_top) { |z| shell_outer_r(z) }
      zi = find_cut(phi, SHELL_FLOOR, z_top) { |z| shell_inner_r(z) }
      (0..N_OUTER).each do |k|
        z = zo * k / N_OUTER
        outer[k] << ring_point(shell_outer_r(z), phi, z)
      end
      (0..N_INNER).each do |k|
        z = zi - (zi - SHELL_FLOOR) * k / N_INNER
        inner[k] << ring_point(shell_inner_r(z), phi, z)
      end
    end
    # kesim kenarlarini tam duzleme oturt
    [outer[N_OUTER], inner[0]].each do |ring|
      ring.map! { |p| [p[0], p[1], cut_z(p[0], p[1])] }
    end
    N_OUTER.times { |k| strip(outer[k + 1], outer[k], tris) }
    strip(inner[0], outer[N_OUTER], tris)          # kesim yuzu
    N_INNER.times { |k| strip(inner[k + 1], inner[k], tris) }
    fan([0.0, 0.0, SHELL_FLOOR], inner[N_INNER], tris) # ic taban
    fan([0.0, 0.0, 0.0], outer[0], tris, true)     # alt taban
    tris
  end

  # ---- Ic govde ----
  def body_pr
    @body_pr ||= begin
      pr = smooth_profile(BODY_PROFILE, 4)
      extra = [GROOVE_TOP - 6, GROOVE_TOP].map { |z| [z, interp(pr, z)] }
      rows = []
      (pr + extra).sort_by(&:first).each do |z, r|
        rows << [z, r] if rows.empty? || z - rows[-1][0] > 0.5
      end
      rows
    end
  end

  # Bir yatay halkadaki acilar ve yarik derinlikleri
  def rib_ring(z, r)
    pitch = 2 * Math::PI / RIBS
    g = GROOVE_W / r
    g = pitch * 0.4 if g > pitch * 0.4
    depth = GROOVE_D * [[(GROOVE_TOP - z) / 6.0, 0.0].max, 1.0].min
    pts = []
    RIBS.times do |n|
      a0 = pitch * n
      pts << [a0, 0.0]
      pts << [a0 + g * 0.08, depth]
      pts << [a0 + g * 0.92, depth]
      pts << [a0 + g, 0.0]
      RIB_PTS.times do |k|
        pts << [a0 + g + (pitch - g) * (k + 1) / (RIB_PTS + 1), 0.0]
      end
    end
    pts.map { |a, d| ring_point([r - d, 1.0].max, a, z) }
  end

  def body_tris
    tris = []
    pr = body_pr
    z_top = BODY_PROFILE.last[0].to_f
    rings = pr.select { |z, r| r > 0.5 }.map { |z, r| rib_ring(z, r) }
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    # alt kapak
    fan([0.0, 0.0, pr.first[0]], rings.first, tris, true)
    # ust: duz halka, agiz ic duvari, agiz tabani
    top = rings.last
    mouth = top.map do |p|
      a = Math.atan2(p[1], p[0])
      ring_point(MOUTH_R, a, z_top)
    end
    strip(mouth, top, tris)
    mouth_bot = mouth.map { |p| [p[0], p[1], z_top - MOUTH_DEPTH] }
    strip(mouth_bot, mouth, tris)
    fan([0.0, 0.0, z_top - MOUTH_DEPTH], mouth_bot, tris)
    tris
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

  # Butun parcalar: [ad, [[ucgenler, renk], ...]]
  def parts
    [
      ['Dis Kabuk', [[shell_tris, :body]]],
      ['Ic Govde', [[body_tris, :body]]]
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

  # Egri yuzeylerde ince kenarlari yumusat, keskin kenarlari birak
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
    top = faces.max_by { |f| f.bounds.max.z }
    faces.each(&:reverse!) if top && top.normal.z < 0
  end

  def material(model, name, rgb)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  def run
    model = Sketchup.active_model
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - kabuklu damla vazo olusturuluyor..."
    list = parts
    model.start_operation('Kabuklu Damla Vazo', true)
    mats = { body: material(model, 'Vazo5_Bronz', [168, 155, 132]) }
    root = model.active_entities.add_group
    root.name = 'Kabuklu Damla Vazo'
    list.each do |name, pieces|
      grp = root.entities.add_group
      grp.name = name
      pieces.each { |tris, mat| add_mesh(grp.entities, tris, mats[mat]) }
      fix_normals(grp)
      soften(grp.entities, 0.35) # ~20 derece
    end
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Vazo hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

ShellVase.run if defined?(Sketchup)
