local dandelion = require("dandelion")

local PLAYER_SIZE = 8
MOVEMENT_CONTROL_RADIUS = 24

function _config()
    ---@type Usagi.Config
    return { name = "Mobile Shmup", game_id = "com.spad4.mobile_shmup", sprite_size = 8, game_height = 320, game_width = 180 }
end

local function spawn_enemy(x, y)
    return {
        x = x,
        y = y,
        health = 12,
        r = 4,
        sprite = 2,
        color = gfx.COLOR_RED,
        flash_until = 0
    }
end

local function new_wave()
    return {
        spawn_enemy(64, 64),
        spawn_enemy(80, 64),
        spawn_enemy(96, 64),
        spawn_enemy(112, 64),
        spawn_enemy(128, 64)
    }
end

function _init()
    Elapsed = 0
    Player = {
        health = 10,
        x = usagi.GAME_W / 2 - PLAYER_SIZE / 2,
        y = usagi.GAME_H - 100,
        w = PLAYER_SIZE,
        h = PLAYER_SIZE,
        hfw = PLAYER_SIZE / 2,
        hfh = PLAYER_SIZE / 2,
        speed = 3
    }
    Mouse = {
        x = 0,
        y = 0,
        down_x = 0,
        down_y = 0,
        is_down = false,
        distance = 0,
        angle = 0
    }
    Weapon = {
        -- bursts of attacks (like a magazine)
        burst_rate = 0.5, -- time between bursts
        next_burst = 0,   -- when the next burst can begin
        burst_size = 1,   -- how many shots are fired each burst

        -- affects individual shots in a burst
        fire_rate = 0.1, -- how quickly each shot in around is fired
        current_shot = 1, -- how many shots have been fired in the current round
        next_shot = 0,    -- when the next shot can be fired
        shot_size = 2,    -- how many bullets are fired per shot
        spread = 0.25     -- angle between shots, in radians
    }
    Player_Projectiles = {}
    Room_Cleared = false
    Enemies = new_wave()
end

local function player_shoot()
    local new_projectile = {
        x = Player.x + Player.hfw,
        y = Player.y,
        w = 2,
        h = 2,
        r = 4,
        damage = 0,
        color = gfx.COLOR_YELLOW,
        vx = 0,
        vy = -256
    }
    new_projectile.draw = function()
        gfx.circ_fill(new_projectile.x, new_projectile.y, new_projectile.w, new_projectile.color)
    end

    table.insert(Player_Projectiles, new_projectile)
end

function _update(dt)
    Elapsed += dt
    -- Mouse/touch controls
    Mouse.x, Mouse.y = input.mouse()
    Mouse.is_down = input.mouse_held(input.MOUSE_LEFT)

    if input.mouse_pressed(input.MOUSE_LEFT) then
        Mouse.down_x, Mouse.down_y = Mouse.x, Mouse.y
    end

    if Mouse.is_down then
        local vx, vy = Mouse.x - Mouse.down_x, Mouse.y - Mouse.down_y
        Mouse.distance = util.vec_dist({ x = 0, y = 0 }, { x = vx, y = vy })
        if Mouse.distance == 0 then
            Mouse.angle = 0
        else
            local theta = math.asin(vy / Mouse.distance) or 0
            Mouse.angle = vx > 0 and theta or (math.pi - theta)
        end
        Mouse.distance = math.min(Mouse.distance, MOVEMENT_CONTROL_RADIUS)
    else
        Mouse.distance = 0
        Mouse.angle = 0
    end

    -- player movement
    if Mouse.is_down then
        local move_vec = util.vec_from_angle(Mouse.angle, Player.speed * Mouse.distance * dt)
        Player.x = util.clamp(Player.x + move_vec.x, 0, usagi.GAME_W - Player.w)
        Player.y = util.clamp(Player.y + move_vec.y, 0, usagi.GAME_H - Player.h - 64)
        -- particles
        if move_vec.y < -0.25 then
            dandelion.engine_flame(Player.x + Player.hfw, Player.y + Player.hfh)
        end
    end

    -- Shooting
    if not Room_Cleared then
        if Elapsed > Weapon.next_burst then
            Weapon.next_burst = Elapsed + Weapon.burst_rate
            Weapon.current_shot = 1
        end

        if Weapon.current_shot ~= 0 and (Weapon.current_shot == 1 or Elapsed > Weapon.next_shot) then
            player_shoot()
            Weapon.next_shot = Elapsed + Weapon.fire_rate
            Weapon.current_shot += 1
            if Weapon.current_shot > Weapon.burst_size then
                Weapon.current_shot = 0
            end
        end
    end

    -- Player Projectiles
    for i = #Player_Projectiles, 1, -1 do
        local projectile = Player_Projectiles[i]
        projectile.x += projectile.vx * dt
        projectile.y += projectile.vy * dt

        if projectile.y < -16 then
            table.remove(Player_Projectiles, i)
        end

        -- Hit enemies
        for e = #Enemies, 1, -1 do
            local enemy = Enemies[e]
            if util.circ_overlap(projectile, enemy) then
                enemy.health -= projectile.damage
                -- dandelion.damage_number(enemy.x, enemy.y, {amount = projectile.damage})
                enemy.flash_until = Elapsed + 0.25
                table.remove(Player_Projectiles, i)
                if enemy.health < 0 then
                    table.remove(Enemies, e)
                end
                break
            end
        end
    end
end

function _draw(dt)
    gfx.clear(gfx.COLOR_BLACK)

    -- player
    dandelion.DrawGroups("engine_flame")
    gfx.spr_ex(1, Player.x, Player.y, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)

    -- Player projectiles
    for i = #Player_Projectiles, 1, -1 do
        local projectile = Player_Projectiles[i]
        projectile.draw()
    end

    -- Enemies
    for _, enemy in pairs(Enemies) do
        gfx.spr_ex(enemy.sprite, enemy.x-enemy.r, enemy.y-enemy.r, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)
        if Elapsed < enemy.flash_until then
            gfx.spr_ex(enemy.sprite, enemy.x-enemy.r, enemy.y-enemy.r, false, false, 0, gfx.COLOR_INDIGO, 4 * (enemy.flash_until - Elapsed))
        end
    end

    dandelion.DrawExcept()

    -- NO GAME ENTITIES BEYOND THIS POINT

    -- bottom of screen UI
    gfx.rect_fill(0, usagi.GAME_H - 64, usagi.GAME_W, 64, gfx.COLOR_BLACK)

    -- Movement dial
    if Mouse.is_down then
        -- outline
        gfx.circ(Mouse.down_x, Mouse.down_y, MOVEMENT_CONTROL_RADIUS, gfx.COLOR_WHITE)

        -- line to mouse, capped at movement control radius
        local line_end = util.vec_normalize({ x = Mouse.x - Mouse.down_x, y = Mouse.y - Mouse.down_y })
        line_end.x, line_end.y = line_end.x * Mouse.distance, line_end.y * Mouse.distance
        gfx.line(Mouse.down_x, Mouse.down_y, Mouse.down_x + line_end.x, Mouse.down_y + line_end.y, gfx.COLOR_WHITE)
    end

    -- gfx.rect(0, 1, usagi.GAME_W, usagi.GAME_H - 64, gfx.COLOR_INDIGO)
    -- THE FUCKIN LINE
    gfx.line(0, 0, usagi.GAME_W, 0, gfx.COLOR_BLACK)
end
