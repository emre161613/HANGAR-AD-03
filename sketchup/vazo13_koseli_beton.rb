# Koseli beton vazo seti - sekizgen kesitli, iki kesik koniden olusan uc vazo
# (gri, bej, beyaz); alt koni kisa ve genisler, ust koni uzun ve daralir.
# SketchUp: Window > Ruby Console, sonra:
#   load "C:/Users/Onur Girit/Desktop/vazo13_koseli_beton.rb"
#
# Eksenler: X = sag, Y = derinlik (on -Y), Z = yukari.
# Olculer fotograftan piksel olarak alindi; SCALE ile cm'ye cevrilir.
# Ondeki beyaz vazo kameraya yakin oldugu icin perspektif payi (~%13) dusuldu.

module FacetVases
  extend self

  SCALE = 60.0 / 684.0 # gri vazo 60 cm
  SIDES = 8            # kenar sayisi (sekizgen)

  # profile: [z, kose yaricapi] (px) - taban, kirim, agiz
  # mouth: agiz deligi yaricapi, depth: delik derinligi, pos: [x, y] px
  VASES = [
    { name: 'Gri',   color: [120, 118, 114], pos: [-80, 0],   mouth: 34, depth: 200,
      profile: [[0, 48], [172, 87], [684, 70.5]] },
    { name: 'Bej',   color: [196, 168, 128], pos: [97, 90],   mouth: 28, depth: 200,
      profile: [[0, 62.5], [165, 91.5], [615, 55.5]] },
    { name: 'Beyaz', color: [232, 230, 226], pos: [16, -260], mouth: 24, depth: 160,
      profile: [[0, 48.5], [198, 76.7], [498, 42.3]] }
  ]

  # Kose acilari: bir kose one (-Y) bakar, fotograftaki gibi ortada dikey kenar
  def angles
    Array.new(SIDES) { |i| -Math::PI / 2 + 2 * Math::PI * i / SIDES }
  end

  def ring(r, z)
    angles.map { |a| [r * Math.cos(a), r * Math.sin(a), z.to_f] }
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

  # Kapali govde: taban, kose yuzleri, ust yuz, agiz deligi (px)
  def vase_tris(v)
    top = v[:profile].last[0].to_f
    rings = v[:profile].map { |z, r| ring(r, z) }
    rings << ring(v[:mouth], top) << ring(v[:mouth], top - v[:depth])
    tris = []
    fan([0.0, 0.0, 0.0], rings.first, tris, true)
    (rings.size - 1).times { |k| strip(rings[k + 1], rings[k], tris) }
    fan([0.0, 0.0, top - v[:depth]], rings.last, tris)
    tris
  end

  # ---- SketchUp ----
  def add_mesh(ents, tris, mat)
    mesh = Geom::PolygonMesh.new(tris.size * 3, tris.size)
    index = {}
    tris.each do |tri|
      ids = tri.map do |v|
        key = v.map { |c| (c * 1e6).round }
        index[key] ||= mesh.add_point(Geom::Point3d.new((v[0] * SCALE).cm, (v[1] * SCALE).cm, (v[2] * SCALE).cm))
      end
      next if ids.uniq.size < 3
      mesh.add_polygon(*ids)
    end
    ents.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE, mat, mat)
  end

  # Ayni duzlemdeki ucgenlerin arasindaki cizgiyi gizle; koseler keskin kalsin
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
    puts "SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION} - koseli beton vazolar olusturuluyor..."
    model.start_operation('Koseli Beton Vazolar', true)
    root = model.active_entities.add_group
    root.name = 'Koseli Beton Vazolar'
    VASES.each do |v|
      grp = root.entities.add_group
      grp.name = "#{v[:name]} Vazo"
      mat = material(model, "Beton_#{v[:name]}", v[:color])
      add_mesh(grp.entities, vase_tris(v), mat)
      soften(grp.entities, 0.05)
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

FacetVases.run if defined?(Sketchup)
