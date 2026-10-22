# Cizgili delikli ikili - turuncudan griye yatay serit renkli yassi iki vazo:
# sol uzun vazoda dikey oval (stadyum) delik, sagdakinde kalp delik; ince boyunlu.
# Her vazo tek yumusak alan (SDF) olarak tanimlanir ve marching-tetrahedra ile
# tek parca kapali kati olarak cikarilir; renkler yukseklige gore seritlerdir.
# Olusturma 20-60 saniye surebilir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo39_cizgili_delikli.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module StripedHoles
  extend self

  SCALE = 40.0 / 967.0 # soldaki vazo 40 cm

  # Yukseklik oranina gore renk seritleri (alttan yukari): [ust sinir, renk]
  BANDS = [
    [0.12, [74, 72, 70]], [0.20, [122, 118, 110]], [0.28, [178, 170, 152]],
    [0.38, [214, 196, 160]], [0.46, [228, 188, 122]], [0.54, [232, 160, 82]],
    [0.62, [226, 128, 62]], [1.01, [204, 96, 52]]
  ]

  # Vazolar (fotograf pikseli): cx/base = eksen ve taban, outline = govde siluet,
  # hole = delik cokgeni, neck = [x, y, yari cap] ustten asagi, neck_top = agiz y
  # depth = govde yari kalinligi, pos = [x, y] px, size = perspektif payi
  VASES = [
    {
      name: 'Oval Delikli', cx: 284.0, base: 1233.0, pos: [0, 0], size: 1.0,
      depth: 78.0, round: 60.0, offset: 8.0, smooth: 15.0, blend: 45.0,
      neck: [[289, 268, 55], [289, 300, 54], [288, 330, 57], [286, 380, 72]],
      neck_top: 268.0, mouth_wall: 9.0, mouth_depth: 200.0,
      step: 6.5, box: [[-280.0, 280.0], [-100.0, 100.0], [-4.0, 980.0]],
      outline: [
        [238, 330], [222, 365], [205, 380], [159, 400], [120, 420], [93, 440],
        [75, 460], [64, 480], [57, 500], [53, 520], [51, 540], [48, 580],
        [47, 650], [47, 800], [50, 900], [54, 960], [58, 1000], [62, 1040],
        [70, 1080], [78, 1110], [88, 1140], [101, 1160], [116, 1180], [150, 1210],
        [200, 1228], [284, 1233], [368, 1228], [418, 1210], [452, 1180], [467, 1160],
        [480, 1140], [490, 1110], [498, 1080], [506, 1040], [510, 1000], [514, 960],
        [518, 900], [521, 800], [521, 650], [520, 580], [517, 540], [515, 520],
        [511, 500], [504, 480], [493, 460], [475, 440], [448, 420], [409, 400],
        [363, 380], [346, 365], [330, 330]
      ],
      hole: [
        [362.0, 650.0], [360.9, 637.5], [357.7, 625.4], [352.4, 614.0], [345.2, 603.7], [336.3, 594.8],
        [326.0, 587.6], [314.6, 582.3], [302.5, 579.1], [290.0, 578.0], [277.5, 579.1], [265.4, 582.3],
        [254.0, 587.6], [243.7, 594.8], [234.8, 603.7], [227.6, 614.0], [222.3, 625.4], [219.1, 637.5],
        [218.0, 650.0], [218.0, 850.0], [219.1, 862.5], [222.3, 874.6], [227.6, 886.0], [234.8, 896.3],
        [243.7, 905.2], [254.0, 912.4], [265.4, 917.7], [277.5, 920.9], [290.0, 922.0], [302.5, 920.9],
        [314.6, 917.7], [326.0, 912.4], [336.3, 905.2], [345.2, 896.3], [352.4, 886.0], [357.7, 874.6],
        [360.9, 862.5], [362.0, 850.0]
      ]
    },
    {
      name: 'Kalp Delikli', cx: 740.0, base: 1241.0, pos: [456, -185], size: 0.96,
      depth: 72.0, round: 60.0, offset: 8.0, smooth: 15.0, blend: 40.0,
      neck: [[740, 522, 37], [740, 560, 36], [740, 590, 40], [740, 630, 58]],
      neck_top: 522.0, mouth_wall: 7.0, mouth_depth: 160.0,
      step: 6.0, box: [[-285.0, 285.0], [-95.0, 95.0], [-4.0, 730.0]],
      outline: [
        [712, 590], [690, 615], [640, 640], [590, 660], [550, 685], [520, 715],
        [505, 750], [498, 800], [497, 900], [500, 980], [505, 1040], [512, 1100],
        [522, 1150], [540, 1200], [580, 1230], [650, 1240], [740, 1241], [830, 1240],
        [900, 1230], [940, 1200], [958, 1150], [968, 1100], [975, 1040], [980, 980],
        [983, 900], [982, 800], [975, 750], [960, 715], [930, 685], [890, 660],
        [840, 640], [790, 615], [768, 590]
      ],
      hole: [
        [747.0, 900.2], [747.1, 899.2], [747.5, 896.3], [748.8, 891.7], [751.1, 885.8], [754.7, 879.1],
        [759.8, 872.4], [766.3, 866.0], [774.2, 860.8], [783.2, 857.0], [793.0, 855.1], [803.3, 855.3],
        [813.5, 857.7], [823.2, 862.2], [832.0, 868.6], [839.3, 876.6], [844.8, 885.9], [848.2, 896.1],
        [849.4, 906.8], [848.2, 917.7], [844.8, 928.6], [839.3, 939.2], [832.0, 949.5], [823.2, 959.5],
        [813.5, 969.0], [803.3, 978.3], [793.0, 987.2], [783.2, 995.9], [774.2, 1004.3], [766.3, 1012.3],
        [759.8, 1019.8], [754.7, 1026.7], [751.1, 1032.7], [748.8, 1037.6], [747.5, 1041.3], [747.1, 1043.6],
        [747.0, 1044.3], [746.9, 1043.6], [746.5, 1041.3], [745.2, 1037.6], [742.9, 1032.7], [739.3, 1026.7],
        [734.2, 1019.8], [727.7, 1012.3], [719.8, 1004.3], [710.8, 995.9], [701.0, 987.2], [690.7, 978.3],
        [680.5, 969.0], [670.8, 959.5], [662.0, 949.5], [654.7, 939.2], [649.2, 928.6], [645.8, 917.7],
        [644.6, 906.8], [645.8, 896.1], [649.2, 885.9], [654.7, 876.6], [662.0, 868.6], [670.8, 862.2],
        [680.5, 857.7], [690.7, 855.3], [701.0, 855.1], [710.8, 857.0], [719.8, 860.8], [727.7, 866.0],
        [734.2, 872.4], [739.3, 879.1], [742.9, 885.8], [745.2, 891.7], [746.5, 896.3], [746.9, 899.2]
      ]
    }
  ]

  # ---------- 2B yardimcilar (x-z duzlemi) ----------

  def to_xz(px, py)
    [px - @v[:cx], @v[:base] - py]
  end

  # Cokgene isaretli uzaklik (icerde negatif)
  def poly_dist(poly, x, z)
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
    pts = @v[:neck].map { |px, py, r| to_xz(px, py) + [r] }
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

  # Bir (x, z) sutunu icin y'den bagimsiz degerler: [siluet, yari kalinlik, boyun, boyun yaricapi]
  def column(x, z)
    d = [poly_dist(@outline, x, z), -poly_dist(@hole, x, z)].max
    w = -d + @v[:offset]
    r = @v[:round]
    h = if w > 0
          w = r if w > r
          @v[:depth] * Math.sqrt(1 - (1 - w / r)**2)
        else
          3.0 * w
        end
    nd, nr = neck_xz(x, z)
    [d, h, nd, nr]
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
    _, h, nd, nr = col
    body = y.abs - h
    top = @v[:base] - @v[:neck_top]
    rad = Math.hypot(nd, y)
    neck = smax(rad - nr, z - top, 3.0)
    f = smin(body, neck, @v[:blend])
    f = [f, -z].max # duz taban
    mouth = [rad - (nr - @v[:mouth_wall]), top - @v[:mouth_depth] - z].max
    f = smax(f, -mouth, 3.0)
    f.abs < 1e-9 ? 1e-9 : f
  end

  def use(v)
    @v = v
    @outline = v[:outline].map { |px, py| to_xz(px, py) }
    @hole = v[:hole].map { |px, py| to_xz(px, py) }
  end

  # ---------- marching tetrahedra ----------

  CUBE = [[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0], [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]].freeze
  TETS = [[0, 5, 1, 6], [0, 1, 2, 6], [0, 2, 3, 6], [0, 3, 7, 6], [0, 7, 4, 6], [0, 4, 5, 6]].freeze

  def mesh_tris
    nx = ((@v[:box][0][1] - @v[:box][0][0]) / @v[:step]).ceil
    ny = ((@v[:box][1][1] - @v[:box][1][0]) / @v[:step]).ceil
    nz = ((@v[:box][2][1] - @v[:box][2][0]) / @v[:step]).ceil
    pos = ->(i, j, k) { [@v[:box][0][0] + i * @v[:step], @v[:box][1][0] + j * @v[:step], @v[:box][2][0] + k * @v[:step]] }
    cols = Array.new(nx + 1) { |i| Array.new(nz + 1) { |k| column(@v[:box][0][0] + i * @v[:step], @v[:box][2][0] + k * @v[:step]) } }
    smooth_depth(cols, nx, nz)
    val = Array.new(nx + 1) do |i|
      Array.new(ny + 1) do |j|
        y = @v[:box][1][0] + j * @v[:step]
        Array.new(nz + 1) { |k| field3(cols[i][k], y, @v[:box][2][0] + k * @v[:step]) }
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
    r = (@v[:smooth] / @v[:step]).round
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


  # Ucgenleri yukseklige gore renk seritlerine ayir
  def banded(tris, height)
    tris.group_by do |t|
      f = (t[0][2] + t[1][2] + t[2][2]) / 3.0 / height
      BANDS.index { |top, _| f < top } || BANDS.size - 1
    end
  end

  def material(model, name, rgb)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  def run
    model = Sketchup.active_model
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - cizgili delikli vazolar hesaplaniyor, lutfen bekleyin..."
    meshes = VASES.map do |v|
      use(v)
      [v, mesh_tris]
    end
    puts 'Yuzeyler olusturuluyor...'
    model.start_operation('Cizgili Delikli Vazolar', true)
    mats = BANDS.each_with_index.map { |(_, rgb), i| material(model, "Cizgili_Serit_#{i + 1}", rgb) }
    root = model.active_entities.add_group
    root.name = 'Cizgili Delikli Vazolar'
    meshes.each do |v, tris|
      s = v[:size]
      tris = tris.map { |t| t.map { |x, y, z| [x * s, y * s, z * s] } }
      grp = root.entities.add_group
      grp.name = v[:name]
      height = (v[:base] - v[:neck_top]) * s
      banded(tris, height).each { |i, part| add_mesh(grp.entities, part, mats[i]) }
      soften(grp.entities, 0.7) # ~40 derece
      x, y = v[:pos].map { |c| c * SCALE }
      grp.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x.cm, y.cm, 0)))
    end
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Vazolar hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

StripedHoles.run if defined?(Sketchup)
