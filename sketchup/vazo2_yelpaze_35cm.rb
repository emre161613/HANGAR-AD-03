# Damla vazo, delikli ve yelpaze desenli - 35 cm
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo2_yelpaze_35cm.rb"
#
# Eksenler: X = sag, Y = derinlik (on yuz -Y), Z = yukari. Olculer cm.

module FanVase
  extend self

  # ---- Govde dis siluet (x, z), saat yonunun tersine, kapali egri ----
  OUTLINE = [
    [-4.6, -0.5], [4.6, -0.5], [6.4, 1.1], [8.8, 3.9], [10.6, 8.5],
    [11.2, 13.4], [10.6, 18.4], [8.8, 23.0], [6.4, 26.5], [4.2, 29.0],
    [3.1, 30.5], [2.4, 31.2], [1.5, 31.4], [0.6, 31.2], [-0.2, 30.5],
    [-2.1, 28.3], [-4.6, 25.8], [-7.1, 23.0], [-9.5, 19.4], [-11.5, 14.8],
    [-12.2, 10.6], [-11.5, 6.4], [-9.2, 2.8], [-6.6, 0.4]
  ]

  # ---- Delik ----
  HOLE_CX   = 1.2
  HOLE_CZ   = 18.0
  HOLE_RX   = 3.4
  HOLE_RZ   = 8.4
  HOLE_TILT = -4.0  # derece
  HOLE_POW  = 1.8   # 2 = elips, kucuk = uclari daha sivri

  # ---- Kalinlik ----
  DEPTH   = 5.0     # govde yari kalinligi (toplam ~10 cm)
  NECK_D  = 2.0     # boyna yakin yari kalinlik
  SQUARE  = 0.65    # kesit kareligi (1 = elips)

  # ---- Boyun ----
  NECK_X = 1.5
  NECK_PROFILE = [
    [0.0, 29.8], [2.05, 29.8], [1.95, 30.6], [1.8, 31.6], [1.75, 32.6],
    [1.9, 33.7], [2.25, 34.5], [2.4, 34.85], [2.25, 35.0], [1.6, 35.0],
    [1.4, 34.5], [1.3, 33.5], [1.2, 32.6], [0.0, 32.4]
  ]

  # ---- Yelpaze (on yuzde, deligin solunda) ----
  FAN_PX = 1.0      # yelpazenin dondugu nokta (deligin alt ucu)
  FAN_PZ = 9.4
  # [aci (derece), yaricap (cm)] - yelpazenin dis siniri
  FAN_EDGE = [
    [88, 17.2], [98, 15.4], [111, 13.4], [131, 11.3], [156, 9.85],
    [181, 9.3], [204, 9.2], [226, 9.1], [244, 8.7], [251, 8.6]
  ]
  FAN_RIBS   = 20   # pli sayisi
  FAN_RECESS = 0.35 # oyuk derinligi
  FAN_AMP    = 0.9  # pli derinligi
  FAN_BOTH   = false # arka yuze de yelpaze

  # ---- Cozunurluk ----
  N_THETA_FAN  = 220 # yelpaze bolgesinde (sik)
  N_THETA_REST = 60
  N_PHI        = 200
  N_NECK       = 64

  def smooth(e0, e1, x)
    t = (x - e0) / (e1 - e0)
    t = 0.0 if t < 0.0
    t = 1.0 if t > 1.0
    t * t * (3 - 2 * t)
  end

  def spow(v, e)
    v < 0 ? -(-v)**e : v**e
  end

  # Kapali Catmull-Rom egrisi ile siluet noktalarini yumusat
  def outline_poly
    @outline_poly ||= begin
      pts = []
      n = OUTLINE.size
      n.times do |i|
        p0, p1, p2, p3 = OUTLINE[(i - 1) % n], OUTLINE[i], OUTLINE[(i + 1) % n], OUTLINE[(i + 2) % n]
        16.times do |k|
          t = k / 16.0
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

  # Delik merkezinden (dx, dz) yonundeki isinin siluete uzakligi
  def outer_dist(dx, dz)
    poly = outline_poly
    best = 0.0
    poly.each_index do |i|
      ax, az = poly[i]
      bx, bz = poly[(i + 1) % poly.size]
      ex = bx - ax
      ez = bz - az
      den = dx * ez - dz * ex
      next if den.abs < 1e-12
      qx = ax - HOLE_CX
      qz = az - HOLE_CZ
      t = (qx * ez - qz * ex) / den
      s = (qx * dz - qz * dx) / den
      best = t if s >= 0 && s <= 1 && t > best
    end
    best
  end

  def hole_dist(dx, dz)
    a = HOLE_TILT * Math::PI / 180
    lx = dx * Math.cos(a) + dz * Math.sin(a)
    lz = -dx * Math.sin(a) + dz * Math.cos(a)
    1.0 / ((lx.abs / HOLE_RX)**HOLE_POW + (lz.abs / HOLE_RZ)**HOLE_POW)**(1.0 / HOLE_POW)
  end

  def fan_edge_radius(deg)
    FAN_EDGE.each_cons(2) do |(a0, r0), (a1, r1)|
      return r0 + (r1 - r0) * (deg - a0) / (a1 - a0) if deg >= a0 && deg <= a1
    end
    nil
  end

  # (x, z) noktasindaki yelpaze oyugu: [agirlik, iceri derinlik]
  def fan_offset(x, z)
    rx = x - FAN_PX
    rz = z - FAN_PZ
    r = Math.sqrt(rx * rx + rz * rz)
    return [0.0, 0.0] if r < 1e-6
    deg = Math.atan2(rz, rx) * 180 / Math::PI
    deg += 360 if deg < 0
    a0 = FAN_EDGE.first[0]
    a1 = FAN_EDGE.last[0]
    return [0.0, 0.0] if deg <= a0 || deg >= a1
    rb = fan_edge_radius(deg)
    edge = smooth(0.0, 0.35, rb - r) * smooth(0.0, 1.5, deg - a0) * smooth(0.0, 1.5, a1 - deg)
    return [0.0, 0.0] if edge <= 0
    step = (a1 - a0) / FAN_RIBS
    wave = 0.5 - 0.5 * Math.cos(2 * Math::PI * (deg - a0) / step)
    k = r / rb
    pleat = FAN_AMP * wave * k**1.2 * smooth(1.5, 4.5, r)
    [edge, edge * (FAN_RECESS + pleat)]
  end

  def thetas
    a = 80.0 * Math::PI / 180
    b = 285.0 * Math::PI / 180
    rest = 2 * Math::PI - (b - a)
    Array.new(N_THETA_FAN) { |i| a + (b - a) * i / N_THETA_FAN } +
      Array.new(N_THETA_REST) { |i| b + rest * i / N_THETA_REST }
  end

  # Super-elips kesiti esit aralikli N_PHI noktaya bol: [[radyal, y], ...]
  # (esit aralik, yelpaze plilerinin duzgun cikmasi icin gerekli)
  def section(w, d)
    fine = Array.new(N_PHI * 4) do |k|
      ph = -Math::PI + 2 * Math::PI * k / (N_PHI * 4)
      [w * spow(Math.cos(ph), SQUARE), d * spow(Math.sin(ph), SQUARE)]
    end
    fine << fine[0]
    len = [0.0]
    (1...fine.size).each do |k|
      len << len[-1] + Math.hypot(fine[k][0] - fine[k - 1][0], fine[k][1] - fine[k - 1][1])
    end
    out = []
    k = 0
    N_PHI.times do |j|
      target = len[-1] * j / N_PHI
      k += 1 while len[k + 1] < target
      t = (target - len[k]) / (len[k + 1] - len[k])
      out << [fine[k][0] + (fine[k + 1][0] - fine[k][0]) * t,
              fine[k][1] + (fine[k + 1][1] - fine[k][1]) * t]
    end
    out
  end

  # Govde kafesi: her nokta [x, y, z, yelpaze_mi]
  def body_grid
    thetas.map do |th|
      dx = Math.cos(th)
      dz = Math.sin(th)
      r_in  = hole_dist(dx, dz)
      r_out = outer_dist(dx, dz)
      w  = (r_out - r_in) / 2.0
      rc = (r_out + r_in) / 2.0
      zc = HOLE_CZ + rc * dz
      d = DEPTH + (NECK_D - DEPTH) * smooth(20.0, 28.5, zc)
      section(w, d).map do |rad, y|
        x = HOLE_CX + (rc + rad) * dx
        z = HOLE_CZ + (rc + rad) * dz
        fan = false
        face_w = smooth(0.5, 0.8, y.abs / d)
        if y < 0 || FAN_BOTH
          wgt, off = fan_offset(x, z)
          if wgt > 0
            off *= face_w
            y += y < 0 ? off : -off
            fan = wgt * face_w > 0.05
          end
        end
        z = 0.0 if z < 0.0 # duz taban
        [x, y, z, fan]
      end
    end
  end

  def neck_grid
    NECK_PROFILE.map do |r, z|
      Array.new(N_NECK) do |k|
        a = 2 * Math::PI * k / N_NECK
        [NECK_X + r * Math.cos(a), r * Math.sin(a), z, false]
      end
    end
  end

  # Kafes -> ucgenler [[i,j],...], ve yelpaze ucgeni mi
  def triangles(grid, wrap_rows)
    rows = grid.size
    cols = grid[0].size
    list = []
    last = wrap_rows ? rows : rows - 1
    last.times do |i|
      i2 = (i + 1) % rows
      cols.times do |j|
        j2 = (j + 1) % cols
        q = [[i, j], [i, j2], [i2, j2], [i2, j]]
        fan = q.any? { |a, b| grid[a][b][3] }
        list << [[q[0], q[1], q[2]], fan]
        list << [[q[0], q[2], q[3]], fan]
      end
    end
    list
  end

  # ---- SketchUp ----
  def add_mesh(ents, grid, tris, mat)
    mesh = Geom::PolygonMesh.new(tris.size * 3, tris.size)
    tris.each do |tri|
      pts = tri.map { |i, j| v = grid[i][j]; Geom::Point3d.new(v[0].cm, v[1].cm, v[2].cm) }
      next if pts.uniq { |p| p.to_a }.size < 3
      ids = pts.map { |p| mesh.add_point(p) }
      next if ids.uniq.size < 3
      mesh.add_polygon(*ids)
    end
    flags = Geom::PolygonMesh::AUTO_SOFTEN | Geom::PolygonMesh::SMOOTH_SOFT_EDGES
    ents.add_faces_from_mesh(mesh, flags, mat, mat)
  end

  def build(ents, grid, wrap_rows, name, body_mat, fan_mat)
    grp = ents.add_group
    grp.name = name
    tris = triangles(grid, wrap_rows)
    plain = tris.reject { |_, f| f }.map { |t, _| t }
    fan   = tris.select { |_, f| f }.map { |t, _| t }
    add_mesh(grp.entities, grid, plain, body_mat)
    add_mesh(grp.entities, grid, fan, fan_mat) unless fan.empty?
    fix_normals(grp)
    grp
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - vazo olusturuluyor, lutfen bekleyin..."
    model.start_operation('Yelpaze Vazo', true)
    cream = material(model, 'Vazo2_Seramik', [234, 227, 214])
    gold  = material(model, 'Vazo2_Altin', [201, 163, 98])
    vase = model.active_entities.add_group
    vase.name = 'Yelpaze Vazo 35cm'
    build(vase.entities, body_grid, true, 'Govde', cream, gold)
    build(vase.entities, neck_grid, false, 'Boyun', cream, gold)
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Vazo hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

FanVase.run if defined?(Sketchup)
