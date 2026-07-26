WEAPONS = {
    basic = function () return {
        -- bursts of attacks (like a magazine)
        round_rate = 0.5, -- time between bursts
        next_round = 0,   -- when the next burst can begin
        round_size = 1,   -- how many shots are fired each burst

        -- affects individual shots in a burst
        fire_rate = 0.1, -- how quickly each shot in around is fired
        current_shot = 1, -- how many shots have been fired in the current round
        next_shot = 0,    -- when the next shot can be fired
        shot_size = 2,    -- how many bullets are fired per shot
        spread = 0.25     -- angle between shots, in radians
    } end,
    basic_burst = function () return {
        -- bursts of attacks (like a magazine)
        round_rate = 0.05, -- time between bursts
        next_round = 0,   -- when the next burst can begin
        round_size = 1,   -- how many shots are fired each burst

        -- affects individual shots in a burst
        fire_rate = 0.1, -- how quickly each shot in around is fired
        current_shot = 1, -- how many shots have been fired in the current round
        next_shot = 0,    -- when the next shot can be fired
        shot_size = 2,    -- how many bullets are fired per shot
        spread = 0.25     -- angle between shots, in radians
    } end,
    slow_three = function () return {
        -- bursts of attacks (like a magazine)
        round_rate = 3, -- time between bursts
        next_round = 0,   -- when the next burst can begin
        round_size = 3,   -- how many shots are fired each burst

        -- affects individual shots in a burst
        fire_rate = 0.1, -- how quickly each shot in around is fired
        current_shot = 1, -- how many shots have been fired in the current round
        next_shot = 0,    -- when the next shot can be fired
        shot_size = 2,    -- how many bullets are fired per shot
        spread = 0.25     -- angle between shots, in radians
    } end
}