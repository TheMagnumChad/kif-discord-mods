module HoennNativeKIFFusionFX
  def self.play(first, second)
    return unless $scene.is_a?(Scene_Map)
    viewport = nil
    sprites = []
    begin
      viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      viewport.z = 99999
      # Project each Pokémon's tile into the current map camera
      centers = [first, second].map do |pkmn|
        coords = pkmn.ow_coordinates
        next nil unless coords && $game_map
        tx, ty = coords
        sx = (tx * 128 - $game_map.display_x + 64) / 4
        sy = (ty * 128 - $game_map.display_y + 64) / 4 - 16
        [sx, sy]
      end.compact
      if centers.length == 2
        centers << [(centers[0][0]+centers[1][0])/2,
                    (centers[0][1]+centers[1][1])/2]
      end
      centers = [[Graphics.width/2, Graphics.height/2]] if centers.empty?
      centers.each do |cx,cy|
        sp = Sprite.new(viewport)
        sp.bitmap = Bitmap.new(80,80)
        # Solid layered diamond burst, visible without external assets
        white = Color.new(255,255,255)
        gold  = Color.new(255,218,88)
        0.upto(32) do |dy|
          half = 32-dy
          sp.bitmap.fill_rect(40-half, 40-dy, half*2+1, 1, gold)
          sp.bitmap.fill_rect(40-half, 40+dy, half*2+1, 1, gold)
        end
        sp.bitmap.fill_rect(33, 12, 14, 56, white)
        sp.bitmap.fill_rect(12, 33, 56, 14, white)
        sp.ox=40;sp.oy=40;sp.x=cx;sp.y=cy
        sp.opacity=0;sp.zoom_x=0.2;sp.zoom_y=0.2
        sprites << sp
      end
      24.times do |frame|
        sprites.each do |sp|
          sp.zoom_x = sp.zoom_y = 0.2 + (frame.to_f/23)*1.3
          sp.opacity = frame < 9 ? [255,frame*30].min : [0,255-(frame-9)*18].max
        end
        Graphics.update
        Input.update
      end
    ensure
      sprites.each do |sp|
        next if !sp || sp.disposed?
        sp.bitmap.dispose if sp.bitmap && !sp.bitmap.disposed?
        sp.dispose
      end
      viewport.dispose if viewport && !viewport.disposed?
    end
  end
end

# Town wildlife may notice/flee, but must never force a battle
