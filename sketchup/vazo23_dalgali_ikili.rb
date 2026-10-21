# Dalgali asimetrik ikili - krem iki bogumlu damla vazo ve siyah, saga
# tasan dalgali omuzlu vazo; ikisi de ince uzun boyunlu.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo23_dalgali_ikili.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Siluetler fotograftan her 4 pikselde bir olculdu; SCALE ile cm'ye cevrilir.
# Her yukseklikte kesit, o satirdaki sol ve sag kenarin ortasinda bir dairedir;
# boylece fotograftaki yana tasmalar (asimetri) modele gecer.

module WobblePair
  extend self

  SCALE = 30.0 / 486.0 # krem vazo 30 cm

  # silhouette: [z, sol kenar x, sag kenar x] (px), alttan yukari
  # mouth: agiz yari capi, depth: agiz derinligi, size: perspektif payi, pos: [x, y] px
  VASES = [
    {
      name: 'Krem Dalgali', color: [214, 200, 178], size: 1.0, pos: [0, 0],
      mouth: 9, depth: 120,
      silhouette: [
        [0, -58, 116], [10, -75.4, 136.6], [14, -66.0, 137.4], [18, -64.6, 138.0], [22, -65.0, 141.4], [26, -67.6, 
        144.0], [30, -70.0, 147.8], [34, -74.6, 152.4], [38, -77.6, 155.4], [42, -79.6, 158.8], [46, -81.4, 161.8], 
        [50, -84.2, 164.4], [54, -88.0, 167.6], [58, -92.0, 169.8], [62, -93.6, 171.6], [66, -95.0, 175.2], [70, 
        -97.2, 176.8], [74, -99.8, 178.4], [78, -102.0, 180.2], [82, -104.2, 182.2], [86, -105.4, 184.2], [90, 
        -106.6, 186.2], [94, -107.4, 187.2], [98, -108.2, 188.2], [102, -109.6, 189.6], [106, -110.6, 191.0], [110, 
        -111.0, 191.6], [114, -110.8, 191.0], [118, -109.8, 191.0], [122, -108.4, 191.0], [126, -107.4, 191.0], [130, 
        -106.0, 190.8], [134, -105.4, 190.0], [138, -101.2, 189.4], [142, -98.4, 188.6], [146, -97.0, 187.4], [150, 
        -92.8, 185.0], [154, -89.2, 182.4], [158, -86.6, 180.8], [162, -81.6, 178.4], [166, -76.6, 176.2], [170, 
        -72.2, 174.4], [174, -68.6, 173.0], [178, -67.6, 171.0], [182, -66.0, 166.2], [186, -64.4, 160.8], [190, 
        -64.6, 157.4], [194, -66.2, 155.0], [198, -67.4, 150.6], [202, -69.2, 147.4], [206, -72.2, 144.8], [210, 
        -76.0, 140.8], [214, -81.0, 139.0], [218, -85.8, 137.6], [222, -90.6, 136.2], [226, -96.6, 133.6], [230, 
        -103.2, 130.8], [234, -108.4, 130.4], [238, -114.4, 130.6], [242, -117.6, 130.4], [246, -120.2, 128.2], [250, 
        -122.8, 126.4], [254, -124.4, 125.6], [258, -125.4, 125.0], [262, -126.6, 124.4], [266, -127.8, 124.0], [270, 
        -129.0, 124.0], [274, -129.8, 124.0], [278, -128.8, 124.0], [282, -128.0, 124.0], [286, -127.4, 124.2], [290, 
        -126.6, 124.4], [294, -125.6, 123.4], [298, -124.4, 122.4], [302, -122.2, 121.2], [306, -120.4, 119.2], [310, 
        -118.4, 118.4], [314, -115.8, 117.2], [318, -114.6, 115.8], [322, -112.2, 113.4], [326, -107.8, 111.2], [330, 
        -106.8, 108.6], [334, -105.2, 105.0], [338, -102.0, 102.4], [342, -98.0, 96.8], [346, -96.2, 95.2], [350, 
        -93.8, 93.2], [354, -91.2, 89.4], [358, -88.4, 87.6], [362, -85.0, 82.4], [366, -81.6, 78.2], [370, -77.6, 
        76.4], [374, -74.6, 72.0], [378, -70.2, 65.0], [382, -68.4, 61.6], [386, -66.8, 59.2], [390, -62.6, 55.2], 
        [394, -58.2, 46.8], [398, -55.8, 44.8], [402, -52.0, 41.4], [406, -48.4, 36.0], [410, -44.2, 31.8], [414, 
        -40.2, 29.2], [418, -37.0, 24.4], [422, -35.2, 21.6], [426, -33.2, 20.4], [430, -30.4, 18.0], [434, -27.6, 
        15.0], [438, -24.8, 14.2], [442, -22.0, 13.0], [446, -20.8, 11.8], [450, -20.0, 11.0], [454, -20.0, 10.2], 
        [458, -20.0, 9.8], [462, -20.6, 9.6], [466, -21.4, 10.0], [470, -22.0, 10.0], [474, -22.0, 10.0], [478, 
        -22.0, 10.0], [482, -22.4, 10.6], [486, -22.2, 10.4]
      ]
    },
    {
      name: 'Siyah Dalgali', color: [70, 66, 66], size: 1.08, pos: [320, 220],
      mouth: 12, depth: 140,
      silhouette: [
        [0, -120, 50], [5, -131.6, 55.4], [9, -135.0, 66.4], [13, -138.2, 72.8], [17, -139.5, 72.2], [21, -140.7, 
        70.2], [25, -141.9, 74.0], [29, -143.1, 79.6], [33, -144.3, 84.6], [37, -145.5, 89.0], [41, -146.7, 93.4], 
        [45, -147.9, 98.0], [49, -149.1, 102.0], [53, -150.4, 106.0], [57, -151.7, 109.6], [61, -153.1, 113.0], [65, 
        -154.5, 116.2], [69, -156.0, 119.4], [73, -157.3, 122.2], [77, -158.8, 125.0], [81, -160.1, 127.4], [85, 
        -161.6, 130.2], [89, -162.9, 132.6], [93, -164.4, 135.0], [97, -165.9, 137.6], [101, -167.3, 140.6], [105, 
        -168.8, 143.0], [109, -170.3, 145.6], [113, -171.8, 148.6], [117, -173.3, 151.4], [121, -174.8, 154.2], [125, 
        -176.3, 157.0], [129, -177.5, 159.8], [133, -178.4, 162.4], [137, -179.3, 165.0], [141, -180.3, 167.4], [145, 
        -181.2, 169.6], [149, -182.1, 172.4], [153, -183.1, 174.4], [157, -183.8, 175.6], [161, -183.7, 177.0], [165, 
        -183.4, 178.0], [169, -183.0, 178.0], [173, -182.7, 176.6], [177, -182.4, 176.6], [181, -182.0, 175.8], [185, 
        -180.5, 173.6], [189, -178.5, 169.0], [193, -176.5, 161.2], [197, -174.5, 153.4], [201, -172.4, 132.4], [205, 
        -169.2, 128.4], [209, -165.5, 110.0], [213, -161.8, 94.4], [217, -162.8, 88.8], [221, -162.0, 85.0], [225, 
        -159.2, 82.0], [229, -156.8, 80.0], [233, -154.6, 79.6], [237, -152.2, 81.4], [241, -150.2, 85.2], [245, 
        -148.2, 90.2], [249, -146.4, 96.4], [253, -144.6, 102.6], [257, -142.6, 108.2], [261, -140.2, 114.0], [265, 
        -138.0, 118.6], [269, -135.6, 121.6], [273, -133.0, 123.4], [277, -130.4, 124.4], [281, -127.6, 125.0], [285, 
        -124.6, 125.0], [289, -121.0, 124.4], [293, -117.6, 122.8], [297, -113.2, 120.6], [301, -109.0, 117.8], [305, 
        -105.0, 114.0], [309, -100.4, 110.2], [313, -95.8, 104.0], [317, -91.0, 97.2], [321, -86.6, 91.2], [325, 
        -81.8, 87.4], [329, -77.2, 81.6], [333, -72.8, 79.6], [337, -68.0, 75.6], [341, -63.4, 71.4], [345, -59.0, 
        67.0], [349, -55.2, 62.6], [353, -52.0, 58.4], [357, -48.0, 55.0], [361, -44.6, 51.2], [365, -41.0, 48.0], 
        [369, -37.8, 45.0], [373, -34.6, 42.4], [377, -32.0, 40.0], [381, -30.2, 37.8], [385, -28.6, 35.8], [389, 
        -27.4, 33.6], [393, -26.4, 31.4], [397, -25.2, 29.4], [401, -25.0, 28.2], [405, -24.8, 27.2], [409, -24.2, 
        26.2], [413, -23.8, 25.2], [417, -23.0, 24.6], [421, -23.0, 24.0], [425, -23.0, 23.8], [429, -23.0, 23.0], 
        [433, -23.0, 23.0], [437, -23.4, 23.0], [441, -23.8, 23.0], [445, -24.0, 23.0], [449, -24.0, 23.0], [453, 
        -24.6, 23.0], [457, -25.0, 23.0], [461, -25.0, 22.8], [465, -25.0, 22.6], [469, -25.8, 23.0], [473, -25.4, 
        23.0]
      ]
    }
  ]

  N_AROUND = 96

  def section(row)
    z, xl, xr = row
    xc = (xl + xr) / 2.0
    w = (xr - xl) / 2.0
    Array.new(N_AROUND) do |i|
      a = 2 * Math::PI * i / N_AROUND
      [xc + w * Math.cos(a), w * Math.sin(a), z.to_f]
    end
  end

  def strip(ring_a, ring_b, list)
    n = ring_a.size
    n.times do |i|
      j = (i + 1) % n
      list << [ring_a[i], ring_b[i], ring_b[j]]
      list << [ring_a[i], ring_b[j], ring_a[j]]
    end
  end

  def fan(center, rg, list, flip = false)
    n = rg.size
    n.times do |i|
      j = (i + 1) % n
      list << (flip ? [center, rg[j], rg[i]] : [center, rg[i], rg[j]])
    end
  end

  # Kapali govde: taban, yan yuz, ust halka, agiz deligi (px)
  # Fotograftaki doku/olcum gurultusunu temizlemek icin kenarlari komsu
  # satirlarla ortala (taban ve agiz satirlari aynen kalir)
  SMOOTH = 3

  def smoothed(sil)
    n = sil.size
    sil.each_with_index.map do |(z, l, r), i|
      next [z, l, r] if i.zero? || i == n - 1
      lo = [i - SMOOTH, 1].max
      hi = [i + SMOOTH, n - 2].min
      part = sil[lo..hi]
      [z, part.sum { |row| row[1] } / part.size.to_f, part.sum { |row| row[2] } / part.size.to_f]
    end
  end

  def vase_tris(v)
    sil = smoothed(v[:silhouette])
    rings = sil.map { |row| section(row) }
    tris = []
    z0, l0, r0 = sil.first
    fan([(l0 + r0) / 2.0, 0.0, z0.to_f], rings.first, tris, true)
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    zt, lt, rt = sil.last
    xc = (lt + rt) / 2.0
    mouth = Array.new(N_AROUND) do |i|
      a = 2 * Math::PI * i / N_AROUND
      [xc + v[:mouth] * Math.cos(a), v[:mouth] * Math.sin(a), zt.to_f]
    end
    strip(mouth, rings.last, tris)
    bottom = mouth.map { |x, y, _| [x, y, zt - v[:depth]] }
    strip(bottom, mouth, tris)
    fan([xc, 0.0, zt - v[:depth]], bottom, tris)
    tris
  end

  def cross(a, b)
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
  end

  def dot(a, b)
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
  end

  def good_triangle?(a, b, c, s)
    e1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]]
    e2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]]
    cr = cross(e1, e2)
    area2 = Math.sqrt(dot(cr, cr))
    edges = [[a, b], [b, c], [c, a]].map { |p, q| Math.sqrt((p[0] - q[0])**2 + (p[1] - q[1])**2 + (p[2] - q[2])**2) }
    edges.min * s > 0.005 && area2 * s * s > 1e-5
  end

  # ---- SketchUp ----
  def add_mesh(ents, tris, mat, s)
    mesh = Geom::PolygonMesh.new(tris.size * 3, tris.size)
    index = {}
    tris.each do |tri|
      next unless good_triangle?(*tri, s)
      ids = tri.map do |v|
        key = v.map { |c| (c * 1e6).round }
        index[key] ||= mesh.add_point(Geom::Point3d.new((v[0] * s).cm, (v[1] * s).cm, (v[2] * s).cm))
      end
      next if ids.uniq.size < 3
      mesh.add_polygon(*ids)
    end
    ents.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE, mat, mat)
  end

  # Egri yuzeylerde ince kenarlari yumusat
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - dalgali ikili vazo olusturuluyor..."
    model.start_operation('Dalgali Ikili Vazo', true)
    root = model.active_entities.add_group
    root.name = 'Dalgali Ikili Vazo'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = v[:name]
      mat = material(model, "Dalgali_#{v[:name].tr(' ', '_')}", v[:color])
      add_mesh(grp.entities, vase_tris(v), mat, SCALE * v[:size])
      soften(grp.entities, 0.6) # ~35 derece
      x, y = v[:pos].map { |c| c * SCALE }
      grp.transform!(Geom::Transformation.translation(Geom::Vector3d.new(x.cm, y.cm, 0)))
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

WobblePair.run if defined?(Sketchup)
