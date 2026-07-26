local dandelion = require("dandelion")
require("weapons")

local PLAYER_SIZE = 8
local BURST_WINDOW = 0.25
local MOVEMENT_CONTROL_RADIUS = 24

function _config()
    ---@type Usagi.Config
    return { name = "Mobile Shmup", game_id = "com.spad4.mobile_shmup", sprite_size = 8, game_height = 320, game_width = 180, pixel_perfect = true }
end

local function spawn_enemy(x, y)
    return {
        x = x,
        y = y,
        health = 12,
        r = 4,
        sprite = 2,
        color = gfx.COLOR_RED,
        flash_until = 0,
        weapon = WEAPONS.slow_three()
    }
end

local function new_wave()
    return {
        spawn_enemy(64, 64),
        spawn_enemy(80, 80),
        spawn_enemy(96, 80),
        spawn_enemy(112, 80),
        spawn_enemy(128, 64)
    }
end

function _init()
    Elapsed = 0
    Player = {
        max_health = 10,
        health = 10,
        energy = 0,
        max_energy = 9,
        x = usagi.GAME_W / 2 - PLAYER_SIZE / 2,
        y = usagi.GAME_H - 100,
        w = PLAYER_SIZE,
        h = PLAYER_SIZE,
        r = PLAYER_SIZE / 2,
        absorb_r = 16,
        hfw = PLAYER_SIZE / 2,
        hfh = PLAYER_SIZE / 2,
        speed = 3,
        i_frames = 0.25,
        invuln_until = 0
    }
    Mouse = {
        x = 0,
        y = 0,
        down_x = 0,
        down_y = 0,
        is_down = false,
        distance = 0,
        angle = 0,
        last_press = 0
    }
    Weapon = WEAPONS.basic()
    Burst_Weapon = WEAPONS.basic_burst()
    Can_Burst = false
    Burst_Active = false
    Player_Projectiles = {}
    Enemy_Projectiles = {}
    Room_Cleared = false
    Enemies = new_wave()

    -- slow mo
    Slow_Mo = {
        time = 0,
        duration = 0,
        scale = 0
    }
end

local function decaying_slow_mo(time, scale)
    Slow_Mo.time = time
    Slow_Mo.duration = time
    Slow_Mo.scale = scale
end

local function player_shoot()
    local new_projectile = {
        x = Player.x,
        y = Player.y,
        w = 2,
        h = 2,
        r = 4,
        damage = 3,
        color = gfx.COLOR_YELLOW,
        vx = 0,
        vy = -256
    }
    new_projectile.draw = function()
        gfx.circ_fill(new_projectile.x, new_projectile.y, new_projectile.w, new_projectile.color)
    end

    table.insert(Player_Projectiles, new_projectile)
end

local function enemy_shoot(enemy)
    local new_projectile = {
        x = enemy.x,
        y = enemy.y,
        w = 3,
        h = 3,
        r = 3,
        damage = 3,
        color = gfx.COLOR_RED,
        vx = 0,
        vy = 128
    }
    new_projectile.draw = function()
        gfx.circ_fill(new_projectile.x, new_projectile.y, new_projectile.w, new_projectile.color)
        if new_projectile.absorbed and Elapsed < new_projectile.absorbed then
            gfx.circ_fill(new_projectile.x, new_projectile.y, new_projectile.w, gfx.COLOR_BLUE,
                4 * (new_projectile.absorbed - Elapsed))
        end
    end

    table.insert(Enemy_Projectiles, new_projectile)
