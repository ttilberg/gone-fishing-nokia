class LostAtSea
class << self

  def tick(args)
    elapsed = args.state.scene_started_at.elapsed_time
    init(args) if elapsed == 0

    if args.state.lost_at_sea.progress && (args.keyboard.key_up.enter || args.keyboard.key_up.space)
      $gtk.reset
    end    

    if elapsed > 100 && (args.keyboard.key_up.enter || args.keyboard.key_up.space)
      args.state.lost_at_sea.progress = true
    end  

    if args.state.lost_at_sea.progress
      args.nokia.labels << args.nokia
                            .default_label
                            .merge(x: NOKIA_WIDTH / 2,
                                   y: 30,
                                   size_enum: NOKIA_FONT_SM,
                                   text: "Your final threat:",
                                   alignment_enum: 1)  

      args.nokia.labels << args.nokia
                            .default_label
                            .merge(x: NOKIA_WIDTH / 2,
                                   y: 10,
                                   size_enum: NOKIA_FONT_MD,
                                   text: "135" || args.state.threat_level,
                                   alignment_enum: 1)  

      return
    end


    args.nokia.sprites << {
      x: 0, y: 0, w: 84, h: 48, path: :pixel, **NOKIA_COLORS[:dark]
    }

    args.nokia.sprites << {
      x: 5, y: 3, w: 63, h: 42, path: "sprites/lost-at-sea.png"
    }
    render_boat(args)


    if args.state.title.reveal_dots.any?
      args.state.title.reveal_dots.each do |dot|
        args.nokia.sprites << dot
      end

      if elapsed > 20 && args.tick_count % 2 == 0
        i = [3, args.state.title.reveal_dots.size / 40].max
        args.state.title.reveal_dots = args.state.title.reveal_dots.drop(i)
      end
    end
  end

  def render_boat(args)
    args.nokia.sprites << {
      x: 59, y: 20, w: 18, h: 18, path: "sprites/lost-at-sea-boat.png"
    }
  end

  def init(args)
    args.state.lost_at_sea.progress = false
    args.audio.bg = {
      input: "sounds/lost.wav",
    }
    args.state.title.reveal_dots = []
    (0..84).each do |x|
      (0..48).each do |y|
        args.state.title.reveal_dots << {x: x, y: y, w: 1, h:1, **NOKIA_COLORS[:dark], path: :pixel}
      end
    end
    args.state.title.reveal_dots.shuffle!
  end

end
end
