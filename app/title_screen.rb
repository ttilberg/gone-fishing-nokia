class TitleScreen
class << self

  def tick(args)
    title_init(args) if args.tick_count == 0

    if args.state.title.boat.x == 48 && (args.keyboard.enter || args.keyboard.space)
      args.state.title.proceed_at ||= args.tick_count
    end

    render_boat(args)
    render_help_text(args)


    args.nokia.sprites << {
      x: 0, y: 0, w: 84, h: 48, path: "sprites/title-gone-fishing-text.png"
    }
    render_fishing_pole(args)
    if args.state.title.reveal_dots.any?
      args.state.title.reveal_dots.each do |dot|
        args.nokia.sprites << dot
      end

      i = [3, args.state.title.reveal_dots.size / 60].max
      args.state.title.reveal_dots = args.state.title.reveal_dots.drop(i)
    end
  end

  def render_help_text(args)
    # Wait for boat to get in place
    return if args.state.title.boat.x < 48

    # Skip if player already pressed the button
    return if args.state.title.proceed_at

    args.state.title.blink_show = !args.state.title.blink_show if args.tick_count % 30 == 0

    if args.state.title.blink_show
      args.nokia.labels << args.nokia
                                .default_label
                                .merge(x: 2,
                                       y: 4,
                                       text: "Space or Enter",
                                       alignment_enum: 0)
    end
  end

  def render_boat(args)
    if args.state.title.boat.x < 48 && args.state.tick_count % 5 == 0
      i = args.easing.ease(50, args.tick_count, 60 * 3, :flip, :quad, :flip)
      args.state.title.boat.x = (i * 78).to_i - 29
    end  
    args.nokia.sprites << args.state.title.boat
  end

  def render_fishing_pole(args)
    return unless args.state.title.proceed_at
    elapsed = args.state.title.proceed_at.elapsed_time

    args.audio.fx = {input: "sounds/chirp.wav"} if elapsed == 0

    # Animate the pole based on time elapsed
    sprite = case elapsed  
    when 0..12
      1
    when 13..17
      2
    when 18..22
      3
    when 26..34
      4
    when 60..70, 79..400
      6
    else
      5
    end

    args.state.transition_scene_to = :overworld if elapsed == 120

    args.nokia.sprites << {
      x: 44,
      y: 31,
      w: 17 * 2,
      h: 10 * 2,
      path: "sprites/rod-#{sprite}.png"
    }    
  end


  def title_init(args)
    args.audio.bg = {
      input: "sounds/title-loop.wav",
      looping: true
    }
    args.state.title.blink_show = true
    args.state.title.reveal_dots = []
    (0..84).each do |x|
      (0..48).each do |y|
        args.state.title.reveal_dots << {x: x, y: y, w: 1, h:1, **NOKIA_COLORS[:light], path: :pixel}
      end
    end
    args.state.title.reveal_dots.shuffle!

    args.state.title.boat = {
      x: -20, y: 14, w: 26, h: 26, path: "sprites/boat-0.png"
    }
  end

end
end
