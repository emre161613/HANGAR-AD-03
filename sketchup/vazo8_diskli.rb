# Diskli vazo - ortada ince bir cekirdek, etrafinda ust uste dizilmis
# 15 disk; disklerin dis kenari vazonun siluetini, araliklar cekirdegi gosterir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo8_diskli.rb"
#
# Eksenler: X = sag, Y = derinlik, Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module DiscVase
  extend self

  SCALE = 30.0 / 408.0 # toplam yukseklik 30 cm

  # ---- Diskler (alttan yukari): [alt z, ust z, alt yari cap, ust yari cap] ----
  # Disk kenarlari vazonun siluetine gore hafif egik (koni dilimi).
  DISCS = [
    [0, 22, 69, 69],     # taban
    [27, 49, 71, 74],
    [56, 76, 76, 80],
    [85, 104, 82, 86],
    [113, 132, 89, 92],
    [141, 160, 94, 98],
    [170, 188, 100, 104],
    [198, 214, 108, 111],
    [227, 241, 112, 112], # en genis
    [254, 270, 108, 103],
    [281, 298, 89, 69],   # omuz
    [308, 325, 58, 51],
    [335, 353, 48, 48],
    [362, 380, 52, 58],
    [389, 408, 67, 79]    # agiz
  ]
  BASE_CHAMFER = 3.0 # taban alt kenar pahi

  # ---- Cekirdek (disklerin arasindan gorunen ic govde) [z, yari cap] ----
  CORE = [
    [0, 52], [24, 55], [52, 64], [80, 72], [108, 74], [137, 71], [165, 64],
    [193, 55], [220, 45], [248, 36], [276, 30], [303, 27], [330, 24],
    [358, 26], [386, 35], [408, 38]
  ]

  # ---- Agiz deligi ----
  HOLE_R = 18.0
  HOLE_Z = 340.0 # delik tabani

  N_AROUND = 144

  def interp(table, z)
    (table.size - 1).times do |i|
      z0, r0 = table[i]
      z1, r1 = table[i + 1]
      return r0 + (r1 - r0) * (z - z0).to_f / (z1 - z0) if z >= z0 && z <= z1
    end
    z < table[0][0] ? table[0][1] : table[-1][1]
  end

  def core_r(z)
    interp(CORE, z).to_f
  end

  # Dis profil: alttan yukari [z, r] (ayni z'de iki nokta = yatay basamak)
  def profile
    pts = []
    DISCS.each_with_index do |(z0, z1, r0, r1), i|
      if i.zero?
        pts << [0.0, r0 - BASE_CHAMFER] << [BASE_CHAMFER, r0.to_f]
      else
        prev_top = DISCS[i - 1][1]
        pts << [prev_top.to_f, core_r(prev_top)] << [z0.to_f, core_r(z0)] # aradaki cekirdek
        pts << [z0.to_f, r0.to_f]
      end
      pts << [z1.to_f, r1.to_f]
    end
    pts
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

  # Tek parca kapali govde: taban, basamakli dis yuz, ust halka, delik
  def vase_tris
    tris = []
    top = DISCS.last[1].to_f
    rings = profile.map { |z, r| ring(r, z) }
    rings << ring(HOLE_R, top) << ring(HOLE_R, HOLE_Z)
    fan([0.0, 0.0, 0.0], rings.first, tris, true)
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    fan([0.0, 0.0, HOLE_Z], rings.last, tris)
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
    [['Diskli Vazo', [[vase_tris, :body]]]]
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

  # Yuvarlak yuzlerde ince kenarlari yumusat, disk kenarlarini keskin birak
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - diskli vazo olusturuluyor..."
    list = parts
    model.start_operation('Diskli Vazo', true)
    mats = { body: material(model, 'Vazo8_Beyaz', [242, 242, 238]) }
    root = model.active_entities.add_group
    root.name = 'Diskli Vazo'
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

DiscVase.run if defined?(Sketchup)
