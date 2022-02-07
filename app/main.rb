require 'app/nokia.rb'

def tick(args)
  init(args) if args.tick_count == 0

  try_to_move(args)
  audio(args)

  args.nokia.sprites << args.state.map
  args.nokia.sprites << args.state.player
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

INPUT_ANGLE = {
  [1,   0] => 0,
  [1,   1] => 45,
  [0,   1] => 90,
  [-1,  1] => 135,
  [-1,  0] => 180,
  [-1, -1] => 225,
  [0,  -1] => 270,
  [1,  -1] => 315
}

def try_to_move(args)
  return unless args.tick_count % 2 == 0
  
  inp = args.inputs
  return unless inp.up || inp.down || inp.left || inp.right

  # TODO: create 45º sprites, and create json crash maps for the various angles
  args.state.player.angle = INPUT_ANGLE[[inp.left_right, inp.up_down]]

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

  args.state.map_box = args.gtk.parse_json_file('data/map.png.json').map{|row| [ [row['x'], row['y']], true ] }.to_h
  args.state.boat_pts = args.gtk.parse_json_file('data/boat_13_7_outline.png.json').map{|row| [row['x'], row['y']] }

  args.audio[:bg] = {
    input: 'sounds/loop-1-intro.wav',
  }
end

$gtk.reset
