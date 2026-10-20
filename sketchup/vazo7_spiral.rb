# Spiral seritli vazo - damla govde, ince boyun, egik boru agiz;
# boyna sarilan yassi serit altta kucuk bir yumruda govdeye baglaniyor.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo7_spiral.rb"
#
# Eksenler: X = sag, Y = derinlik (on yuz -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.

module SpiralVase
  extend self

  SCALE = 45.0 / 845.0 # toplam yukseklik ~45 cm

  # ---- Govde dis profili [yukseklik, yari cap] ----
  OUTER = [
    [0, 34], [10, 58], [20, 77], [40, 96], [60, 105], [80, 109], [100, 112],
    [130, 114], [160, 114], [200, 110], [240, 103], [280, 93], [320, 82],
    [360, 71], [400, 62], [440, 52], [480, 42], [520, 34], [560, 30],
    [600, 27.5], [640, 26], [680, 28], [720, 32], [750, 38], [770, 44],
    [790, 53], [810, 63], [830, 72], [845, 76]
  ]
  # Eksenin yana kaymasi [yukseklik, dx]: boru agiz saga dogru acilir
  AXIS_DX = [[0, 6], [400, 6], [480, 0], [600, -6], [700, -6], [740, 0], [780, 12], [845, 34]]
  WALL     = 5.0   # agizdaki cidar
  CAVITY_Z = 600.0 # agizdan iceri bakan oyugun tabani
  # agiz kesimi: z = TOP_Z0 + TOP_SX * X + TOP_SY * Y
  TOP_Z0 = 834.0
  TOP_SX = 0.07
  TOP_SY = 0.06

  # ---- Spiral serit ----
  RIB_Z_START = 761.5  # spiralin baslangic yuksekligi (egim haric)
  RIB_TURNS   = 3.575  # toplam tur
  RIB_PITCH   = 84.6   # bir turda inis
  RIB_TILT    = 0.30   # halkalar sola dogru yukselir (egik halka gorunumu)
  # [aci (derece), yaricap]: asagi indikce boyna yaklasir
  RIB_RADIUS  = [[0, 105], [360, 100], [720, 95], [1080, 85], [1200, 70], [1287, 56]]
  RIB_HALF_W  = 13.0   # serit yari genisligi (dusey)
  RIB_HALF_T  = 4.0    # serit yari kalinligi
  RIB_TIP     = 10.0   # serbest ucun yuvarlanma acisi (derece)

  # ---- Yumru (seridin bittigi yer) ----
  KNOB_C = [-50.0, -25.0, 474.0]
  KNOB_R = [22.0, 22.0, 27.0]

  # ---- Cozunurluk ----
  N_AROUND = 96
  N_ROWS   = 120
  RIB_STEP = 3.0 # derece
  RIB_SEC  = 20  # kesit noktasi

  def smooth_profile(table, per = 6)
    pr = table.map { |z, r| [z.to_f, r.to_f] }
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

  def interp(pr, z)
    (pr.size - 1).times do |i|
      z0, r0 = pr[i]
      z1, r1 = pr[i + 1]
      next if z1 == z0
      return r0 + (r1 - r0) * (z - z0) / (z1 - z0) if z >= z0 && z <= z1
    end
    z < pr[0][0] ? pr[0][1] : pr[-1][1]
  end

  def outer_r(z)
    @outer ||= smooth_profile(OUTER)
    interp(@outer, z)
  end

  def inner_r(z)
    outer_r(z) - WALL
  end

  def axis_dx(z)
    @axis ||= smooth_profile(AXIS_DX)
    interp(@axis, z)
  end

  def body_point(r, phi, z)
    [axis_dx(z) + r * Math.cos(phi), r * Math.sin(phi), z]
  end

  def top_z(x, y)
    TOP_Z0 + TOP_SX * x + TOP_SY * y
  end

  def find_top(phi)
    f = lambda do |z|
      p = body_point(yield(z), phi, z)
      z - top_z(p[0], p[1])
    end
    lo = 700.0
    hi = OUTER.last[0].to_f
    60.times do
      mid = (lo + hi) / 2
      if f.call(mid) < 0 then lo = mid else hi = mid end
    end
    (lo + hi) / 2
  end

  def strip(ring_a, ring_b, list)
    n = ring_a.size
    n.times do |i|
      j = (i + 1) % n
      list << [ring_a[i], ring_b[i], ring_b[j]]
      list << [ring_a[i], ring_b[j], ring_a[j]]
    end
  end

  def fan(center, ring, list, flip = false)
    n = ring.size
    n.times do |i|
      j = (i + 1) % n
      list << (flip ? [center, ring[j], ring[i]] : [center, ring[i], ring[j]])
    end
  end

  # ---- Govde: dis yuz, egik agiz halkasi, agiz ici, oyuk tabani, alt taban ----
  def body_tris
    tris = []
    tops_o = []
    tops_i = []
    N_AROUND.times do |i|
      phi = 2 * Math::PI * i / N_AROUND
      tops_o << find_top(phi) { |z| outer_r(z) }
      tops_i << find_top(phi) { |z| inner_r(z) }
    end
    outer = Array.new(N_ROWS + 1) do |k|
      Array.new(N_AROUND) do |i|
        phi = 2 * Math::PI * i / N_AROUND
        # alt kisimda sik, ustte kesime kadar esit aralik
        z = tops_o[i] * k / N_ROWS
        body_point(outer_r(z), phi, z)
      end
    end
    rows_in = 30
    inner = Array.new(rows_in + 1) do |k|
      Array.new(N_AROUND) do |i|
        phi = 2 * Math::PI * i / N_AROUND
        z = tops_i[i] - (tops_i[i] - CAVITY_Z) * k / rows_in
        body_point(inner_r(z), phi, z)
      end
    end
    N_ROWS.times { |k| strip(outer[k + 1], outer[k], tris) }
    strip(inner[0], outer[N_ROWS], tris)
    rows_in.times { |k| strip(inner[k + 1], inner[k], tris) }
    fan([axis_dx(CAVITY_Z), 0.0, CAVITY_Z], inner[rows_in], tris)
    fan([axis_dx(0), 0.0, 0.0], outer[0], tris, true)
    tris
  end

  # ---- Spiral serit ----
  def rib_center(deg)
    a = deg * Math::PI / 180
    r = interp(RIB_RADIUS.map { |d, rr| [d.to_f, rr.to_f] }, deg)
    x = r * Math.cos(a)
    [x, r * Math.sin(a), RIB_Z_START - RIB_PITCH * deg / 360.0 - RIB_TILT * x]
  end

  def sub(a, b)
    [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
  end

  def norm(a)
    l = Math.sqrt(a[0]**2 + a[1]**2 + a[2]**2)
    [a[0] / l, a[1] / l, a[2] / l]
  end

  def rib_tris
    tris = []
    total = RIB_TURNS * 360
    steps = (total / RIB_STEP).ceil
    sections = (0..steps).map do |k|
      deg = total * k / steps
      c = rib_center(deg)
      t = norm(sub(rib_center(deg + 0.5), rib_center(deg - 0.5)))
      up = [0.0, 0.0, 1.0]
      w = norm(sub(up, [t[0] * t[2], t[1] * t[2], t[2] * t[2]])) # dusey, teget'e dik
      v = cross(t, w) # disa dogru kalinlik yonu
      # serbest uc yuvarlak
      s = deg < RIB_TIP ? Math.sqrt([1 - ((RIB_TIP - deg) / RIB_TIP)**2, 0.0004].max) : 1.0
      Array.new(RIB_SEC) do |j|
        a = 2 * Math::PI * j / RIB_SEC
        cw = Math.cos(a)
        sv = Math.sin(a)
        # yuvarlak koseli dikdortgen kesit (super-elips)
        pw = RIB_HALF_W * s * (cw < 0 ? -(-cw)**0.5 : cw**0.5)
        pv = RIB_HALF_T * (sv < 0 ? -(-sv)**0.5 : sv**0.5)
        [c[0] + w[0] * pw + v[0] * pv, c[1] + w[1] * pw + v[1] * pv, c[2] + w[2] * pw + v[2] * pv]
      end
    end
    steps.times { |k| strip(sections[k + 1], sections[k], tris) }
    fan(rib_center(0), sections.first, tris, true)
    fan(rib_center(total), sections.last, tris)
    tris
  end

  # ---- Yumru: elipsoid ----
  def knob_tris
    tris = []
    n_lat = 16
    rings = (1...n_lat).map do |k|
      b = Math::PI * k / n_lat
      Array.new(N_AROUND / 2) do |i|
        a = 2 * Math::PI * i / (N_AROUND / 2)
        [KNOB_C[0] + KNOB_R[0] * Math.sin(b) * Math.cos(a),
         KNOB_C[1] + KNOB_R[1] * Math.sin(b) * Math.sin(a),
         KNOB_C[2] - KNOB_R[2] * Math.cos(b)]
      end
    end
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    fan([KNOB_C[0], KNOB_C[1], KNOB_C[2] - KNOB_R[2]], rings.first, tris, true)
    fan([KNOB_C[0], KNOB_C[1], KNOB_C[2] + KNOB_R[2]], rings.last, tris)
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
    [
      ['Govde', [[body_tris, :body]]],
      ['Spiral Serit', [[rib_tris, :body]]],
      ['Yumru', [[knob_tris, :body]]]
    ]
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

  # Egri yuzeylerde ince kenarlari yumusat, keskin kenarlari birak
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - spiral vazo olusturuluyor..."
    list = parts
    model.start_operation('Spiral Vazo', true)
    mats = { body: material(model, 'Vazo7_Kirik_Beyaz', [234, 226, 218]) }
    root = model.active_entities.add_group
    root.name = 'Spiral Vazo'
    list.each do |name, pieces|
      grp = root.entities.add_group
      grp.name = name
      pieces.each { |tris, mat| add_mesh(grp.entities, tris, mats[mat]) }
      soften(grp.entities, 0.6) # ~35 derece
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

SpiralVase.run if defined?(Sketchup)
