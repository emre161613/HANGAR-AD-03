# Yaprak desenli yumurta vazo - siyah govde; ustten asagi inen sivri krem ve gri
# yapraklar, beyaz kucuk agiz ve beyaz taban halkasi.
# Govde fotograftan olculen profille dondurulur; desen her ucgene acisina ve
# yuksekligine gore renk atanarak verilir (4 malzeme: siyah, krem, gri, beyaz).
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo40_yaprak_desenli.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module PetalVase
  extend self

  SCALE = 40.0 / 729.0 # vazo 40 cm

  # Dis profil: alttan yukari [z, yari cap] (px)
  PROFILE = [
    [0, 78], [15, 79], [30, 77], [32, 78], [65, 93], [105, 109], [145, 125],
    [185, 140], [225, 154], [265, 165], [305, 174], [345, 182], [385, 188],
    [425, 191], [465, 191], [495, 188], [525, 182], [545, 175], [585, 160],
    [615, 144], [645, 121], [660, 107], [680, 88], [700, 68], [715, 55],
    [724, 49], [729, 46]
  ]
  MOUTH   = 30.0  # agiz ic yari capi (px)
  DEPTH   = 160.0 # agiz derinligi (px)
  FOOT_Z  = 30.0  # beyaz taban halkasinin ust siniri (px)
  LIP_Z   = 712.0 # beyaz agiz bandinin alt siniri (px)

  # Yapraklar: govde etrafinda esit aralikli; sirayla krem ve gri.
  PETALS   = 18
  FULL_Z   = 500.0 # yapraklar bu yuksekligin ustunde tam genislikte
  GAP      = 0.016 # yapraklar arasindaki ince siyah cizgi (radyan, yarim)
  # Yaprak uclarinin yuksekligi (px), sirayla tekrar eder: krem uzun, gri kisa
  TIPS     = [205, 285, 240, 300, 190, 275, 225, 310, 255]
  SHAPE    = 0.9  # uca dogru incelme (kucuk = daha sivri uc)

  COLORS = {
    black: [34, 34, 34], cream: [234, 226, 210], grey: [158, 160, 164], white: [244, 242, 236]
  }

  N_AROUND = 360
  STEP     = 3.0 # profil boyunca satir araligi (px)

  def interp(pr, z)
    (pr.size - 1).times do |i|
      z0, r0 = pr[i]
      z1, r1 = pr[i + 1]
      return r0 + (r1 - r0) * (z - z0).to_f / (z1 - z0) if z >= z0 && z <= z1
    end
    z < pr[0][0] ? pr[0][1] : pr[-1][1]
  end

  # Catmull-Rom ile yumusatilmis profil, STEP aralikla
  def outer_profile
    @outer_profile ||= begin
      pr = PROFILE.map { |z, r| [z.to_f, r.to_f] }
      dense = []
      (pr.size - 1).times do |i|
        p0 = pr[[i - 1, 0].max]
        p1 = pr[i]
        p2 = pr[i + 1]
        p3 = pr[[i + 2, pr.size - 1].min]
        n = [((p2[0] - p1[0]) / STEP).ceil, 1].max
        n.times do |k|
          t = k.to_f / n
          dense << [0, 1].map do |c|
            0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t +
                   (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t * t +
                   (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t**3)
          end
        end
      end
      dense << pr.last
      dense
    end
  end

  def ring(r, z)
    Array.new(N_AROUND) do |i|
      a = 2 * Math::PI * i / N_AROUND
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

  # Kapali govde: taban, dis yuz, agiz halkasi, agiz ici
  def vase_tris
    pr = outer_profile
    top = pr.last[0]
    rings = pr.map { |z, r| ring(r, z) }
    inner = (0..10).map { |k| ring(MOUTH, top - DEPTH * k / 10.0) }
    tris = []
    fan([0.0, 0.0, 0.0], rings.first, tris, true)
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    strip(inner[0], rings.last, tris)
    (inner.size - 1).times { |k| strip(inner[k + 1], inner[k], tris) }
    fan([0.0, 0.0, top - DEPTH], inner.last, tris)
    tris
  end

  # Yuzey noktasinin rengi: aci ve yukseklige gore yaprak deseni
  def color_at(x, y, z)
    r = Math.hypot(x, y)
    return :white if z < FOOT_Z || z > LIP_Z || r < MOUTH + 1
    phi = Math.atan2(y, x) + Math::PI / 2 # 0 = tam on
    pitch = 2 * Math::PI / PETALS
    k = (phi / pitch).floor
    local = phi - (k + 0.5) * pitch # yaprak ortasina gore aci
    tip = TIPS[k % TIPS.size]
    return :black if z < tip
    half = pitch / 2 - GAP
    if z < FULL_Z
      t = (z - tip) / (FULL_Z - tip)
      half *= t**SHAPE
    end
    return :black if local.abs > half
    k.even? ? :cream : :grey
  end

  def cross(a, b)
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
  end

  def dot(a, b)
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
  end

  # Ucgenleri renge gore grupla
  def colored_parts
    vase_tris.group_by do |t|
      c = [0, 1, 2].map { |i| (t[0][i] + t[1][i] + t[2][i]) / 3.0 }
      color_at(*c)
    end
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - yaprak desenli vazo olusturuluyor..."
    parts = colored_parts
    model.start_operation('Yaprak Desenli Vazo', true)
    grp = model.active_entities.add_group
    grp.name = 'Yaprak Desenli Vazo'
    parts.each do |key, tris|
      add_mesh(grp.entities, tris, material(model, "Yaprak_#{key}", COLORS[key]))
    end
    soften(grp.entities, 0.6) # ~35 derece
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Vazo hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

PetalVase.run if defined?(Sketchup)
