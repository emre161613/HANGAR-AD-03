# Tabak kule - ince bir cekirdegin etrafinda ust uste dizilmis, kenarlari
# bicak gibi incelen 32 tabak; en altta hafif egik oturmus iki buyuk tabak.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo9_tabak_kule.rb"
#
# Eksenler: X = sag, Y = derinlik, Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module PlateTower
  extend self

  SCALE = 50.0 / 528.0 # toplam yukseklik ~50 cm

  # ---- Duzenli tabaklar ----
  PLATES      = 32
  PLATE_TOP_Z = 521.5 # en ustteki tabagin orta yuksekligi
  PLATE_PITCH = 15.5  # tabaklar arasi
  R_TOP       = 90.0  # en ustteki tabagin yari capi
  R_BOTTOM    = 108.0 # en alttaki duzenli tabagin yari capi
  HALF_T      = 5.5   # tabagin cekirdek hizasindaki yari kalinligi
  EDGE_POW    = 4.0   # kenar incelme egrisi (buyuk = kenara yakin incelir)
  N_EDGE      = 7     # tabak yuzeyindeki nokta sayisi (her yuzde)

  # ---- Cekirdek (tabaklarin arasindan gorunen kolon) ----
  CORE_TOP_R    = 65.0
  CORE_BOTTOM_R = 52.0
  CORE_BOTTOM_Z = 31.0 # alttaki egik tabaga oturur

  # ---- Alttaki egik tabaklar: [orta z, yari cap, egim (derece), dx] ----
  LOOSE = [
    [28.0, 116.0, 2.0, -8.0],
    [12.0, 124.0, -2.5, -8.0]
  ]

  N_AROUND = 72

  def plate_r(i)
    R_TOP + (R_BOTTOM - R_TOP) * i / (PLATES - 1).to_f
  end

  def plate_z(i)
    PLATE_TOP_Z - PLATE_PITCH * i
  end

  def core_r(z)
    t = (z - CORE_BOTTOM_Z) / (PLATE_TOP_Z - CORE_BOTTOM_Z)
    CORE_BOTTOM_R + (CORE_TOP_R - CORE_BOTTOM_R) * t
  end

  # Tabagin cekirdekten kenara kalinlik egrisi: 1 -> 0
  def lens(t)
    (1 - t**EDGE_POW)**0.7
  end

  # Ana kule profili: alttan yukari [r, z]; ilk ve son nokta eksen uzerinde
  def profile
    pts = [[0.0, CORE_BOTTOM_Z], [core_r(CORE_BOTTOM_Z), CORE_BOTTOM_Z]]
    (PLATES - 1).downto(0) do |i|
      zc = plate_z(i)
      rc = core_r(zc)
      big = plate_r(i)
      pts << [rc, zc - HALF_T] # cekirdek boyunca bu tabagin altina
      (1..N_EDGE).each do |k| # alt yuz: cekirdekten kenara
        t = k.to_f / N_EDGE
        pts << [rc + (big - rc) * t, zc - HALF_T * lens(t)]
      end
      (N_EDGE - 1).downto(0) do |k| # ust yuz: kenardan cekirdege
        t = k.to_f / N_EDGE
        pts << [rc + (big - rc) * t, zc + HALF_T * lens(t)]
      end
    end
    pts << [0.0, pts.last[1]]
    pts
  end

  def ring(r, z, n = N_AROUND)
    Array.new(n) do |i|
      a = 2 * Math::PI * i / n
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

  # Profil -> kapali donel yuzey (ilk ve son nokta eksen uzerinde)
  def revolve(pts, n = N_AROUND)
    tris = []
    rings = pts[1..-2].map { |r, z| ring(r, z, n) }
    fan([0.0, 0.0, pts.first[1]], rings.first, tris, true)
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    fan([0.0, 0.0, pts.last[1]], rings.last, tris)
    tris
  end

  def tower_tris
    revolve(profile)
  end

  # Tek basina mercek kesitli tabak, egilip yerine konur
  def loose_plate_tris(zc, big, tilt_deg, dx)
    pts = [[0.0, -HALF_T]]
    (1..N_EDGE * 2).each do |k|
      t = k.to_f / (N_EDGE * 2)
      pts << [big * t, -HALF_T * lens(t)]
    end
    (N_EDGE * 2 - 1).downto(1) do |k|
      t = k.to_f / (N_EDGE * 2)
      pts << [big * t, HALF_T * lens(t)]
    end
    pts << [0.0, HALF_T]
    a = tilt_deg * Math::PI / 180
    revolve(pts, 96).map do |tri|
      tri.map do |x, y, z|
        [x * Math.cos(a) - z * Math.sin(a) + dx, y, x * Math.sin(a) + z * Math.cos(a) + zc]
      end
    end
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
    list = [['Kule', [[tower_tris, :body]]]]
    LOOSE.each_with_index do |(zc, big, tilt, dx), i|
      list << ["Alt Tabak #{i + 1}", [[loose_plate_tris(zc, big, tilt, dx), :body]]]
    end
    list
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

  # Yuvarlak yuzlerde ince kenarlari yumusat, tabak kenarlarini keskin birak
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - tabak kule olusturuluyor..."
    list = parts
    model.start_operation('Tabak Kule', true)
    mats = { body: material(model, 'Vazo9_Porselen', [240, 238, 232]) }
    root = model.active_entities.add_group
    root.name = 'Tabak Kule'
    list.each do |name, pieces|
      grp = root.entities.add_group
      grp.name = name
      pieces.each { |tris, mat| add_mesh(grp.entities, tris, mats[mat]) }
      soften(grp.entities, 0.6) # ~35 derece
    end
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Kule hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

PlateTower.run if defined?(Sketchup)
