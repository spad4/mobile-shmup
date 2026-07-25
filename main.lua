local dandelion = require("dandelion")

local PLAYER_SIZE = 8
MOVEMENT_CONTROL_RADIUS = 24

function _config()
    ---@type Usagi.Config
    return { name = "Mobile Shmup", game_id = "com.spad4.mobile_shmup", sprite_size = 8, game_height = 320, game_width = 180 }
end

function _init()
    Elapsed = 0
    Player = {
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
        burst_rate = 1, -- time between bursts
        next_burst = 0, -- when the next burst can begin
        burst_size = 2, -- how many shots are fired each burst

        -- affects individual shots in a round
        fire_rate = 0.25, -- how quickly each shot in around is fired
        current_shot = 1, -- how many shots have been fired in the current round
        next_shot = 0     -- when the next shot can be fired
    }
    Player_Projectiles = {}
end

local function new_player_projectile()
    local new_projectile = {
        x = Player.x,
        y = Player.y,
        speed = 128
    }

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
        local dx, dy = Mouse.x - Mouse.down_x, Mouse.y - Mouse.down_y
        Mouse.distance = util.vec_dist({ x = 0, y = 0 }, { x = dx, y = dy })
        if Mouse.distance == 0 then
            Mouse.angle = 0
        else
            local theta = math.asin(dy / Mouse.distance) or 0
            Mouse.angle = dx > 0 and theta or (math.pi - theta)
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
    -- if not Room_Cleared then
    if Elapsed > Weapon.next_burst then
        Weapon.next_burst = Elapsed + Weapon.burst_rate
        Weapon.current_shot = 1
    end

    if Weapon.current_shot ~= 0 and Elapsed > Weapon.next_shot then
        new_player_projectile()
        Weapon.next_shot = Elapsed + Weapon.fire_rate
        Weapon.current_shot += 1
        if Weapon.current_shot > Weapon.burst_size then
            Weapon.current_shot = 0
        end
    end
    -- end

    -- Player Projectiles
    for i = #Player_Projectiles, 1, -1 do
        local projectile = Player_Projectiles[i]
        projectile.y -= projectile.speed * dt

        if projectile.y < -16 then
            table.remove(Player_Projectiles, i)
        end
    end
end

function _draw(dt)
    gfx.clear(gfx.COLOR_DARK_GRAY)

    -- player
    dandelion.DrawGroups("engine_flame")
    gfx.spr_ex(1, Player.x, Player.y, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)


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
end
