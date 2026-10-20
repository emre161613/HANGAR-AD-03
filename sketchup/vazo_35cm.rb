# Halka (donut) vazo - 35 cm
# SketchUp: Window > Ruby Console, bu dosyanin tamamini yapistir ve Enter'a bas.
# Ya da: load "C:/Users/Onur Girit/Desktop/vazo_35cm.rb"
#
# Eksenler: X = sag, Y = derinlik, Z = yukari. Olculer cm.

module DonutVase
  extend self

  # ---- Ana olculer (cm) ----
  BODY_CX   = 0.0    # govde dis elipsi merkezi
  BODY_CZ   = 15.0
  BODY_RX   = 15.0   # govde yari genislik  (toplam ~30 cm)
  BODY_RZ   = 15.8   # govde yari yukseklik
  HOLE_CX   = -2.4   # delik merkezi (hafif solda)
  HOLE_CZ   = 14.8
  HOLE_RX   = 3.3    # delik yari genislik
  HOLE_RZ   = 6.3    # delik yari yukseklik
  HOLE_TILT = -12.0  # delik egimi (derece)
  DEPTH     = 4.4    # govde yari kalinligi (toplam ~9 cm)
  SQUARE    = 0.62   # kesit "kareligi" (1 = elips, kucuk = daha duz yuzler)

  NECK_X    = -0.7   # boyun ekseni
  TOP_Z     = 35.0   # toplam yukseklik

  # ---- Dalgali cizgiler ----
  RIB_FROM  = -105.0 # cizgi bolgesi baslangic acisi (delik merkezine gore)
  RIB_TO    = 52.0   # bitis acisi
  RIB_AMP   = 0.28   # cizgi kabarikligi
  RIB_STEP  = 0.17   # cizgiler arasi (radyan, kesit uzerinde)

  # ---- Cozunurluk ----
  N_THETA_RIB  = 170 # cizgili bolgede (daha sik)
  N_THETA_REST = 50  # duz bolgede
  N_PHI   = 160
  N_NECK  = 64

  def smooth(e0, e1, x)
    t = (x - e0) / (e1 - e0)
    t = 0.0 if t < 0.0
    t = 1.0 if t > 1.0
    t * t * (3 - 2 * t)
  end

  def spow(v, e)
    v < 0 ? -(-v)**e : v**e
  end

  # Delik merkezinden theta yonundeki isinin dis elipsi kestigi mesafe
  def outer_dist(dx, dz)
    ox = HOLE_CX - BODY_CX
    oz = HOLE_CZ - BODY_CZ
    a = (dx / BODY_RX)**2 + (dz / BODY_RZ)**2
    b = 2 * (ox * dx / BODY_RX**2 + oz * dz / BODY_RZ**2)
    c = (ox / BODY_RX)**2 + (oz / BODY_RZ)**2 - 1
    (-b + Math.sqrt(b * b - 4 * a * c)) / (2 * a)
  end

  # Egik delik elipsinin ayni isin uzerindeki mesafesi
  def hole_dist(dx, dz)
    t = HOLE_TILT * Math::PI / 180
    lx = dx * Math.cos(t) + dz * Math.sin(t)
    lz = -dx * Math.sin(t) + dz * Math.cos(t)
    1.0 / Math.sqrt((lx / HOLE_RX)**2 + (lz / HOLE_RZ)**2)
  end

  # Cizgi kabarikligi: kesit acisi phi, govde acisi theta (derece)
  def rib_offset(theta_deg, phi)
    return 0.0 unless theta_deg > RIB_FROM && theta_deg < RIB_TO
    u = (theta_deg - RIB_FROM) / (RIB_TO - RIB_FROM)
    env = Math.sin(Math::PI * u)
    # dalgali S sinir: cizgiler dis kenardan iceri dogru bu aciya kadar
    border = 0.2 + 2.45 * env + 0.3 * Math.sin(2.0 * Math::PI * u + 0.4) * env
    s = border - phi.abs
    return 0.0 if s <= 0
    rib = 0.5 - 0.5 * Math.cos(2 * Math::PI * s / RIB_STEP)
    RIB_AMP * rib * smooth(0.0, 0.12, s) * smooth(0.0, 0.25, env)
  end

  # Govde acilari: cizgili bolgede sik, geri kalaninda seyrek
  def thetas
    a = RIB_FROM * Math::PI / 180
    b = RIB_TO * Math::PI / 180
    rest = 2 * Math::PI - (b - a)
    Array.new(N_THETA_RIB) { |i| a + (b - a) * i / N_THETA_RIB } +
      Array.new(N_THETA_REST) { |i| b + rest * i / N_THETA_REST }
  end

  # Govde: delik etrafinda donen, kesiti super-elips olan halka
  def body_grid
    thetas.map do |th|
      dx = Math.cos(th)
      dz = Math.sin(th)
      r_in  = hole_dist(dx, dz)
      r_out = outer_dist(dx, dz)
      w  = (r_out - r_in) / 2.0
      rc = (r_out + r_in) / 2.0
      th_deg = th * 180 / Math::PI
      Array.new(N_PHI) do |j|
        ph = -Math::PI + 2 * Math::PI * j / N_PHI
        c = Math.cos(ph)
        s = Math.sin(ph)
        rad = w * spow(c, SQUARE)
        y   = DEPTH * spow(s, SQUARE)
        off = rib_offset(th_deg, ph)
        rad += off * c
        y   += off * s
        x = HOLE_CX + (rc + rad) * dx
        z = HOLE_CZ + (rc + rad) * dz
        z = 0.0 if z < 0.0 # duz taban
        [x, y, z]
      end
    end
  end

  # Boyun: dikey eksen etrafinda donel profil (r, z), ust agiz acik ici bos
  NECK_PROFILE = [
    [0.0, 27.5], [3.9, 27.5], [3.7, 29.5], [3.35, 31.0], [3.15, 32.5],
    [3.2, 34.2], [3.05, 34.85], [2.75, 35.0], [2.2, 35.0], [2.0, 34.6],
    [1.9, 33.0], [1.6, 32.2], [0.0, 32.0]
  ]

  def neck_grid
    NECK_PROFILE.map do |r, z|
      Array.new(N_NECK) do |k|
        a = 2 * Math::PI * k / N_NECK
        [NECK_X + r * Math.cos(a), r * Math.sin(a), z]
      end
    end
  end

  # Kafes -> dortgen listesi (indeksler). wrap_rows: satirlar da kapali mi
  def quads(rows, cols, wrap_rows)
    list = []
    last = wrap_rows ? rows : rows - 1
    last.times do |i|
      i2 = (i + 1) % rows
      cols.times do |j|
        j2 = (j + 1) % cols
        list << [[i, j], [i, j2], [i2, j2], [i2, j]]
      end
    end
    list
  end

  # ---- SketchUp ----
  def build_mesh(ents, grid, wrap_rows, mat, name)
    rows = grid.size
    cols = grid[0].size
    mesh = Geom::PolygonMesh.new(rows * cols, rows * cols * 2)
    idx = grid.map { |row| row.map { |x, y, z| mesh.add_point(Geom::Point3d.new(x.cm, y.cm, z.cm)) } }
    quads(rows, cols, wrap_rows).each do |q|
      ids = q.map { |i, j| idx[i][j] }.uniq
      next if ids.size < 3
      # Duz olmayan dortgenleri SketchUp atliyor; ucgenlere bol
      mesh.add_polygon(ids[0], ids[1], ids[2])
      mesh.add_polygon(ids[0], ids[2], ids[3]) if ids.size == 4
    end
    grp = ents.add_group
    grp.name = name
    flags = Geom::PolygonMesh::AUTO_SOFTEN | Geom::PolygonMesh::SMOOTH_SOFT_EDGES
    grp.entities.add_faces_from_mesh(mesh, flags, mat, mat)
    fix_normals(grp)
    grp
  end

  # En sagdaki yuz disari bakmiyorsa tum yuzleri cevir
  def fix_normals(grp)
    faces = grp.entities.grep(Sketchup::Face)
    right = faces.max_by { |f| f.bounds.center.x }
    faces.each(&:reverse!) if right && right.normal.x < 0
  end

  def run
    model = Sketchup.active_model
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - vazo olusturuluyor, lutfen bekleyin..."
    model.start_operation('Halka Vazo', true)
    mat = model.materials['Vazo_Seramik'] || model.materials.add('Vazo_Seramik')
    mat.color = Sketchup::Color.new(234, 228, 216)
    vase = model.active_entities.add_group
    vase.name = 'Halka Vazo 35cm'
    build_mesh(vase.entities, body_grid, true, mat, 'Govde')
    build_mesh(vase.entities, neck_grid, false, mat, 'Boyun')
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Vazo hazir.'
  rescue => e
    model.abort_operation
    puts "Hata: #{e.message}"
    raise
  end
end

DonutVase.run if defined?(Sketchup)
