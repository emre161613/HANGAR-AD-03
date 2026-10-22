# U vazo - yumurta govdeden iki boru boyun yukselen, aralari oyulmus heykel vazo.
# Govde, iki boyun ve oyuk tek bir yumusak "alan" (SDF) olarak tanimlanir;
# yuzey bu alandan marching-tetrahedra ile cikarilir. Sonuc tek parca, kapali
# (su gecirmez) bir katidir. Olusturma birkac saniye ile yarim dakika surebilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo29_u_vazo.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi (x - 155, 411 - y); SCALE ile cm'ye cevrilir.

module UVase
  extend self

  SCALE = 40.0 / 322.0 # toplam yukseklik 40 cm

  # Govde: elipsoid [merkez x, y, z, yaricap x, y, z]
  BODY = [0.0, 0.0, 78.0, 80.0, 70.0, 82.0]

  # Oyuk: govdeden cikarilan elipsoid (iki boyun arasindaki kase)
  SCOOP = [6.0, -6.0, 176.0, 50.0, 84.0, 96.0]

  # Boyunlar: [x, z, yari cap] zinciri, agizdan asagi; ust = agiz duzlemi
  NECKS = [
    { top: 288.0, chain: [[-53, 292, 29], [-53, 279, 25], [-55, 266, 20], [-59, 245, 13.5],
                          [-61, 221, 11.5], [-60.5, 200, 11], [-63, 177, 12], [-64, 145, 17],
                          [-62, 120, 24]] },
    { top: 316.0, chain: [[33, 320, 27], [33, 301, 22], [32, 268, 13], [41, 236, 14],
                          [47, 209, 13], [55, 181, 14], [60, 154, 17], [58, 125, 23]] }
  ]
  MOUTH_WALL  = 6.0  # agiz cidari (px)
  MOUTH_DEPTH = 60.0 # agizdan iceri oyuk (px)
  BLEND       = 30.0 # govde-boyun birlesme yumusakligi (px)
  EDGE        = 4.0  # oyuk ve agiz kenarlarinin yuvarlatmasi (px)

  STEP = 3.0 # izgara araligi (px) - kucuk = daha puruzsuz, daha yavas
  BOX  = [[-110.0, 110.0], [-90.0, 90.0], [-4.0, 326.0]]

  # ---------- alan fonksiyonlari (negatif = icerde) ----------

  def ellipsoid(e, x, y, z)
    cx, cy, cz, rx, ry, rz = e
    k = Math.sqrt(((x - cx) / rx)**2 + ((y - cy) / ry)**2 + ((z - cz) / rz)**2)
    (k - 1.0) * [rx, ry, rz].min
  end

  # Degisken yaricapli boru zinciri (x-z duzleminde, y = 0)
  def chain(ch, x, y, z, shrink = 0.0)
    best = 1e9
    (ch.size - 1).times do |i|
      ax, az, ar = ch[i]
      bx, bz, br = ch[i + 1]
      ex = bx - ax
      ez = bz - az
      t = ((x - ax) * ex + (z - az) * ez) / (ex * ex + ez * ez)
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0
      d = Math.sqrt((x - ax - ex * t)**2 + y * y + (z - az - ez * t)**2) - (ar + (br - ar) * t - shrink)
      best = d if d < best
    end
    best
  end

  def smin(a, b, k)
    h = 0.5 + 0.5 * (b - a) / k
    h = 0.0 if h < 0.0
    h = 1.0 if h > 1.0
    b + (a - b) * h - k * h * (1.0 - h)
  end

  def smax(a, b, k)
    -smin(-a, -b, k)
  end

  def field(x, y, z)
    f = ellipsoid(BODY, x, y, z)
    NECKS.each do |n|
      neck = smax(chain(n[:chain], x, y, z), z - n[:top], EDGE / 2)
      f = smin(f, neck, BLEND)
    end
    f = smax(f, -ellipsoid(SCOOP, x, y, z), EDGE) # oyuk
    f = [f, -z].max # duz taban
    NECKS.each do |n|
      hole = [chain(n[:chain], x, y, z, MOUTH_WALL), n[:top] - MOUTH_DEPTH - z].max
      f = smax(f, -hole, EDGE / 2)
    end
    f.abs < 1e-9 ? 1e-9 : f
  end

  # ---------- marching tetrahedra ----------

  CUBE = [[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0], [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]].freeze
  TETS = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6], [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]].freeze

  def mesh_tris
    nx = ((BOX[0][1] - BOX[0][0]) / STEP).ceil
    ny = ((BOX[1][1] - BOX[1][0]) / STEP).ceil
    nz = ((BOX[2][1] - BOX[2][0]) / STEP).ceil
    pos = ->(i, j, k) { [BOX[0][0] + i * STEP, BOX[1][0] + j * STEP, BOX[2][0] + k * STEP] }
    val = Array.new(nx + 1) { |i| Array.new(ny + 1) { |j| Array.new(nz + 1) { |k| field(*pos.call(i, j, k)) } } }
    verts = {}
    tris = []
    edge_point = lambda do |a, b|
      key = (a <=> b) < 0 ? [a, b] : [b, a]
      verts[key] ||= begin
        va = val[a[0]][a[1]][a[2]]
        vb = val[b[0]][b[1]][b[2]]
        t = va / (va - vb)
        pa = pos.call(*a)
        pb = pos.call(*b)
        [pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t, pa[2] + (pb[2] - pa[2]) * t]
      end
    end
    nx.times do |i|
      ny.times do |j|
        nz.times do |k|
          corners = CUBE.map { |d| [i + d[0], j + d[1], k + d[2]] }
          vals = corners.map { |c| val[c[0]][c[1]][c[2]] }
          next if vals.all? { |v| v >= 0 } || vals.all? { |v| v < 0 }
          TETS.each do |tet|
            ins = tet.select { |c| vals[c] < 0 }
            out = tet.reject { |c| vals[c] < 0 }
            next if ins.empty? || out.empty?
            ref = pos.call(*corners[ins[0]])
            if ins.size == 1 || out.size == 1
              lone, others = ins.size == 1 ? [ins[0], out] : [out[0], ins]
              pts = others.map { |o| edge_point.call(corners[lone], corners[o]) }
              tris << orient(pts, ref)
            else
              a = edge_point.call(corners[ins[0]], corners[out[0]])
              b = edge_point.call(corners[ins[0]], corners[out[1]])
              c = edge_point.call(corners[ins[1]], corners[out[1]])
              d = edge_point.call(corners[ins[1]], corners[out[0]])
              tris << orient([a, b, c], ref) << orient([a, c, d], ref)
            end
          end
        end
      end
    end
    tris
  end

  # Ucgeni normali icerdeki noktadan disa bakacak sekilde cevir
  def orient(t, inside)
    a, b, c = t
    n = cross(sub(b, a), sub(c, a))
    cen = [(a[0] + b[0] + c[0]) / 3.0, (a[1] + b[1] + c[1]) / 3.0, (a[2] + b[2] + c[2]) / 3.0]
    dot(n, sub(cen, inside)) < 0 ? [a, c, b] : t
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

  def run
    model = Sketchup.active_model
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - U vazo hesaplaniyor, lutfen bekleyin..."
    tris = mesh_tris
    puts "#{tris.size} ucgen, yuzeyler olusturuluyor..."
    model.start_operation('U Vazo', true)
    mat = model.materials['U_Vazo_Krem'] || model.materials.add('U_Vazo_Krem')
    mat.color = Sketchup::Color.new(226, 216, 206)
    grp = model.active_entities.add_group
    grp.name = 'U Vazo'
    add_mesh(grp.entities, tris, mat)
    soften(grp.entities, 0.7) # ~40 derece
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Vazo hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

UVase.run if defined?(Sketchup)
