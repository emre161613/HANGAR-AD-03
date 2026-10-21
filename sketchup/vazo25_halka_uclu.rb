# Halka (donut) uclu set - govdesinden bir yandan obur yana delik gecen
# yassi uc vazo: bej genis, siyah kucuk, beyaz uzun; ince boyunlu.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo25_halka_uclu.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module RingTrio
  extend self

  SCALE = 25.0 / 334.0 # bej vazo 25 cm

  # Her vazo (fotograf pikseli; y asagi dogru, base = taban y'si):
  #   outline: govde dis siluet noktalari (boyun haric, boyun dibinde kesilmis)
  #   hole: [merkez x, merkez y, yatay yari eksen, dusey yari eksen, egim (derece)]
  #   depth: govde yari kalinligi, neck: [[y, yari cap], ...] ustten asagi, neck_x
  VASES = [
    {
      name: 'Bej Halka', color: [196, 156, 118], base: 636, x0: 190, pos: [0, 0],
      depth: 68, neck_x: 220, mouth: 13,
      neck: [[302, 24.5], [316, 25.5], [330, 27], [346, 28]],
      hole: [141, 441, 50, 34, 22],
      outline: [
        [341, 441], [330, 421], [317, 404], [303, 388], [290, 375], [276, 363],
        [265, 351], [252, 338], [242, 327], [234, 318], [206, 318], [198, 327],
        [188, 336], [174, 345], [160, 353], [141, 368], [122, 382], [102, 397], [86, 409],
        [68, 425], [53, 441], [41, 462], [34, 489], [37, 517], [49, 544],
        [65, 572], [87, 606], [105, 630], [130, 642], [180, 643], [230, 643],
        [265, 640], [290, 632], [310, 620], [326, 605], [336, 590], [343, 565],
        [345, 540], [345, 510], [345, 480]
      ]
    },
    {
      name: 'Siyah Halka', color: [62, 62, 60], base: 681, x0: 400, pos: [215, -260],
      depth: 46, neck_x: 390, mouth: 13,
      neck: [[403, 25], [418, 26], [432, 27], [448, 28]],
      hole: [412, 555, 32, 28, 0],
      outline: [
        [492, 555], [489, 539], [483, 523], [474, 510], [464, 498], [452, 486],
        [439, 471], [432, 461], [422, 450], [414, 440], [408, 432], [372, 432],
        [366, 440], [358, 450], [350, 459], [340, 470], [328, 488], [318, 505],
        [312, 520], [309, 545], [308, 570], [308, 600], [309, 630], [312, 655],
        [320, 672], [335, 684], [360, 687], [412, 687], [452, 687], [467, 683],
        [474, 665], [479, 629], [486, 609], [490, 590], [492, 572]
      ]
    },
    {
      name: 'Beyaz Halka', color: [232, 228, 220], base: 636, x0: 576, pos: [386, 30],
      depth: 58, neck_x: 569, mouth: 12,
      neck: [[218, 22], [238, 24.5], [256, 26], [274, 27]],
      hole: [621, 408, 31, 46, -12],
      outline: [
        [520, 280], [503, 300], [490, 320], [478, 340], [470, 360], [465, 380],
        [462, 400], [459, 450], [461, 500], [470, 550], [486, 590], [500, 610],
        [520, 630], [545, 642], [600, 642], [625, 638], [645, 626], [660, 610],
        [672, 590], [687, 550], [693, 500], [693, 450], [689, 420], [684, 400],
        [677, 380], [668, 360], [655, 340], [640, 320], [625, 300], [610, 284],
        [600, 268], [594, 256], [546, 256], [539, 268], [530, 280]
      ]
    }
  ]

  SQUARE   = 0.7 # kesit kareligi (1 = elips, kucuk = daha duz yuzler)
  N_THETA  = 180
  N_PHI    = 72
  N_NECK   = 72

  def spow(v, e)
    v < 0 ? -(-v)**e : v**e
  end

  # Yumusak minimum (ince yerlerde kesit yuvarlaga doner)
  def softmin(a, b, p = 4)
    a * b / (a**p + b**p)**(1.0 / p)
  end

  # Fotograf pikselinden vazo koordinatina: [x, z]
  def to_local(v, px, py)
    [px - v[:x0].to_f, v[:base] - py.to_f]
  end

  # Kapali Catmull-Rom ile yumusatilmis siluet
  def outline_poly(v)
    pts = v[:outline].map { |px, py| to_local(v, px, py) }
    out = []
    n = pts.size
    n.times do |i|
      p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
      8.times do |k|
        t = k / 8.0
        out << [0, 1].map do |c|
          0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t +
                 (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t * t +
                 (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t**3)
        end
      end
    end
    out
  end

  # Delik merkezinden (dx, dz) yonundeki isinin siluete uzakligi
  def outer_dist(poly, hc, dx, dz)
    best = 0.0
    poly.each_index do |i|
      ax, az = poly[i]
      bx, bz = poly[(i + 1) % poly.size]
      ex = bx - ax
      ez = bz - az
      den = dx * ez - dz * ex
      next if den.abs < 1e-12
      qx = ax - hc[0]
      qz = az - hc[1]
      t = (qx * ez - qz * ex) / den
      s = (qx * dz - qz * dx) / den
      best = t if s >= 0 && s <= 1 && t > best
    end
    best
  end

  # Siluetin z yuksekligindeki yari genisligi (yatay kesisimler)
  def half_width(v, poly, z)
    @hw ||= {}
    key = [v[:name], (z / 2.0).round]
    @hw[key] ||= begin
      xs = []
      poly.each_index do |i|
        ax, az = poly[i]
        bx, bz = poly[(i + 1) % poly.size]
        next if (az - z) * (bz - z) > 0 || az == bz
        xs << ax + (bx - ax) * (z - az) / (bz - az)
      end
      xs.size >= 2 ? (xs.max - xs.min) / 2.0 : 1.0
    end
  end

  # Egik elips deligin ayni isin uzerindeki yaricapi
  def hole_dist(v, dx, dz)
    _, _, a, b, tilt = v[:hole]
    t = tilt * Math::PI / 180
    lx = dx * Math.cos(t) + dz * Math.sin(t)
    lz = -dx * Math.sin(t) + dz * Math.cos(t)
    1.0 / Math.sqrt((lx / a)**2 + (lz / b)**2)
  end

  # Govde kafesi: delik etrafinda donen, kesiti super-elips olan halka
  def body_grid(v)
    poly = outline_poly(v)
    hc = to_local(v, v[:hole][0], v[:hole][1])
    Array.new(N_THETA) do |i|
      th = 2 * Math::PI * i / N_THETA
      dx = Math.cos(th)
      dz = Math.sin(th)
      r_in = hole_dist(v, dx, dz)
      r_out = outer_dist(poly, hc, dx, dz)
      w = (r_out - r_in) / 2.0
      rc = (r_out + r_in) / 2.0
      d = softmin(v[:depth].to_f, 1.15 * w)
      Array.new(N_PHI) do |j|
        ph = -Math::PI + 2 * Math::PI * j / N_PHI
        rad = w * spow(Math.cos(ph), SQUARE)
        x = hc[0] + (rc + rad) * dx
        z = hc[1] + (rc + rad) * dz
        # kalinlik o yukseklikteki siluet genisligini gecmesin (boyun dibi yuvarlak kalir)
        y = softmin(d, 0.95 * half_width(v, poly, z)) * spow(Math.sin(ph), SQUARE)
        z = 0.0 if z < 0.0 # duz taban
        [x, y, z]
      end
    end
  end

  # Boyun: dikey eksen etrafinda donel; ust agiz acik, alt ucu govdenin icinde kapali
  def neck_grid(v)
    nx = v[:neck_x] - v[:x0].to_f
    prof = v[:neck].map { |py, r| [r.to_f, v[:base] - py.to_f] }.reverse # alttan yukari
    bottom = prof.first[1] - 25
    top = prof.last[1]
    m = v[:mouth].to_f
    rings = [[0.0, bottom]] + [[prof.first[0], bottom]] + prof +
            [[m, top], [m, top - 60], [0.0, top - 60]]
    rings.map do |r, z|
      Array.new(N_NECK) do |k|
        a = 2 * Math::PI * k / N_NECK
        [nx + r * Math.cos(a), r * Math.sin(a), z]
      end
    end
  end

  # Kafes -> ucgenler. wrap_rows: satirlar da kapali halka mi
  def grid_tris(grid, wrap_rows)
    rows = grid.size
    cols = grid[0].size
    tris = []
    last = wrap_rows ? rows : rows - 1
    last.times do |i|
      i2 = (i + 1) % rows
      cols.times do |j|
        j2 = (j + 1) % cols
        tris << [grid[i][j], grid[i][j2], grid[i2][j2]]
        tris << [grid[i][j], grid[i2][j2], grid[i2][j]]
      end
    end
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

  # Tum parcalar: [[ad, ucgenler], ...]; yuzleri disa bakacak sekilde
  def parts(v)
    body = orient(grid_tris(body_grid(v), true))
    neck = orient(grid_tris(neck_grid(v), false))
    [["#{v[:name]} Govde", body], ["#{v[:name]} Boyun", neck]]
  end

  # Isaretli hacim negatifse tum ucgenleri ters cevir
  def orient(tris)
    vol = tris.sum { |a, b, c| dot(a, cross(b, c)) }
    vol < 0 ? tris.map(&:reverse) : tris
  end

  # ---------- SketchUp ----------

  def add_mesh(ents, tris, mat)
    mesh = Geom::PolygonMesh.new(tris.size * 3, tris.size)
    index = {}
    tris.each do |tri|
      next unless good_triangle?(*tri)
      ids = tri.map do |p|
        key = p.map { |c| (c * 1e4).round }
        index[key] ||= mesh.add_point(Geom::Point3d.new((p[0] * SCALE).cm, (p[1] * SCALE).cm, (p[2] * SCALE).cm))
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - halka vazo seti olusturuluyor..."
    model.start_operation('Halka Uclu Vazo Seti', true)
    root = model.active_entities.add_group
    root.name = 'Halka Uclu Vazo Seti'
    VASES.each do |v|
      vg = root.entities.add_group
      vg.name = v[:name]
      mat = material(model, "Halka_#{v[:name].tr(' ', '_')}", v[:color])
      parts(v).each do |name, tris|
        grp = vg.entities.add_group
        grp.name = name
        add_mesh(grp.entities, tris, mat)
        soften(grp.entities, 0.6) # ~35 derece
      end
      x, y = v[:pos].map { |c| c * SCALE }
      vg.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x.cm, y.cm, 0)))
    end
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Set hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

RingTrio.run if defined?(Sketchup)
