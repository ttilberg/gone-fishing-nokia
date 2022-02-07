require 'app/nokia.rb'

def tick(args)
  init(args) if args.tick_count == 0

  try_to_move(args)
  check_the_water(args)
  go_fishing(args)
  render_score(args)

  audio(args)

  args.nokia.sprites << args.state.map
  args.nokia.sprites << args.state.player
end


X_SPAWN = (-50..50).to_a.freeze
Y_SPAWN = (-30..30).to_a.freeze


def check_the_water(args)
  if args.tick_count % 10 == 0 && rand > 0.9
    something = {
      x: args.state.player.x_pos + args.state.player.x + X_SPAWN.sample,
      y: args.state.player.y_pos + args.state.player.y + Y_SPAWN.sample,
      w: [1,2,3].sample,
      h: [1,2,3].sample,
      created_at: args.tick_count,
      destroy_at: args.tick_count + 60 * 10,
    }

    # boss?
    if args.state.score > 10 && (rand > 0.9) && args.state.something_in_the_water.none?(&:boss)
      something.merge!(
        boss: true,
        w: [4,5,6].sample,
        h: [4,5,6].sample
      )
      args.audio[:fx] = {
        input: 'sounds/boss.wav',
      }
    end

    args.state.something_in_the_water << something
  end

  args.state.something_in_the_water.reject!{|el| el[:destroy_at] < args.tick_count}

  args.state.something_in_the_water.each do |something|
    args.nokia.solids << something.merge(
      x: something[:x] - args.state.player.x_pos,
      y: something[:y] - args.state.player.y_pos,
    )
  end
end

def go_fishing(args)
  return unless args.keyboard.space
  player = args.state.player

  something = args.state.something_in_the_water.find do |something|

    x_distance = (player.x_pos + player.x - something.x).abs
    y_distance = (player.y_pos + player.y - something.y).abs

    x_distance < 8 && y_distance < 8
  end

  return unless something

  args.audio[:fx] = {
    input: 'sounds/chirp.wav',
  }

  args.state.score += 1

  args.state.something_in_the_water -= [something]
end

def render_score(args)
  return if args.state.score == 0

  args.nokia.labels << args.nokia
                            .default_label
                            .merge(x: 5,
                                   y: 5,
                                   text: args.state.score,
                                   alignment_enum: 1)  
end

def audio(args)
  args.audio[:bg] ||= {
    input: 'sounds/loop-1.wav',
    looping: true
  }

  # Only play a single channel. If there's fx, mute the bg.
  if args.audio[:fx]
    args.audio[:bg].gain = 0.0
  else
    args.audio[:bg].gain = 1.0
  end
end

def try_to_move(args)
  return unless args.tick_count % 2 == 0
  
  inp = args.inputs
  return unless inp.up || inp.down || inp.left || inp.right

  # TODO: create 45º sprites, and create json crash maps for the various angles
  args.state.player.angle = args.inputs.directional_angle

  current_x = args.state.player.x_pos
  current_y = args.state.player.y_pos

  future_x = current_x + args.inputs.left_right
  future_y = current_y + args.inputs.up_down

  # Return early if the move should be invalid
  if args.state.boat_pts.any? do |x, y|
      args.state.map_box[ [future_x + x, future_y + y ] ]
    end

    args.nokia.labels << args.nokia
                            .default_label
                            .merge(x: NOKIA_WIDTH / 2,
                                   y: 5,
                                   text: "Bang!",
                                   alignment_enum: 1)

    args.audio[:fx] = {
      input: 'sounds/blip.wav',
    }

    return
  end


  args.state.player.x_pos += inp.left_right
  args.state.player.y_pos += inp.up_down


  args.state.map.x = args.state.player.x - args.state.player.x_pos
  args.state.map.y = args.state.player.y - args.state.player.y_pos
end


def init(args)
  args.state.player = {
    x_pos: 88,
    x: NOKIA_WIDTH / 2,
    y_pos: 390,
    y: NOKIA_HEIGHT / 2,
    w: 13,
    h: 7,
    path: 'sprites/boat_13_7.png',
  }

  args.state.map = {
    x: args.state.player.x - args.state.player.x_pos,
    y: args.state.player.y - args.state.player.y_pos,
    w: 840,
    h: 480,
    path: 'sprites/map.png',
  }

  args.state.score = 0

  args.state.something_in_the_water = []


  args.state.map_box = args.gtk.parse_json_file('data/map.png.json').map{|row| [ [row['x'], row['y']], true ] }.to_h
  args.state.boat_pts = args.gtk.parse_json_file('data/boat_13_7_outline.png.json').map{|row| [row['x'], row['y']] }

  args.audio[:bg] = {
    input: 'sounds/loop-1-intro.wav',
  }
end

$gtk.reset
