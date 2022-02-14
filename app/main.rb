require 'app/nokia.rb'
require 'app/boss_fight.rb'
require 'app/title_screen.rb'
require 'app/lost_at_sea.rb'

REGULAR_SPAWN_RATE = 0.85
BOSS_SPAWN_RATE = 0.85

def tick(args)
  init(args) if args.tick_count == 0
  if args.state.transition_scene_to
    puts "Transitioning scene to #{args.state.transition_scene_to} at #{args.tick_count}"
    args.state.scene = args.state.transition_scene_to
    args.state.scene_started_at = args.tick_count
    args.state.transition_scene_to = nil
    args.audio.bg = nil unless args.tick_count == 0
  end

  send "tick_scene_#{args.state.scene}".to_sym, args
  single_channel_audio(args)
end

def tick_scene_title_screen(args)
  TitleScreen.tick(args)
end

def tick_scene_overworld(args)
  init_overworld(args) unless args.state.scene_overworld.did_init

  # Play the main loop after the intro exits
  args.audio[:bg] ||= {
    input: 'sounds/overworld-loop.wav',
    looping: true
  }
  args.audio.bg.paused = false

  try_to_move(args)
  check_the_water(args)
  go_fishing(args) if (args.keyboard.space || args.keyboard.enter)

  render_threat_level(args)
  render_things_in_the_water(args)
  render_background(args)
  render_player(args)
  render_fishing_pole(args)
  render_foreground(args)
end

def tick_scene_catching_a_boss(args)
  args.audio.bg = nil
  catching_a_boss(args)

  render_threat_level(args)
  render_things_in_the_water(args)
  render_background(args)
  render_player(args)

  render_fishing_pole_for_boss(args)
  render_foreground(args)
end

def tick_scene_boss_fight(args)
  BossFight.tick(args)
end

def tick_scene_lost_at_sea(args)
  LostAtSea.tick(args)
end

def render_player(args)
  args.state.player.path = boat_sprite(args.state.player.heading)
  args.nokia.sprites << args.state.player
end


def render_fishing_pole(args)
  return unless args.state.player.started_fishing_at
  elapsed = args.state.player.started_fishing_at.elapsed_time

  if elapsed > 50
    args.state.player.started_fishing_at = nil
    args.state.player.rod_has_something_hooked = nil
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
  when 31..40, 43..50
    if args.state.player.rod_has_something_hooked
      6 # rod up!
    else
      5 # Rod down ; ;
    end
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
  elapsed = args.state.player.started_fishing_at.elapsed_time

  # Animate the pole based on time elapsed
  sprite = case elapsed
  when 0 # If player has discovered "trolling mode", this gives the impression that the line is in the water.
    5
  when 1..3
    1
  when 4..7
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
  case args.state.scene_started_at.elapsed_time
  when 40, 100, 160, 180, 196, 209, 219, 223
    args.audio[:fx] = {
      input: 'sounds/chirp.wav',
    }
  when 240
    args.state.things_in_the_water -= [args.state.current_catch]
    args.state.transition_scene_to = :boss_fight
  end
end

def render_things_in_the_water(args)
  args.state.things_in_the_water.each do |something|
    args.nokia.solids << something.merge(
      x: something[:x] - args.state.player.x_pos,
      y: something[:y] - args.state.player.y_pos,
    )
  end
end

COMMON_FISH_SIZES = [
  {w: 1, h: 1},
  {w: 1, h: 2},
  {w: 2, h: 1},
  {w: 3, h: 1},
  {w: 1, h: 3},
  {w: 3, h: 2},
  {w: 2, h: 3}
].freeze

# Add and remove mobs from the water
def check_the_water(args)
  if args.tick_count.mod(20).zero? && rand > REGULAR_SPAWN_RATE
    something = args.state.new_entity(:something,
      boss: false,
      x: args.state.player.x_pos + args.state.player.x + (rand(100) - 50),
      y: args.state.player.y_pos + args.state.player.y + (rand(60) - 30),
      **COMMON_FISH_SIZES.sample,
    )
    # Set the center point now so we don't have to calc it in the loops later
    something.center_x = something.x + (something.w / 2)
    something.center_y = something.y + (something.h / 2)

    # boss?
    if args.state.threat_level > 10 && (rand > BOSS_SPAWN_RATE) && args.state.things_in_the_water.none?(&:boss)
      something.boss = true
      something.w = [5, 6, 7].sample
      something.h = [5, 6, 7].sample

      args.audio[:fx] = {
        input: 'sounds/boss.wav',
      }
    end

    args.state.things_in_the_water << something
  end

  args.state.things_in_the_water.reject! { |this|
    this != args.state.current_catch && this.created_at_elapsed > 60 * 10
  }
end

# Try some fishing!
def go_fishing(args)
  player = args.state.player
  player.started_fishing_at = args.state.tick_count

  # Base the catch on the pole animation position
  pole_length = 8
  pole_power = 7

  pole_length = -1 * pole_length if player.facing == :left

  x = player.x_pos + player.x + (player.w / 2) + pole_length
  y = player.y_pos + player.y + (player.h / 2)

  something = args.state.things_in_the_water.find do |something|
    x_distance = (x - (something.center_x)).abs
    y_distance = (y - (something.center_y)).abs

    x_distance < pole_power && y_distance < pole_power
  end

  return unless something

  args.state.player.rod_has_something_hooked = true

  if something.boss
    args.state.transition_scene_to = :catching_a_boss
    args.state.current_catch = something
    return
  end

  args.audio[:fx] = {
    input: 'sounds/chirp.wav',
  }

  args.state.player.last_catch_at = args.tick_count
  args.state.threat_level += 1
  args.state.things_in_the_water -= [something]
end

def render_threat_level(args)
  return if args.state.threat_level == 0

  args.nokia.labels << args.nokia
                            .default_label
                            .merge(x: 2,
                                   y: 5,
                                   text: args.state.threat_level,
                                   alignment_enum: 0)  
end

def single_channel_audio(args)
  # Only play a single channel. If there's fx, mute the bg.
  if args.audio[:fx]
    args.audio[:bg]&.gain = 0.0
  else
    args.audio[:bg]&.gain = 1.0
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

    if args.state.player.hp > 30 && args.tick_count % 4 == 0
      args.state.player.hp -= 1
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
  i = args.tick_count.idiv(40).mod(3)
  frame = [1, 2, 3][i]
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

def init_overworld(args)
  return if args.state.scene_overworld.did_init
  args.state.scene_overworld.did_init = true

  args.state.threat_level = 0
  args.state.things_in_the_water = []
  args.state.current_catch = nil


  args.state.map_box = args.gtk.parse_json_file('data/map-walls.png.json').map{|row| [ [row['x'], row['y']], true ] }.to_h
  args.state.boat_pts = {}
  [0, 45, 90, 135, 180, -45, -90, -135].each do |angle|
    args.state.boat_pts[angle] = args.gtk.parse_json_file("data/boat-outline-#{angle}.png.json").map{|row| [row['x'], row['y']] }
  end

  args.audio[:bg] = {
    input: 'sounds/overworld-intro.wav',
  }
end

def init(args)
  args.state.player ||= {
    max_hp: 130,
    hp: 130,
    weapon_base_damage: 10,
    weapon_variable_damage: 20,
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

  args.state.scene ||= :title_screen
  args.state.scene_started_at = 0

  args.state.transition_scene_to = :title_screen
end


$gtk.reset
