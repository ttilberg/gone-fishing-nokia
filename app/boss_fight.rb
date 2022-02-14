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
    return render_intro(args) if args.state.boss.mode == :intro

    # Detect player action
    if (args.keyboard.key_down.space || args.keyboard.key_down.enter) && args.state.battle.player_attack.nil?
      args.state.battle.player_attack = args.state.new_entity(:player_attack)
    end

    # Detect boss action
    # dive
    if args.state.boss.mode == :idle && args.state.boss.mode_at.elapsed_time > 60 && args.tick_count % 10 == 0 && rand > 0.9
      args.state.boss.transition_mode_to = :diving
    end

    case args.state.boss.mode
    when :diving
      boss_diving(args)
    when :dive
      boss_in_dive(args)
    when :returning_to_idle
      boss_returning_to_idle(args)
    when :attack_position
      boss_in_attack_position(args)
    else
      render_boss_idle(args)
    end

    if args.state.battle.player_attack
      attack(args)
    else
      render_resting_pose(args)
    end

    args.nokia.sprites << args.state.battle.bg_sprite
    args.nokia.sprites << [0,0, 84, 48, 'sprites/battle-boat.png']

    render_boss_hp(args)
    render_player_hp(args)

    if args.state.battle.boss.hp <= 0 && args.state.boss.mode != :defeated
      args.state.boss.transition_mode_to = :defeated
    end

    if args.state.player.hp <= 0
      args.state.transition_scene_to = :lost_at_sea
    end
  end

  def render_player_hp(args)
    scale = args.state.player.hp / args.state.player.max_hp

    args.nokia.solids << [0,0, NOKIA_WIDTH * scale, 1, **NOKIA_COLORS[:dark]]
  end

  def render_boss_idle(args)
    frame = args.state.battle.created_at_elapsed.idiv(50).mod(2) + 1
    args.nokia.sprites << [0, 0, 84, 48, "sprites/boss-idle-#{frame}.png"]
    args.nokia.sprites << [20, 10, 20, 15, "sprites/boss-tail-#{frame}.png"]
  end

  def render_intro(args)
    render_boss_intro(args)
    args.nokia.sprites << args.state.battle.bg_sprite
    args.nokia.sprites << [0,0, 84, 48, 'sprites/battle-boat.png']
    render_resting_pose(args)
  end

  def render_boss_intro(args)
    elapsed = args.state.boss.mode_at.elapsed_time
    i = case elapsed 
    when 0..20
      1
    when 20..40
      2
    when 40..170
      3
    # when 171..201
    #   4
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

    # Audio queues
    case elapsed
    when 0, 20, 40
      args.audio.fx = {input: "sounds/blap.wav", pitch: 0.6}
    when 171
      args.audio.bg ||= {
        input: 'sounds/boss-loop.wav',
        looping: true,
        playtime: 5.1
      }
    end 

  end

  def exit_battle(args)
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
    when 60 * 3
      args.state.threat_level *= 2
      args.state.player.weapon_base_damage += 50
      args.state.player.weapon_variable_damage += 100

      args.state.transition_scene_to = :overworld
    end


    # 10 pixels left and right over 120 frames (2 seconds)
    # shift = (elapsed / 120 * 10).to_i    
    shift = (10 * args.easing.ease(args.state.boss.mode_at, args.tick_count, 110, :flip, :quad, :flip)).to_i

    args.nokia.sprites << args.state.battle.bg_sprite
    args.nokia.sprites << [0,0, 84, 48, 'sprites/battle-boat.png']
    render_boss_hp(args)

    if (0..120).include? elapsed
      args.nokia.sprites << [0 - shift, 0, 84, 48, "sprites/boss-idle-1.png"] if (elapsed % 2) == 0
      args.nokia.sprites << [0 + shift, 0, 84, 48, "sprites/boss-idle-1.png"] if (elapsed % 2) == 1
    end

    args.nokia.sprites << [0, 0, 84, 48, "sprites/guy-attack-3.png"]
  end

  def render_resting_pose(args)
    frame = args.state.battle.created_at_elapsed.idiv(30).mod(2) + 1
    args.nokia.sprites << [0,0, 84, 48, "sprites/guy-rest-#{frame}.png"]
  end

  def render_boss_hp(args)
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

  def boss_returning_to_idle(args)
    elapsed = args.state.boss.mode_at.elapsed_time
    if elapsed == 25
      args.state.boss.transition_mode_to = :idle
    end

    args.nokia.sprites << [-3, -3, 84, 48, "sprites/boss-intro-2.png"]
  end

  def boss_diving(args)
    elapsed = args.state.boss.mode_at.elapsed_time
    if elapsed == 25
      args.state.boss.transition_mode_to = :dive
    end

    args.nokia.sprites << [0, 0, 84, 48, "sprites/boss-dive.png"]
  end

  def boss_in_dive(args)
    elapsed = args.state.boss.mode_at.elapsed_time
    i = elapsed.idiv(50).mod(2) + 1
    args.nokia.sprites << [0, 0, 84, 48, "sprites/boss-down-#{i}.png"]

    if elapsed > 300 + rand(500)
      if rand > 0.5
        args.state.boss.transition_mode_to = :returning_to_idle
      else
        args.state.boss.transition_mode_to = :attack_position
      end
    end
  end

  def boss_in_attack_position(args)
    elapsed = args.state.boss.mode_at.elapsed_time

    # Intro attack pose
    if elapsed < 50
      args.nokia.sprites << [0, 0, 84, 48, "sprites/boss-spit-1.png"]
      return
    end

    args.nokia.sprites << [0, 0, 84, 48, "sprites/boss-spit-2.png"]
    i = elapsed.idiv(5).mod(3) + 1
    if [1,2].include? i # Allow for an empty frame to help "move"
      args.nokia.sprites << [0, 0, 84, 48, "sprites/boss-spit-attack-#{i}.png"]
    end

    # 2 is the "hit"
    if i == 2
      args.state.player.hp -= rand(3)
      args.audio[:fx] = {input: 'sounds/blap.wav', pitch: 1.3} if i == 2
    end

    if elapsed == 100
      args.state.boss.transition_mode_to = :dive
    end

  end

  def attack(args)
    return if args.state.boss.mode == :intro
    elapsed = args.state.battle.player_attack.created_at_elapsed
    frame = case elapsed
    when 0..3
      1
    when 4..7
      2
    when 8
      # Miss
      if args.state.boss.mode == :dive
        args.state.battle.player_attack.missed = true
        "miss"
      # hit
      else
        args.state.battle.player_attack.missed = false
        args.audio[:fx] = {input: 'sounds/blap.wav'}
        args.state.battle.boss.damaged_at = args.tick_count
        args.state.battle.boss.hp -= rand(20) + weapon_damage(args)
        3
      end
    when 0..15
      3
    end

    frame = "miss" if args.state.battle.player_attack.missed
    args.nokia.sprites << [0, 0, 84, 48, "sprites/guy-attack-#{frame}.png"]
    args.state.battle.player_attack = nil if elapsed == 15
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
    args.audio.bg = nil
  end
end
end
