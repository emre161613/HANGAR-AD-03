# Kanat saksi - 35 cm (on yuzu katmanli tuylerle kapli, ustu acik saksi)
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo3_kanat_35cm.rb"
#
# Eksenler: X = sag, Y = derinlik (on yuz -Y), Z = yukari. Olculer cm.

module WingVase
  extend self

  # ---- Govde siluet (x, z), saat yonunun tersine ----
  # sol: kalin yuvarlak omurga, ust: saksi agzi, sag: tuylerin altindaki govde
  OUTLINE = [
    [-1.6, -0.5], [4.5, -0.5], [6.0, 8.0], [7.5, 15.0], [9.0, 21.0],
    [12.5, 26.0], [16.0, 30.0], [18.0, 33.2], [17.3, 35.0], [14.0, 34.2],
    [10.0, 33.0], [6.0, 31.8], [2.0, 31.0], [-1.0, 30.7], [-3.0, 30.3],
    [-5.2, 29.7], [-7.3, 28.0], [-8.7, 24.5], [-9.1, 20.0], [-8.8, 15.0],
    [-7.6, 10.7], [-5.8, 6.5], [-3.8, 3.0]
  ]
  # govdenin tuylerin altinda kalan sag kenari (asagidan yukari)
  RIGHT_EDGE = [
    [3.8, -8.0], [4.5, -0.5], [6.0, 8.0], [7.5, 15.0], [9.0, 21.0],
    [12.5, 26.0], [16.0, 30.0], [20.0, 34.6]
  ]
  CENTER_X = 2.0     # parametrelemenin merkezi (siluetin icinde)
  CENTER_Z = 17.0

  # ---- Kalinlik ----
  HALF_BOTTOM = 2.6  # tabanda yari kalinlik (toplam ~5 cm)
  HALF_TOP    = 5.5  # ustte yari kalinlik (toplam ~11 cm)
  PLATE_FRONT = 0.25 # govde disina tasan tuylerin arkasindaki levha
  PLATE_BACK  = 0.5

  # ---- Saksi agzi (ust kenar boyunca) ----
  POT_FROM  = 50.0   # merkeze gore acilar (derece)
  POT_TO    = 112.0
  POT_DEPTH = 5.0    # agiz derinligi
  POT_WALL  = 0.9    # dudak kalinligi

  # ---- Tuyler ----
  FEATHER_ROOT = [-1.6, 26.8] # tuylerin ciktigi nokta
  # [baslangic acisi (derece), uzunluk (cm), egrilik (derece/cm)]
  FEATHER_TABLE = [
    [-110, 27.0, 2.0], [-95, 28.0, 1.6], [-80, 26.0, 1.2], [-65, 22.0, 0.8],
    [-50, 18.5, 0.5], [-35, 17.5, 0.25], [-20, 18.0, 0.0], [-5, 19.0, -0.1],
    [20, 20.5, -0.2]
  ]
  # [tuy sayisi, uzunluk carpani, kabariklik (cm), aci kaydirma (aralik orani)]
  LAYERS = [
    [15, 1.00, 0.50, 0.0],
    [14, 0.68, 1.00, 0.5],
    [13, 0.40, 1.50, 0.0]
  ]
  FEATHER_W0 = 0.95  # tuy yari genisligi (kokte)
  FEATHER_W1 = 0.02  # uzunluk boyunca genisleme
  BEVEL      = 0.45  # tuy kenar yuvarlatma

  # ---- Cozunurluk ----
  N_THETA_WING  = 420 # tuylu taraf (sik)
  N_THETA_SPINE = 50  # duz omurga tarafi
  SPINE_FROM = 125.0  # omurga taraf acilari (derece)
  SPINE_TO   = 255.0
  N_FRONT = 90
  N_RIM   = 18
  N_BACK  = 30

  def smooth(e0, e1, x)
    t = (x - e0) / (e1 - e0)
    t = 0.0 if t < 0.0
    t = 1.0 if t > 1.0
    t * t * (3 - 2 * t)
  end

  def lerp_table(table, key, col)
    return table.first[col] if key <= table.first[0]
    return table.last[col] if key >= table.last[0]
    table.each_cons(2) do |a, b|
      next unless key >= a[0] && key <= b[0]
      t = (key - a[0]) / (b[0] - a[0]).to_f
      return a[col] + (b[col] - a[col]) * t
    end
  end

  # Kapali Catmull-Rom egrisi
  def outline_poly
    @outline_poly ||= begin
      pts = []
      n = OUTLINE.size
      n.times do |i|
        p0, p1, p2, p3 = OUTLINE[(i - 1) % n], OUTLINE[i], OUTLINE[(i + 1) % n], OUTLINE[(i + 2) % n]
        12.times do |k|
          t = k / 12.0
          t2 = t * t
          t3 = t2 * t
          pts << [0, 1].map do |c|
            0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t +
                   (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 +
                   (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3)
          end
        end
      end
      pts
    end
  end

  # Merkezden (dx, dz) yonundeki isinin govde siluetine uzakligi
  def body_dist(dx, dz)
    poly = outline_poly
    best = 0.0
    poly.each_index do |i|
      ax, az = poly[i]
      bx, bz = poly[(i + 1) % poly.size]
      ex = bx - ax
      ez = bz - az
      den = dx * ez - dz * ex
      next if den.abs < 1e-12
      qx = ax - CENTER_X
      qz = az - CENTER_Z
      t = (qx * ez - qz * ex) / den
      s = (qx * dz - qz * dx) / den
      best = t if s >= 0 && s <= 1 && t > best
    end
    best
  end

  # Her tuy: egri ekseni boyunca nokta listesi + kutu + katman bilgisi
  def feathers
    @feathers ||= begin
      list = []
      a_min = FEATHER_TABLE.first[0].to_f
      a_max = FEATHER_TABLE.last[0].to_f
      LAYERS.each do |count, len_k, height, shift|
        step = (a_max - a_min) / (count - 1)
        count.times do |n|
          a0 = a_min + step * (n + shift)
          next if a0 > a_max
          len = lerp_table(FEATHER_TABLE, a0, 1) * len_k
          len = 5.0 if len < 5.0
          bend = lerp_table(FEATHER_TABLE, a0, 2)
          x, z = FEATHER_ROOT
          ang = a0
          pts = [[x, z, 0.0]]
          segs = 10
          segs.times do |k|
            ds = len / segs
            mid = (ang + bend * ds / 2) * Math::PI / 180
            x += ds * Math.cos(mid)
            z += ds * Math.sin(mid)
            ang += bend * ds
            pts << [x, z, ds * (k + 1)]
          end
          wmax = FEATHER_W0 + FEATHER_W1 * len
          xs = pts.map { |p| p[0] }
          zs = pts.map { |p| p[1] }
          box = [xs.min - wmax, xs.max + wmax, zs.min - wmax, zs.max + wmax]
          list << { pts: pts, len: len, h: height, box: box }
        end
      end
      list
    end
  end

  # Tuy ekseni uzerindeki en yakin nokta: [uzaklik, s]
  def feather_dist(f, x, z)
    best = nil
    best_s = 0.0
    pts = f[:pts]
    (pts.size - 1).times do |k|
      ax, az, as = pts[k]
      bx, bz, bs = pts[k + 1]
      ex = bx - ax
      ez = bz - az
      ll = ex * ex + ez * ez
      t = ((x - ax) * ex + (z - az) * ez) / ll
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0
      px = ax + ex * t - x
      pz = az + ez * t - z
      d = px * px + pz * pz
      if best.nil? || d < best
        best = d
        best_s = as + (bs - as) * t
      end
    end
    [Math.sqrt(best), best_s]
  end

  def in_box?(f, x, z)
    b = f[:box]
    x >= b[0] && x <= b[1] && z >= b[2] && z <= b[3]
  end

  def inside_feather?(x, z)
    feathers.any? do |f|
      next false unless in_box?(f, x, z)
      d, s = feather_dist(f, x, z)
      d < FEATHER_W0 + FEATHER_W1 * s
    end
  end

  # On yuzdeki tuy kabarikligi (katmanlar ust uste: en yuksegi)
  def relief(x, z)
    best = 0.0
    feathers.each do |f|
      next unless in_box?(f, x, z)
      d, s = feather_dist(f, x, z)
      w = FEATHER_W0 + FEATHER_W1 * s
      next if d >= w
      h = (f[:h] + 0.35 * (1 - s / f[:len])) * smooth(0.0, BEVEL, w - d)
      best = h if h > best
    end
    best
  end

  # Isin boyunca tuylerin en uzak noktasi
  def feather_reach(dx, dz, r_from)
    r = 40.0
    r -= 0.1 while r > r_from && !inside_feather?(CENTER_X + r * dx, CENTER_Z + r * dz)
    return r_from if r <= r_from
    lo = r
    hi = r + 0.1
    8.times do
      mid = (lo + hi) / 2
      if inside_feather?(CENTER_X + mid * dx, CENTER_Z + mid * dz) then lo = mid else hi = mid end
    end
    lo
  end

  # Govde agirligi: sag kenarin solunda 1, tuylerin tek kaldigi yerde 0
  def body_weight(x, z)
    best = nil
    sign = 1.0
    (RIGHT_EDGE.size - 1).times do |k|
      ax, az = RIGHT_EDGE[k]
      bx, bz = RIGHT_EDGE[k + 1]
      ex = bx - ax
      ez = bz - az
      t = ((x - ax) * ex + (z - az) * ez) / (ex * ex + ez * ez)
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0
      d = Math.hypot(ax + ex * t - x, az + ez * t - z)
      next unless best.nil? || d < best
      best = d
      sign = (ex * (z - az) - ez * (x - ax)) >= 0 ? 1.0 : -1.0
    end
    smooth(-0.5, 8.0, best * sign)
  end

  def half_thickness(z)
    HALF_BOTTOM + (HALF_TOP - HALF_BOTTOM) * smooth(3.0, 27.0, z)
  end

  def deg_of(th)
    (th * 180 / Math::PI) % 360
  end

  def thetas
    a = SPINE_FROM * Math::PI / 180
    b = SPINE_TO * Math::PI / 180
    wing = 2 * Math::PI - (b - a)
    Array.new(N_THETA_SPINE) { |i| a + (b - a) * i / N_THETA_SPINE } +
      Array.new(N_THETA_WING) { |i| b + wing * i / N_THETA_WING }
  end

  # Kafes: her satir bir aci, her nokta [x, y, z, toprak_mi]
  def body_grid
    thetas.map do |th|
      dx = Math.cos(th)
      dz = Math.sin(th)
      r_body = body_dist(dx, dz)
      r_out = feather_reach(dx, dz, r_body)
      deg = deg_of(th)
      wt = smooth(POT_FROM, POT_FROM + 8, deg) * (1 - smooth(POT_TO - 8, POT_TO, deg))

      # bu isin uzerindeki on/arka kalinlik (saksi agzina dogru kase gibi incelir)
      bowl_end = r_out
      thick = lambda do |r|
        x = CENTER_X + r * dx
        z = CENTER_Z + r * dz
        m = body_weight(x, z)
        t = half_thickness(z) * (1 - 0.3 * wt * smooth(bowl_end - 5.0, bowl_end, r)**1.5)
        front = t * m + PLATE_FRONT * (1 - m) + relief(x, z)
        back = t * m + PLATE_BACK * (1 - m)
        [x, z, front, back]
      end

      # kenar: yuvarlak (wt=0) ya da saksi agzi (wt=1)
      _, _, f_rim, b_rim = thick.call(r_out)
      q = (f_rim + b_rim) / 2
      r_lip = r_out - (1 - wt) * q
      _, _, f_lip, b_lip = thick.call(r_lip)
      row = []

      N_FRONT.times do |k|
        r = r_lip * k / N_FRONT
        x, z, f, = thick.call(r)
        row << [x, -f, z, false]
      end

      N_RIM.times do |k|
        psi = Math::PI * k / N_RIM
        c_dr = -q + q * Math.sin(psi)
        c_y = -f_lip + (f_lip + b_lip) * (1 - Math.cos(psi)) / 2
        lip = Math::PI / 6
        if psi < lip
          be = Math::PI * psi / lip
          t_dr = POT_WALL / 2 * Math.sin(be)
          t_y = -f_lip + POT_WALL / 2 * (1 - Math.cos(be))
        elsif psi > Math::PI - lip
          be = Math::PI * (psi - (Math::PI - lip)) / lip
          t_dr = POT_WALL / 2 * Math.sin(be)
          t_y = b_lip - POT_WALL + POT_WALL / 2 * (1 - Math.cos(be))
        else
          ga = Math::PI * (psi - lip) / (Math::PI - 2 * lip)
          t_dr = -POT_DEPTH * Math.sin(ga)
          y0 = -f_lip + POT_WALL
          y1 = b_lip - POT_WALL
          t_y = y0 + (y1 - y0) * (1 - Math.cos(ga)) / 2
        end
        dr = (1 - wt) * c_dr + wt * t_dr
        y = (1 - wt) * c_y + wt * t_y
        r = r_out + dr
        soil = wt > 0.5 && psi > Math::PI / 3 && psi < 2 * Math::PI / 3
        row << [CENTER_X + r * dx, y, CENTER_Z + r * dz, soil]
      end

      (0..N_BACK).each do |k|
        r = r_lip * (N_BACK - k) / N_BACK
        x, z, _, b = thick.call(r)
        row << [x, b, z, false]
      end

      row.map { |x, y, z, s| [x, y, z < 0.0 ? 0.0 : z, s] }
    end
  end

  # Kafes -> ucgenler (satirlar kapali, sutunlar acik), toprak ucgeni mi
  def triangles(grid)
    rows = grid.size
    cols = grid[0].size
    list = []
    rows.times do |i|
      i2 = (i + 1) % rows
      (cols - 1).times do |j|
        q = [[i, j], [i, j + 1], [i2, j + 1], [i2, j]]
        soil = q.any? { |a, b| grid[a][b][3] }
        list << [[q[0], q[1], q[2]], soil]
        list << [[q[0], q[2], q[3]], soil]
      end
    end
    list
  end

  # Cok kucuk ya da duz cizgi olan ucgenleri at (SketchUp bunlari yuz yapamaz)
  def good_triangle?(a, b, c)
    e1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]]
    e2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]]
    cx = e1[1] * e2[2] - e1[2] * e2[1]
    cy = e1[2] * e2[0] - e1[0] * e2[2]
    cz = e1[0] * e2[1] - e1[1] * e2[0]
    area2 = Math.sqrt(cx * cx + cy * cy + cz * cz)
    min_edge = [[a, b], [b, c], [c, a]].map { |p, r| Math.sqrt((p[0] - r[0])**2 + (p[1] - r[1])**2 + (p[2] - r[2])**2) }.min
    min_edge > 0.005 && area2 > 1e-5
  end

  # ---- SketchUp ----
  def add_mesh(ents, grid, tris, mat)
    mesh = Geom::PolygonMesh.new(tris.size * 3, tris.size)
    index = {}
    tris.each do |tri|
      vs = tri.map { |i, j| grid[i][j] }
      next unless good_triangle?(*vs)
      ids = vs.map do |v|
        key = [v[0], v[1], v[2]]
        index[key] ||= mesh.add_point(Geom::Point3d.new(v[0].cm, v[1].cm, v[2].cm))
      end
      next if ids.uniq.size < 3
      mesh.add_polygon(*ids)
    end
    flags = Geom::PolygonMesh::AUTO_SOFTEN | Geom::PolygonMesh::SMOOTH_SOFT_EDGES
    ents.add_faces_from_mesh(mesh, flags, mat, mat)
  end

  # En sagdaki yuz disari bakmiyorsa tum yuzleri cevir
  def fix_normals(grp)
    faces = grp.entities.grep(Sketchup::Face)
    right = faces.max_by { |f| f.bounds.center.x }
    faces.each(&:reverse!) if right && right.normal.x < 0
  end

  def material(model, name, rgb)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  def run
    model = Sketchup.active_model
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - kanat saksi olusturuluyor, lutfen bekleyin..."
    grid = body_grid
    puts 'Geometri hesaplandi, yuzeyler olusturuluyor...'
    model.start_operation('Kanat Saksi', true)
    cream = material(model, 'Kanat_Seramik', [236, 231, 221])
    soil  = material(model, 'Kanat_Toprak', [86, 66, 50])
    grp = model.active_entities.add_group
    grp.name = 'Kanat Saksi 35cm'
    tris = triangles(grid)
    add_mesh(grp.entities, grid, tris.reject { |_, s| s }.map { |t, _| t }, cream)
    add_mesh(grp.entities, grid, tris.select { |_, s| s }.map { |t, _| t }, soil)
    fix_normals(grp)
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Saksi hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

WingVase.run if defined?(Sketchup)