end
function _update(dt)
    Elapsed += dt

    -- decaying slow mo
    if Slow_Mo.time > 0 then
        Slow_Mo.time = math.max(0, Slow_Mo.time - dt)
        local scale = (1 - Slow_Mo.scale) * (1 - (Slow_Mo.time / Slow_Mo.duration) ^ 2)
        effect.slow_mo(0.5, Slow_Mo.scale + scale)
    end

    if Burst_Active then
        Player.energy -= Player.max_energy * 0.01
        if Player.energy <= 0 then
            Player.energy = 0
            Burst_Active = false
        end
    end

    -- Mouse/touch controls
    Mouse.x, Mouse.y = input.mouse()
    Mouse.is_down = input.mouse_held(input.MOUSE_LEFT)

    if input.mouse_pressed(input.MOUSE_LEFT) then
        Mouse.down_x, Mouse.down_y = Mouse.x, Mouse.y
        -- Start burst
        if not Burst_Active and Can_Burst and Elapsed - Mouse.last_press < BURST_WINDOW then
            Burst_Active = true
            decaying_slow_mo(0.5, 0)
        end
        Mouse.last_press = Elapsed
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
        Player.x = util.clamp(Player.x + move_vec.x, Player.w, usagi.GAME_W - Player.w)
        -- Player.y = util.clamp(Player.y + move_vec.y, 0, usagi.GAME_H - Player.h - 64)
        -- particles
        -- if move_vec.y < -0.25 then
        -- end
    end
    -- dandelion.engine_flame(Player.x, Player.y + Player.hfh)

    -- Player Shooting
    if not Room_Cleared and #Enemies > 0 then
        local weapon = Burst_Active and Burst_Weapon or Weapon
        if Elapsed > weapon.next_round then
            weapon.next_round = Elapsed + weapon.round_rate
            weapon.current_shot = 1
        end

        if weapon.current_shot ~= 0 and (weapon.current_shot == 1 or Elapsed > weapon.next_shot) then
            player_shoot()
            weapon.next_shot = Elapsed + weapon.fire_rate
            weapon.current_shot += 1
            if weapon.current_shot > weapon.round_size then
                weapon.current_shot = 0
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
                enemy.flash_until = Elapsed + 0.25

                -- dandelion.hit_enemy_number(enemy.x, enemy.y, { amount = projectile.damage })
                dandelion.player_projectile_break(projectile.x, projectile.y)

                if enemy.health < 0 then
                    table.remove(Enemies, e)
                end
                table.remove(Player_Projectiles, i)
                break
            end
        end
    end

    -- Enemy shooting
    for _, enemy in pairs(Enemies) do
        local weapon = enemy.weapon
        if Elapsed > weapon.next_round then
            weapon.next_round = Elapsed + weapon.round_rate
            weapon.current_shot = 1
        end

        if weapon.current_shot ~= 0 and (weapon.current_shot == 1 or Elapsed > weapon.next_shot) then
            enemy_shoot(enemy)
            weapon.next_shot = Elapsed + weapon.fire_rate
            weapon.current_shot += 1
            if weapon.current_shot > weapon.round_size then
                weapon.current_shot = 0
            end
        end
    end

    -- Enemy Projectiles
    for i = #Enemy_Projectiles, 1, -1 do
        local projectile = Enemy_Projectiles[i]
        projectile.x += projectile.vx * dt
        projectile.y += projectile.vy * dt

        if projectile.y < -16 then
            table.remove(Enemy_Projectiles, i)
        end

        -- Near miss
        if not Burst_Active and not projectile.absorbed and util.circ_overlap(projectile, { x = Player.x, y = Player.y, r = Player.absorb_r }) then
            projectile.absorbed = Elapsed + 0.25
            if Player.energy < Player.max_energy then
                Player.energy += projectile.damage
                if Player.energy >= Player.max_energy then
                    Player.energy = Player.max_energy
                    dandelion.burst_ready(Player.x, Player.y)
                end
            end
        end

        -- Hit player
        if util.circ_overlap(projectile, Player) and Elapsed > Player.invuln_until then
            Player.health = math.max(0, Player.health - projectile.damage)
            Player.invuln_until = Elapsed + Player.i_frames
            -- dandelion.hit_player_number(Player.x, Player.y, { amount = projectile.damage })
            dandelion.enemy_projectile_break(projectile.x, projectile.y)
            table.remove(Enemy_Projectiles, i)
            break
        end
    end
    Can_Burst = Player.energy == Player.max_energy
