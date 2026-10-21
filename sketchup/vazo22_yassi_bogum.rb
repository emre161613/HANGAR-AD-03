# Yassi bogumlu vazo - onden bakinca iki genis kanatli (lob) siluet, yandan
# ince; ortasi hafif sirtli yastik kesitli govde, ince yuvarlak boyun, kucuk ayak.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo22_yassi_bogum.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Siluet fotograftan her 4 pikselde bir olculdu; SCALE ile cm'ye cevrilir.

module FlatLobeVase
  extend self

  SCALE = 35.0 / 902.0 # vazo 35 cm

  # Siluet: [z, sol kenar x, sag kenar x] (px), alttan yukari
  SILHOUETTE = [
    [0, -84.4, 97.4], [6, -89.6, 101.2], [10, -94.4, 102.4], [14, -97.2, 104.2], [18, -100.8, 105.6],
    [22, -102.8, 107.0], [26, -104.4, 109.0], [30, -106.8, 111.0], [34, -109.2, 113.6], [38, -111.2, 116.2], [42, -113.2, 118.6],
    [46, -115.4, 121.4], [50, -118.8, 125.0], [54, -121.8, 129.2], [58, -124.6, 133.8], [62, -129.0, 139.0], [66, -133.0, 144.4],
    [70, -136.8, 150.4], [74, -141.4, 155.8], [78, -145.6, 163.0], [82, -150.0, 170.2], [86, -155.8, 178.2], [90, -160.8, 187.4],
    [94, -165.8, 195.4], [98, -171.4, 205.0], [102, -177.2, 214.2], [106, -185.0, 225.2], [110, -191.8, 235.8], [114, -200.6, 246.6],
    [118, -209.6, 258.6], [122, -221.0, 270.0], [126, -232.6, 282.2], [130, -247.8, 293.0], [134, -262.4, 303.2], [138, -277.8, 313.0],
    [142, -291.6, 322.0], [146, -303.2, 331.0], [150, -312.4, 338.0], [154, -322.8, 344.2], [158, -331.0, 349.6], [162, -337.6, 354.8],
    [166, -343.2, 359.2], [170, -349.0, 363.6], [174, -353.0, 368.0], [178, -358.2, 371.2], [182, -362.4, 374.2], [186, -365.4, 378.0],
    [190, -368.8, 381.6], [194, -371.8, 384.6], [198, -374.4, 386.8], [202, -377.2, 388.4], [206, -379.6, 389.6], [210, -382.2, 391.2],
    [214, -384.4, 392.4], [218, -386.4, 393.4], [222, -387.4, 394.2], [226, -388.2, 395.0], [230, -389.4, 395.4], [234, -390.4, 396.0],
    [238, -391.2, 396.0], [242, -392.0, 396.0], [246, -392.6, 396.0], [250, -393.0, 396.0], [254, -393.0, 395.2], [258, -393.0, 394.4],
    [262, -393.0, 393.6], [266, -393.0, 392.6], [270, -392.4, 391.6], [274, -390.8, 390.0], [278, -389.6, 388.4], [282, -388.2, 386.4],
    [286, -385.8, 383.4], [290, -383.8, 380.6], [294, -381.0, 377.8], [298, -378.6, 375.0], [302, -376.4, 371.0], [306, -373.0, 367.6],
    [310, -369.8, 364.0], [314, -366.0, 360.0], [318, -360.6, 354.6], [322, -354.6, 348.8], [326, -348.2, 341.6], [330, -340.0, 333.0],
    [334, -331.0, 322.2], [338, -318.4, 307.4], [342, -301.0, 277.6], [346, -283.6, 241.6], [350, -261.4, 209.4], [354, -235.8, 190.8],
    [358, -211.6, 177.8], [362, -194.2, 167.4], [366, -182.0, 159.2], [370, -173.0, 152.8], [374, -167.0, 148.2], [378, -161.6, 144.6],
    [382, -157.2, 141.6], [386, -154.0, 139.0], [390, -150.8, 136.8], [394, -148.6, 135.2], [398, -146.6, 134.0], [402, -144.6, 132.8],
    [406, -143.8, 132.4], [410, -143.0, 133.0], [414, -143.0, 133.6], [418, -143.0, 134.8], [422, -144.0, 136.2], [426, -145.2, 138.8],
    [430, -147.0, 142.0], [434, -150.0, 146.8], [438, -153.6, 153.0], [442, -158.0, 160.2], [446, -164.6, 168.0], [450, -173.0, 177.8],
    [454, -183.2, 189.4], [458, -200.8, 204.4], [462, -220.4, 223.0], [466, -241.8, 241.6], [470, -266.4, 255.2], [474, -284.2, 268.2],
    [478, -297.0, 279.6], [482, -310.0, 289.0], [486, -320.6, 298.2], [490, -328.2, 308.6], [494, -335.4, 317.0], [498, -342.4, 323.4],
    [502, -347.4, 329.4], [506, -352.0, 335.6], [510, -356.8, 340.4], [514, -360.8, 344.0], [518, -364.4, 347.6], [522, -367.2, 350.8],
    [526, -369.2, 353.4], [530, -372.4, 356.0], [534, -374.0, 358.0], [538, -375.2, 359.6], [542, -376.2, 361.4], [546, -377.0, 363.0],
    [550, -377.0, 364.4], [554, -377.0, 365.0], [558, -377.0, 365.2], [562, -377.0, 366.0], [566, -377.0, 366.0], [570, -377.0, 366.0],
    [574, -376.4, 366.0], [578, -376.0, 366.0], [582, -375.0, 366.0], [586, -374.0, 365.8], [590, -373.6, 365.0], [594, -372.4, 364.2],
    [598, -371.0, 363.4], [602, -369.6, 362.0], [606, -367.6, 360.0], [610, -365.6, 357.8], [614, -363.8, 356.0], [618, -360.8, 353.6],
    [622, -357.2, 350.4], [626, -354.0, 347.2], [630, -350.4, 344.2], [634, -346.2, 340.4], [638, -340.8, 336.0], [642, -335.8, 330.8],
    [646, -330.0, 325.4], [650, -323.4, 319.2], [654, -316.8, 312.2], [658, -307.6, 306.8], [662, -298.2, 299.4], [666, -288.8, 291.2],
    [670, -278.6, 280.6], [674, -268.2, 269.0], [678, -256.8, 254.6], [682, -245.8, 238.4], [686, -234.2, 222.0], [690, -222.4, 207.4],
    [694, -210.8, 193.6], [698, -199.8, 181.4], [702, -188.2, 169.4], [706, -178.6, 158.6], [710, -167.2, 148.2], [714, -157.4, 138.6],
    [718, -149.4, 130.0], [722, -142.6, 122.4], [726, -136.8, 116.0], [730, -131.4, 110.8], [734, -127.0, 105.6], [738, -123.0, 100.8],
    [742, -118.2, 96.0], [746, -113.4, 92.8], [750, -110.2, 89.2], [754, -107.4, 86.2], [758, -104.8, 83.8], [762, -102.8, 81.4],
    [766, -101.2, 79.2], [770, -99.0, 77.4], [774, -97.0, 76.0], [778, -95.6, 74.2], [782, -94.6, 73.0], [786, -93.8, 71.6],
    [790, -92.8, 70.8], [794, -91.8, 70.0], [798, -90.6, 69.8], [802, -89.6, 68.8], [806, -88.6, 68.0], [810, -88.0, 67.4],
    [814, -87.8, 66.6], [818, -87.0, 65.8], [822, -86.6, 64.8], [826, -86.0, 63.8], [830, -85.6, 63.0], [834, -85.0, 62.8],
    [838, -85.0, 62.6], [842, -84.8, 61.6], [846, -83.8, 61.0], [850, -83.0, 61.0], [854, -83.0, 60.6], [858, -83.0, 60.0],
    [862, -82.8, 59.4], [866, -82.0, 59.0], [870, -82.0, 58.6], [874, -81.6, 58.0], [878, -81.0, 57.8], [882, -80.6, 56.6],
    [886, -79.8, 55.2], [890, -79.0, 54.0], [894, -78.2, 53.8], [898, -76.6, 52.6], [902, -74.8, 51.4],
  ]

  # Kesit: kenarlardan ortaya dogru kalinlasan yastik sekli
  # ortadaki yari kalinlik = CENTER_T0 + CENTER_TK * yari genislik (px);
  # kanatlarda ~10 cm, belde ~7 cm; boyunda kesit yuvarlaga doner
  CENTER_T0 = 70.0
  CENTER_TK = 0.15
  EDGE_T    = 34.0 # kanat ucundaki yari kalinlik (px)
  RIDGE    = 1.7   # 1 = ortada belirgin sirt, 2 = yumusak yuvarlak

  # Agiz
  MOUTH_R  = 24.0
  MOUTH_D  = 160.0

  N_AROUND = 112

  # Yumusak minimum: iki deger arasinda keskin kirilma olmadan gecis
  def softmin(a, b, p = 6)
    a * b / (a**p + b**p)**(1.0 / p)
  end

  def section(zl_xl_xr)
    z, xl, xr = zl_xl_xr
    xc = (xl + xr) / 2.0
    w = (xr - xl) / 2.0
    tc = softmin(w, CENTER_T0 + CENTER_TK * w)
    te = softmin(w, EDGE_T)
    Array.new(N_AROUND) do |i|
      a = 2 * Math::PI * i / N_AROUND
      c = Math.cos(a)
      s = Math.sin(a)
      t = te + (tc - te) * (1 - c.abs**RIDGE)
      [xc + w * c, t * s, z.to_f]
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
  def vase_tris
    rings = SILHOUETTE.map { |row| section(row) }
    tris = []
    z0, l0, r0 = SILHOUETTE.first
    fan([(l0 + r0) / 2.0, 0.0, z0.to_f], rings.first, tris, true)
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    zt, lt, rt = SILHOUETTE.last
    xc = (lt + rt) / 2.0
    mouth = Array.new(N_AROUND) do |i|
      a = 2 * Math::PI * i / N_AROUND
      [xc + MOUTH_R * Math.cos(a), MOUTH_R * Math.sin(a), zt.to_f]
    end
    strip(mouth, rings.last, tris)
    bottom = mouth.map { |x, y, _| [x, y, zt - MOUTH_D] }
    strip(bottom, mouth, tris)
    fan([xc, 0.0, zt - MOUTH_D], bottom, tris)
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

  def run
    model = Sketchup.active_model
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - yassi bogumlu vazo olusturuluyor..."
    tris = vase_tris
    model.start_operation('Yassi Bogumlu Vazo', true)
    mat = model.materials['Yassi_Kirmizi_Kil'] || model.materials.add('Yassi_Kirmizi_Kil')
    mat.color = Sketchup::Color.new(140, 62, 46)
    grp = model.active_entities.add_group
    grp.name = 'Yassi Bogumlu Vazo'
    add_mesh(grp.entities, tris, mat)
    soften(grp.entities, 0.6) # ~35 derece
    model.commit_operation
    model.active_view.zoom_extents
    puts 'Vazo hazir.'
  rescue => e
    model.abort_operation if model
    puts "Hata: #{e.message}"
    puts e.backtrace.first(3)
  end
end

FlatLobeVase.run if defined?(Sketchup)
