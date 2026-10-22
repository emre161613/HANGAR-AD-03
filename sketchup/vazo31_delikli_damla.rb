# Delikli damla vazo - uzun ince boyun, yana tasan yuvarlak govde; sag lobunda
# her iki yuzden cukurlasan bir canak ve ortasindan gecen oval delik.
# Govde, boyun, canak ve delik tek bir yumusak alan (SDF) olarak tanimlanir;
# yuzey marching-tetrahedra ile cikarilir: tek parca, kapali bir kati.
# Olusturma 10-60 saniye surebilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo31_delikli_damla.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi (x - 300, 935 - y); SCALE ile cm'ye cevrilir.

module HoleDrop
  extend self

  SCALE = 35.0 / 807.0 # toplam yukseklik 35 cm

  # Govde siluet (fotograf pikseli, saat yonunde), boyun omzundan baslar
  OUTLINE = [
    [245, 545], [242, 540], [228, 570], [197, 600], [162, 630], [138, 660],
    [119, 690], [104, 720], [101, 750], [105, 780], [112, 815], [125, 850],
    [150, 888], [195, 918], [250, 934], [300, 937], [345, 932], [395, 916],
    [435, 893], [468, 860], [492, 830], [503, 805], [506, 780], [503, 750],
    [494, 720], [466, 700], [434, 680], [400, 660], [384, 640], [372, 610],
    [366, 575], [330, 545], [290, 535]
  ]
  DEPTH = 118.0 # govde yari kalinligi (px)
  ROUND = 110.0 # kenar yuvarlatma genisligi (px)

  # Boyun: [x, y, yari cap] fotograf pikseli, ustten asagi; ust = agiz
  NECK     = [[310, 120, 53], [316, 300, 52], [308, 450, 52], [302, 560, 60], [300, 620, 70]]
  NECK_TOP = 128.0
  MOUTH_WALL  = 7.0
  MOUTH_DEPTH = 150.0
  BLEND = 60.0
  SMOOTH = 20.0 # kalinlik yumusatma yaricapi (px)
  OFFSET = 10.0 # yumusatmanin kucuttugu siluet payi (px)

  # Delik: [merkez x, y, yari eksen a, b, egim (derece, + = saat yonu tersi)]
  HOLE  = [376, 742, 55, 31, -28]
  # Canak: delik etrafinda her iki yuzde cukur [merkez x, y, a, b, egim, derinlik orani]
  DISH  = [392, 738, 112, 74, -25, 0.92]
  EDGE  = 6.0 # delik kenari yuvarlatma

  STEP = 5.0 # izgara araligi (px) - kucuk = daha puruzsuz, daha yavas
  BOX  = [[-240.0, 250.0], [-130.0, 130.0], [-4.0, 812.0]]

  # ---------- 2B yardimcilar (x-z duzlemi) ----------

  def to_xz(px, py)
    [px - 300.0, 935.0 - py]
  end

  def outline_xz
    @outline_xz ||= OUTLINE.map { |px, py| to_xz(px, py) }
  end

  # Siluete isaretli uzaklik (icerde negatif)
  def outline_dist(x, z)
    poly = outline_xz
    best = 1e9
    inside = false
    n = poly.size
    n.times do |i|
      ax, az = poly[i]
      bx, bz = poly[(i + 1) % n]
      ex = bx - ax
      ez = bz - az
      t = ((x - ax) * ex + (z - az) * ez) / (ex * ex + ez * ez)
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0
      d = Math.hypot(x - ax - ex * t, z - az - ez * t)
      best = d if d < best
      inside = !inside if ((az > z) != (bz > z)) && (x < ax + (bx - ax) * (z - az) / (bz - az))
    end
    inside ? -best : best
  end

  # Boyun merkez cizgisine 2B uzaklik ve o noktadaki yari cap
  def neck_xz(x, z)
    pts = NECK.map { |px, py, r| to_xz(px, py) + [r] }
    best = [1e9, 0.0]
    (pts.size - 1).times do |i|
      ax, az, ar = pts[i]
      bx, bz, br = pts[i + 1]
      ex = bx - ax
      ez = bz - az
      t = ((x - ax) * ex + (z - az) * ez) / (ex * ex + ez * ez)
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0
      d = Math.hypot(x - ax - ex * t, z - az - ez * t)
      best = [d, ar + (br - ar) * t] if d < best[0]
    end
    best
  end

  # Egik elips: deger < 1 icerde
  def ellipse_k(e, x, z)
    px, py, a, b, tilt = e
    cx, cz = to_xz(px, py)
    t = tilt * Math::PI / 180
    dx = x - cx
    dz = z - cz
    u = dx * Math.cos(t) + dz * Math.sin(t)
    v = -dx * Math.sin(t) + dz * Math.cos(t)
    Math.sqrt((u / a)**2 + (v / b)**2)
  end

  # Bir (x, z) sutunu icin y'den bagimsiz degerler:
  # [siluet uzakligi, yari kalinlik, boyun uzakligi, boyun yari capi, delik]
  # Yari kalinlik siluetin disinda negatife gecer; yumusatildiktan sonra
  # sifir cizgisi govdenin kenari olur (kenar boyunca puruzsuz yuvarlak).
  def column(x, z)
    d = outline_dist(x, z)
    w = -d + OFFSET
    h = if w > 0
          w = ROUND if w > ROUND
          DEPTH * Math.sqrt(1 - (1 - w / ROUND)**2)
        else
          3.0 * w
        end
    k = ellipse_k(DISH, x, z)
    h *= 1 - DISH[5] * Math.exp(-2.2 * k * k) if h > 0 # canak: delige dogru incelir
    nd, nr = neck_xz(x, z)
    hk = ellipse_k(HOLE, x, z)
    [d, h, nd, nr, (hk - 1) * HOLE[3]]
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

  def field3(col, y, z)
    d, h, nd, nr, hole = col
    body = y.abs - h
    top = 935.0 - NECK_TOP
    rad = Math.hypot(nd, y)
    neck = smax(rad - nr, z - top, 3.0)
    f = smin(body, neck, BLEND)
    f = smax(f, -hole, EDGE) # delik
    f = [f, -z].max          # duz taban
    mouth = [rad - (nr - MOUTH_WALL), top - MOUTH_DEPTH - z].max
    f = smax(f, -mouth, 3.0)
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
    cols = Array.new(nx + 1) { |i| Array.new(nz + 1) { |k| column(BOX[0][0] + i * STEP, BOX[2][0] + k * STEP) } }
    smooth_depth(cols, nx, nz)
    val = Array.new(nx + 1) do |i|
      Array.new(ny + 1) do |j|
        y = BOX[1][0] + j * STEP
        Array.new(nz + 1) { |k| field3(cols[i][k], y, BOX[2][0] + k * STEP) }
      end
    end
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

  # Kalinlik haritasini yumusat (uzaklik alanindaki kirisik izleri yok eder)
  def smooth_depth(cols, nx, nz)
    r = (SMOOTH / STEP).round
    return if r < 1
    h = cols.map { |c| c.map { |v| v[1] } }
    2.times do
      h = h.map do |c|
        (0..nz).map { |k| lo = [k - r, 0].max; hi = [k + r, nz].min; c[lo..hi].sum / (hi - lo + 1) }
      end
      h = (0..nx).map do |i|
        lo = [i - r, 0].max
        hi = [i + r, nx].min
        (0..nz).map { |k| (lo..hi).sum { |ii| h[ii][k] } / (hi - lo + 1) }
      end
    end
    (0..nx).each { |i| (0..nz).each { |k| cols[i][k][1] = h[i][k] } }
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - delikli damla vazo hesaplaniyor, lutfen bekleyin..."
    tris = mesh_tris
    puts "#{tris.size} ucgen, yuzeyler olusturuluyor..."
    model.start_operation('Delikli Damla Vazo', true)
    mat = model.materials['Delikli_Damla_Beyaz'] || model.materials.add('Delikli_Damla_Beyaz')
    mat.color = Sketchup::Color.new(240, 238, 232)
    grp = model.active_entities.add_group
    grp.name = 'Delikli Damla Vazo'
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

HoleDrop.run if defined?(Sketchup)
