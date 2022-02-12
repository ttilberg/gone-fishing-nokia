class BossFight
class << self
  def tick(args)
    init(args) if args.state.scene_started_at.new?

    if args.state.boss.transition_mode_to
      puts "Transitioning boss to #{args.state.boss.transition_mode_to} at #{args.tick_count}"
      args.state.boss.mode = args.state.boss.transition_mode_to
      args.state.boss.mode_at = args.tick_count
      args.state.boss.transition_mode_to = nil
    end

    return exit_battle(args) if args.state.boss.mode == :defeated

    if args.inputs.keyboard.key_down.space && args.state.battle.player_attacked_at.nil?
      args.state.battle.player_attacked_at = args.tick_count
    end

    render_boss(args)

    if args.state.battle.player_attacked_at
      attack(args)
    else
      render_resting_pose(args)
    end

    args.nokia.sprites << args.state.battle.bg_sprite
    args.nokia.sprites << [0,0, 84, 48, 'sprites/battle-scene.png']

    render_hp(args)

    if args.state.battle.boss.hp <= 0 && args.state.boss.mode != :defeated
      args.state.boss.transition_mode_to = :defeated
    end
  end

  def render_boss(args)
    return render_boss_intro(args) if args.state.boss.mode == :intro

    frame = args.state.battle.created_at_elapsed.idiv(50).mod(2) + 1
    args.nokia.sprites << [0, 0, 84, 48, "sprites/boss-idle-#{frame}.png"]
  end

  def render_boss_intro(args)
    i = case args.state.boss.mode_at.elapsed_time
    when 0..20
      1
    when 20..40
      2
    when 40..130
      3
    when 131..190
      4
    else
      5
    end
    args.state.boss.transition_mode_to = :idle if i == 5

    if [1,2,3].include? i
      args.nokia.sprites << [0, 0, 84, 48, "sprites/boss-intro-#{i}.png"]
    else
      # The scowl
      args.nokia.sprites << [0, 0, 84, 48, "sprites/boss-idle-1.png"]
    end
  end

  def exit_battle(args)
    args.nokia.sprites << args.state.battle.bg_sprite
    args.nokia.sprites << [0,0, 84, 48, 'sprites/battle-scene.png']
    args.nokia.sprites << [0, 0, 84, 48, "sprites/guy-attack-3.png"]
    render_hp(args)

    elapsed = args.state.boss.mode_at.elapsed_time

    case elapsed
    when 0
      args.audio[:fx] = {input: 'sounds/chirp.wav', pitch: 0.5}
    when 6
      args.audio[:fx] = {input: 'sounds/chirp.wav', pitch: 0.8}
    when 12
      args.audio[:fx] = {input: 'sounds/chirp.wav', pitch: 1.0}
    when 18
      args.audio[:fx] = {input: 'sounds/chirp.wav', pitch: 1.5}
    when 24
      args.audio[:fx] = {input: 'sounds/chirp.wav', pitch: 2.0}
    when 60 * 2
      args.state.threat_level *= 2
      args.state.player.weapon_base_damage += 50
      args.state.player.weapon_variable_damage += rand(100)

      args.state.transition_scene_to = :overworld
    end

    shift = (elapsed / 120 * 10).to_i

    args.nokia.sprites << [0 - shift, 0, 84, 48, "sprites/boss-idle-1.png"] if (elapsed % 2) == 0
    args.nokia.sprites << [0 + shift, 0, 84, 48, "sprites/boss-idle-1.png"] if (elapsed % 2) == 1

  end

  def render_resting_pose(args)
    frame = args.state.battle.created_at_elapsed.idiv(30).mod(2) + 1
    args.nokia.sprites << [0,0, 84, 48, "sprites/guy-rest-#{frame}.png"]
  end

  def render_hp(args)
    # Occlude background so artwork doesn't pop through the bar as the boss takes damage
    args.nokia.sprites << {
        x: 77,
        y: 3,
        w: 2,
        h: 41,
        path: :pixel,
        **NOKIA_COLORS[:light]
      }

    if args.state.battle.boss.hp > 0
      args.nokia.sprites << {
        x: 77,
        y: 3,
        w: 2,
        h: (args.state.battle.boss.hp / args.state.battle.boss.max_hp) * 41,
        path: :pixel,
        **NOKIA_COLORS[:dark]
      }
    end

    decoration_speed = args.state.battle.boss.damaged_at.elapsed_time < 10 ? 2 : 20
    decoration_speed = 2 if args.state.boss.mode == :defeated

    frame = args.state.battle.created_at_elapsed.idiv(decoration_speed).mod(4) + 1

    args.nokia.sprites << {
      path: "sprites/boss-meter-#{frame}.png",
      x: 71,
      y: 2,
      w: 13,
      h: 44
    }
  end

  def attack(args)
    elapsed = args.state.battle.player_attacked_at.elapsed_time
    frame = case elapsed
    when 0..3
      1
    when 4..7
      2
    when 8
      args.audio[:fx] = {input: 'sounds/blap.wav'}
      args.state.battle.boss.damaged_at = args.tick_count
      args.state.battle.boss.hp -= rand(20) + weapon_damage(args)
      3
    when 0..14
      3
    when 15  # finish attack
      args.state.battle.player_attacked_at = nil
      3
    end

    args.nokia.sprites << [0, 0, 84, 48, "sprites/guy-attack-#{frame}.png"]
  end

  def weapon_damage(args)
    args.state.player.weapon_base_damage + rand(args.state.player.weapon_variable_damage)
  end

  def init(args)
    # Make sure the player has some sort of weapon
    args.state.player.weapon_base_damage ||= 10
    args.state.player.weapon_variable_damage ||= 10

    # Ensure we are starting with a fresh battle
    args.state.battle = args.state.new_entity(:battle)
    args.state.battle.bg_sprite = [0,0, 84, 48, "sprites/battle-bg-#{[1,2,3].sample}.png"]
    args.state.battle.boss.damaged_at = nil

    args.state.boss.transition_mode_to = :intro

    args.state.battle.boss.max_hp = 1000
    args.state.battle.boss.hp = 1000
    args.audio.bg = {
      input: 'sounds/boss-loop.wav',
      looping: true
    }
  end
end
end