end

function _draw(dt)
    gfx.clear(gfx.COLOR_BLACK)
    gfx.rect_fill(0, 0, usagi.GAME_W, usagi.GAME_H, gfx.COLOR_INDIGO, 0.1)

    -- player
    dandelion.DrawGroups("engine_flame")
    gfx.spr_ex(1, Player.x - Player.r, Player.y - Player.r, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)
    if Elapsed < Player.invuln_until then
        gfx.spr_ex(1, Player.x - Player.r, Player.y - Player.r, false, false, 0, gfx.COLOR_RED,
            4 * (Player.invuln_until - Elapsed))
    end

    -- Player projectiles
    for i = #Player_Projectiles, 1, -1 do
        local projectile = Player_Projectiles[i]
        projectile.draw()
    end

    -- Enemies
    for _, enemy in pairs(Enemies) do
        gfx.spr_ex(enemy.sprite, enemy.x - enemy.r, enemy.y - enemy.r, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)
        if Elapsed < enemy.flash_until then
            gfx.spr_ex(enemy.sprite, enemy.x - enemy.r, enemy.y - enemy.r, false, false, 0, gfx.COLOR_INDIGO,
                4 * (enemy.flash_until - Elapsed))
        end
    end

    -- Enemy projectiles
    for i = #Enemy_Projectiles, 1, -1 do
        local projectile = Enemy_Projectiles[i]
        projectile.draw()
    end

    dandelion.DrawExcept()

    local bar_x, bar_y = Player.x - Player.hfw, Player.y + Player.h - 2
    local health_percent = Player.health / Player.max_health
    local health_color = Elapsed < Player.invuln_until and Elapsed % 0.15 > 0.075 and gfx.COLOR_WHITE or gfx.COLOR_GREEN
    local energy_percent = Player.energy / Player.max_energy
    local energy_color = (Can_Burst or Burst_Active) and Elapsed % 0.15 > 0.075 and gfx.COLOR_WHITE or gfx.COLOR_BLUE
    -- mini health bar
    gfx.line(bar_x, bar_y, bar_x + Player.w * health_percent, bar_y, gfx.COLOR_GREEN)

    -- mini energy bar
    gfx.line(bar_x, bar_y + 1, bar_x + Player.w * energy_percent, bar_y + 1, energy_color)

    -- NO GAME ENTITIES BEYOND THIS POINT

    -- bottom of screen UI
    gfx.rect_fill(0, usagi.GAME_H - 64, usagi.GAME_W, 64, gfx.COLOR_DARK_GRAY)

    -- UI health + energy bars
    local bar_size = (usagi.GAME_W / 2 - 9)
    -- empty health bar
    gfx.rect_fill(4, 260, bar_size, 8, gfx.COLOR_DARK_GREEN) -- health
    -- empty energy bar
    gfx.rect_fill((usagi.GAME_W / 2 + 5), 260, bar_size, 8, gfx.COLOR_DARK_BLUE)

    -- filled health bar
    gfx.rect_fill(4, 260, bar_size * health_percent, 8, health_color)
    -- filled energy bar
    gfx.rect_fill((usagi.GAME_W / 2 + 5) + bar_size * (1 - energy_percent), 260, bar_size * energy_percent, 8,
        energy_color)

    -- health triangle
    gfx.tri_fill(85, 260, 92, 260, 85, 268, Player.health == Player.max_health and health_color or gfx.COLOR_DARK_GREEN)

    -- energy triangle
    gfx.tri_fill(95, 261, 95, 268, 87, 268, Can_Burst and energy_color or gfx.COLOR_DARK_BLUE)

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

    local mx, my = input.mouse()
    gfx.text(math.floor(mx) .. " " .. math.floor(my), 0, 0, gfx.COLOR_WHITE)
end
