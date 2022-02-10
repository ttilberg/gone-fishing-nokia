require 'app/nokia.rb'

REGULAR_SPAWN_RATE = 0.9
BOSS_SPAWN_RATE = 0.93


def tick(args)
  init(args) if args.tick_count == 0

  if args.state.current_boss
    catching_a_boss(args)
  else
    try_to_move(args)
    check_the_water(args)
    go_fishing(args)
  end

  render_score(args)
  render_things_in_the_water(args)

  audio(args)

  render_background(args)
  render_player(args)
  render_foreground(args)
end

# def render_map(args)
#   # TODO: Layer the foreground (trees and stuff) in front of player
#   args.nokia.sprites << args.state.map
# end

def render_player(args)
  args.state.player.path = boat_sprite(args.state.player.heading)
  args.nokia.sprites << args.state.player

  render_fishing_pole(args)  
end


X_SPAWN = (-50..50).to_a.freeze
Y_SPAWN = (-30..30).to_a.freeze

def render_fishing_pole(args)
  return render_fishing_pole_for_boss(args) if args.state.current_boss
  return unless args.state.player.started_fishing_at
  elapsed = args.state.tick_count - args.state.player.started_fishing_at

  if elapsed > 50
    args.state.player.started_fishing_at = nil
    args.state.player.catching_a_fish = nil
    return
  end

  # Animate the pole based on time elapsed
  sprite = case elapsed
  when 0 # If player has discovered "trolling mode", this gives the impression that the line is in the water.
    5    
  when 1..3
    1
  when 3..7
    2
  when 8..11
    3
  when 12..15
    4
  when 31..40, 44..50
    args.state.player.catching_a_fish ? 6 : 5
  else
    5
  end

  args.nokia.sprites << {
    x: args.state.player.x - 2,
    y: args.state.player.y + 7,
    w: 17,
    h: 10,
    flip_horizontally: args.state.player.facing == :left,
    path: "sprites/rod-#{sprite}.png"
  }    
end

def render_fishing_pole_for_boss(args)
  elapsed = args.state.tick_count - args.state.player.started_fishing_at

  # Animate the pole based on time elapsed
  sprite = case elapsed
  when 0 # If player has discovered "trolling mode", this gives the impression that the line is in the water.
    5
  when 1..3
    1
  when 3..7
    2
  when 8..11
    3
  when 12..15
    4
  when 35..50, 98..104, 158..163, 178..183, 195..200, 207..212, 218..221, 223..240
    6
  else
    5
  end

  args.nokia.sprites << {
    x: args.state.player.x - 2,
    y: args.state.player.y + 7,
    w: 17,
    h: 10,
    flip_horizontally: args.state.player.facing == :left,
    path: "sprites/rod-#{sprite}.png"
  }
end

def catching_a_boss(args)
  case args.state.tick_count - args.state.current_boss_at
  when 40, 100, 160, 180, 196, 209, 219, 223
    args.audio[:fx] = {
      input: 'sounds/chirp.wav',
    }
  when 240
    args.state.something_in_the_water -= [args.state.current_boss]
    args.state.score *= 2
    args.state.current_boss = nil
    args.state.current_boss_at = nil
    args.audio.bg.paused = false
  end
end

def render_things_in_the_water(args)
  args.state.something_in_the_water.each do |something|
    args.nokia.solids << something.merge(
      x: something[:x] - args.state.player.x_pos,
      y: something[:y] - args.state.player.y_pos,
    )
  end
end


def check_the_water(args)
  if args.tick_count % 10 == 0 && rand > REGULAR_SPAWN_RATE
    something = {
      x: args.state.player.x_pos + args.state.player.x + X_SPAWN.sample,
      y: args.state.player.y_pos + args.state.player.y + Y_SPAWN.sample,
      w: [1,2,3].sample,
      h: [1,2,3].sample,
      created_at: args.tick_count,
      destroy_at: args.tick_count + 60 * 10,
    }

    # boss?
    if args.state.score > 10 && (rand > BOSS_SPAWN_RATE) && args.state.something_in_the_water.none?(&:boss)
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
end

def go_fishing(args)
  return unless args.keyboard.space
  player = args.state.player
  player.started_fishing_at = args.state.tick_count

  # Base the catch on the pole animation position
  pole_length = 8
  pole_length = -1 * pole_length if player.facing == :left
  pole_power = 7

  x = player.x_pos + player.x + (player.w / 2) + pole_length
  y = player.y_pos + player.y + (player.h / 2)

  something = args.state.something_in_the_water.find do |something|
    x_distance = (x - (something.x + (something.w / 2))).abs
    y_distance = (y - (something.y + (something.h / 2))).abs

    x_distance < pole_power && y_distance < pole_power
  end

  return unless something

  if something.boss
    args.state.current_boss_at = args.tick_count
    args.state.current_boss = something
    args.audio.bg.paused = true
    return catching_a_boss(args)
  end

  args.audio[:fx] = {
    input: 'sounds/chirp.wav',
  }

  args.state.player.catching_a_fish = true
  args.state.score += 1
  args.state.something_in_the_water -= [something]
end

def render_score(args)
  return if args.state.score == 0

  args.nokia.labels << args.nokia
                            .default_label
                            .merge(x: 2,
                                   y: 5,
                                   text: args.state.score,
                                   alignment_enum: 0)  
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


  current_x = args.state.player.x_pos
  current_y = args.state.player.y_pos

  future_x = current_x + args.inputs.left_right
  future_y = current_y + args.inputs.up_down

  future_angle = args.inputs.directional_angle.to_i

  # Return early if the move should be invalid
  if args.state.boat_pts[future_angle].any? do |x, y|
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



  args.state.player.heading = future_angle
  args.state.player.facing = :right if inp.right
  args.state.player.facing = :left if inp.left

  args.state.player.x_pos += inp.left_right
  args.state.player.y_pos += inp.up_down
end

def boat_sprite(angle=0)
  "sprites/boat-#{angle}.png"
end

def render_background(args)
  i = args.tick_count.idiv(40).mod(4)
  frame = [1, 2, 3, 2][i]
  [
    "sprites/map-walls.png",
    "sprites/environment-background-#{frame}.png",
  ].each do |png|
    args.nokia.sprites << 
      args.state.map = _render_map_args(args).merge(path: png)
  end
end

def render_foreground(args)
  args.nokia.sprites << _render_map_args(args).merge(path: "sprites/environment-foreground-1.png")
end

def _render_map_args(args)
  {
    x: args.state.player.x - args.state.player.x_pos,
    y: args.state.player.y - args.state.player.y_pos,
    w: 840,
    h: 480
  }
end


def init(args)
  args.state.player = {
    x_pos: 88,
    x: NOKIA_WIDTH / 2,
    y_pos: 390,
    y: NOKIA_HEIGHT / 2,
    w: 13,
    h: 13,
    path: boat_sprite,
    heading: 0,
    facing: :right
  }


  args.state.score = 0
  args.state.current_boss = nil
  args.state.something_in_the_water = []


  args.state.map_box = args.gtk.parse_json_file('data/map-walls.png.json').map{|row| [ [row['x'], row['y']], true ] }.to_h
  args.state.boat_pts = {}
  [0, 45, 90, 135, 180, -45, -90, -135].each do |angle|
    args.state.boat_pts[angle] = args.gtk.parse_json_file("data/boat-outline-#{angle}.png.json").map{|row| [row['x'], row['y']] }
  end

  args.audio[:bg] = {
    input: 'sounds/loop-1-intro.wav',
  }
end

$gtk.reset
