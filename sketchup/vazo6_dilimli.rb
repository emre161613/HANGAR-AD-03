# Dilimli vazo - ince cidarli yumurta govde + boyun + agiz, egik duzlemlerle
# bes dilime kesilmis; her dilim biraz kaydirilmis, aralarinda bosluk var.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo6_dilimli.rb"
#
# Eksenler: X = sag, Y = derinlik (on yuz -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module SlicedVase
  extend self

  SCALE = 30.0 / 1402.0 # toplam yukseklik ~30 cm

  # ---- Govde dis profili [yukseklik, yari cap] ----
  OUTER = [
    [0, 100], [17, 135], [47, 172], [87, 205], [137, 235], [170, 255],
    [230, 280], [272, 296], [352, 318], [432, 338], [532, 360], [612, 374],
    [662, 377], [712, 375], [772, 362], [852, 345], [924, 328], [990, 305],
    [1067, 275], [1134, 240], [1180, 205], [1212, 170], [1237, 125],
    [1262, 97], [1287, 75], [1305, 72], [1325, 78], [1340, 100],
    [1352, 150], [1365, 190], [1380, 203], [1390, 201], [1397, 195], [1402, 185]
  ]
  # ---- Ic profil (cidar ~12 px, agizda huni) ----
  INNER = [
    [24, 80], [47, 160], [87, 193], [137, 223], [170, 243], [230, 268],
    [272, 284], [352, 306], [432, 326], [532, 348], [612, 362], [662, 365],
    [712, 363], [772, 350], [852, 333], [924, 316], [990, 293], [1067, 263],
    [1134, 228], [1180, 193], [1212, 158], [1237, 113], [1262, 85],
    [1287, 63], [1305, 60], [1330, 62], [1355, 78], [1375, 100],
    [1392, 130], [1398, 140], [1402, 152]
  ]
  FLOOR_Z = 24.0
  TOP_Z   = 1402.0

  # ---- Dilimler ----
  # alt / ust duzlem: z = z0 + sx * X + sy * Y (dilimin kendi ekseninde)
  # nil alt = taban, nil ust = agiz
  # kaydirma: [dx, dy, dz]
  PIECES = [
    { name: 'Agiz ve Boyun', bottom: [1177, 0.18, 0.0],    top: nil,                 shift: [-30, 0, 0] },
    { name: 'Omuz',          bottom: [1045, -0.333, 0.095], top: [1169, 0.18, 0.0],   shift: [5, 0, 0] },
    { name: 'Govde',         bottom: [621, -0.252, 0.064],  top: [960, -0.30, 0.20],  shift: [25, 0, 0] },
    { name: 'Alt Govde',     bottom: [251, -0.088, 0.113],  top: [556, -0.367, 0.243], shift: [2, 0, 0] },
    { name: 'Taban',         bottom: nil,                   top: [220, -0.196, 0.25], shift: [-20, 0, 0] }
  ]
  MIN_T = 8.0 # kama dilimlerinin ince ucundaki en az kalinlik

  # ---- Cozunurluk ----
  N_AROUND = 180
  ROWS_PER_100 = 4 # 100 px yukseklik basina meridyen satiri (en az 6)

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

  def outer_r(z)
    @outer ||= smooth_profile(OUTER)
    interp(@outer, z)
  end

  def inner_r(z)
    @inner ||= smooth_profile(INNER)
    interp(@inner, z)
  end

  def plane_z(pl, x, y)
    pl[0] + pl[1] * x + pl[2] * y
  end

  def ring_point(r, phi, z)
    [r * Math.cos(phi), r * Math.sin(phi), z]
  end

  # Meridyenin duzlemi kestigi yukseklik (z_lo..z_hi arasinda, alttan ilk)
  def find_cut(pl, phi, z_lo, z_hi)
    f = lambda do |z|
      p = ring_point(yield(z), phi, z)
      z - plane_z(pl, p[0], p[1])
    end
    return z_lo if f.call(z_lo) >= 0
    return z_hi if f.call(z_hi) <= 0
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

  # Bir dilim: dis yuz, ust kesim, ic yuz, alt kesim (ya da taban)
  def piece_tris(pc)
    tris = []
    lo_o = []
    hi_o = []
    lo_i = []
    hi_i = []
    N_AROUND.times do |i|
      phi = 2 * Math::PI * i / N_AROUND
      zb_o = pc[:bottom] ? find_cut(pc[:bottom], phi, 0.0, TOP_Z) { |z| outer_r(z) } : 0.0
      zt_o = pc[:top] ? find_cut(pc[:top], phi, 0.0, TOP_Z) { |z| outer_r(z) } : TOP_Z
      zb_i = pc[:bottom] ? find_cut(pc[:bottom], phi, FLOOR_Z, TOP_Z) { |z| inner_r(z) } : FLOOR_Z
      zt_i = pc[:top] ? find_cut(pc[:top], phi, FLOOR_Z, TOP_Z) { |z| inner_r(z) } : TOP_Z
      # kama ucunda en az kalinlik birak
      zt_o = zb_o + MIN_T if zt_o < zb_o + MIN_T
      zt_i = zb_i + MIN_T if zt_i < zb_i + MIN_T
      lo_o << zb_o
      hi_o << zt_o
      lo_i << zb_i
      hi_i << zt_i
    end
    span = (hi_o + hi_i).max - (lo_o + lo_i).min
    rows = [6, (span / 100.0 * ROWS_PER_100).ceil + 6].max
    outer = Array.new(rows + 1) do |k|
      Array.new(N_AROUND) do |i|
        phi = 2 * Math::PI * i / N_AROUND
        z = lo_o[i] + (hi_o[i] - lo_o[i]) * k / rows
        ring_point(outer_r(z), phi, z)
      end
    end
    inner = Array.new(rows + 1) do |k|
      Array.new(N_AROUND) do |i|
        phi = 2 * Math::PI * i / N_AROUND
        z = hi_i[i] - (hi_i[i] - lo_i[i]) * k / rows
        ring_point(inner_r(z), phi, z)
      end
    end
    rows.times { |k| strip(outer[k + 1], outer[k], tris) } # dis yuz
    strip(inner[0], outer[rows], tris)                     # ust kesim
    rows.times { |k| strip(inner[k + 1], inner[k], tris) } # ic yuz
    if pc[:bottom]
      strip(outer[0], inner[rows], tris)                   # alt kesim
    else
      fan([0.0, 0.0, FLOOR_Z], inner[rows], tris)          # ic taban
      fan([0.0, 0.0, 0.0], outer[0], tris, true)           # dis taban
    end
    dx, dy, dz = pc[:shift]
    tris.map { |t| t.map { |p| [p[0] + dx, p[1] + dy, p[2] + dz] } }
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
    PIECES.map { |pc| [pc[:name], [[piece_tris(pc), :body]]] }
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

  # Egri yuzeylerde ince kenarlari yumusat, keskin kesim kenarlarini birak
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - dilimli vazo olusturuluyor..."
    list = parts
    model.start_operation('Dilimli Vazo', true)
    mats = { body: material(model, 'Vazo6_Mat_Siyah', [48, 48, 50]) }
    root = model.active_entities.add_group
    root.name = 'Dilimli Vazo'
    list.each do |name, pieces|
      grp = root.entities.add_group
      grp.name = name
      pieces.each { |tris, mat| add_mesh(grp.entities, tris, mats[mat]) }
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

SlicedVase.run if defined?(Sketchup)
