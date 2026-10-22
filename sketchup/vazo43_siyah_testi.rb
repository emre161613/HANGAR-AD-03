# Siyah testi - omuzlu dolgun govde, kisa boyun; solda boyundan yukselip
# omuza inen uzun dar halka kulp, sagda agizdan omuza kisa kulp.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo43_siyah_testi.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi (x - 440, 1058 - y); SCALE ile cm'ye cevrilir.

module BlackJug
  extend self

  SCALE = 40.0 / 715.0 # kulp tepesine kadar 40 cm

  # Govde + boyun: alttan yukari [z, yari cap] (px); agzi acik
  BODY = [
    [0, 96], [3, 108], [18, 113], [48, 120], [78, 125], [108, 128], [138, 131],
    [168, 134], [198, 141], [228, 148], [258, 155], [288, 166], [318, 175], [333, 179],
    [348, 181], [368, 180], [393, 175], [418, 165], [438, 150], [453, 130], [468, 100],
    [483, 74], [498, 67], [528, 66], [548, 67], [558, 68]
  ]
  WALL  = 8.0
  DEPTH = 300.0 # agizdan iceri oyuk

  # Kulplar: [x, z] yol noktalari, boru yari capi
  HANDLE_R = 21.0
  HANDLES = [
    [[-142, 408], [-168, 453], [-174, 538], [-174, 618], [-164, 673], [-122, 696], [-88, 678], [-75, 638], [-73, 578], [-68, 536]],
    [[72, 538], [120, 546], [170, 538], [200, 506], [201, 458], [186, 418], [160, 390], [135, 368]]
  ]

  BLACK = [40, 38, 38]

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

  # Tum parcalar: [ad, {renk => ucgenler}]
  def parts
    [
      ['Govde', { black: body_tris }],
      ['Uzun Kulp', { black: handle_tris(HANDLES[0]) }],
      ['Kisa Kulp', { black: handle_tris(HANDLES[1]) }]
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - siyah testi olusturuluyor..."
    list = parts
    model.start_operation('Siyah Testi', true)
    mats = { black: material(model, 'Testi_Siyah', BLACK) }
    root = model.active_entities.add_group
    root.name = 'Siyah Testi'
    list.each do |name, groups|
      grp = root.entities.add_group
      grp.name = name
      groups.each { |key, tris| add_mesh(grp.entities, tris, mats[key]) }
      soften(grp.entities, 0.6) # ~35 derece
    end
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Testi hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

BlackJug.run if defined?(Sketchup)
