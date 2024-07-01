package main

import rl "vendor:raylib"
import    "core:fmt"
import m  "core:math/linalg/hlsl"
import    "core:math/rand"


Paddle :: struct {
    textureCoords : rl.Rectangle,
    position      : rl.Vector2
}

Ball :: struct {
    textureCoords : rl.Rectangle,
    position      : rl.Vector2,
    velocity      : rl.Vector2,
    size          : f32,
}

Brick :: struct {
    textureCoords : rl.Rectangle,
    damageCoords  : rl.Rectangle,
    position      : rl.Vector2,
    size          : rl.Vector2,
    health        : i32,
    hasDied       : bool,
    color         : rl.Color,
}

player_paddle : Paddle
ball : Ball

PADDLE_SPEED :: 1500
BALL_SPEED :: 3

color_map := map[int]HSV{
    0 = HSV{90, .5, 1},
    1 = HSV{120, .5, 1},
    2 = HSV{140, .5, 1},
    3 = HSV{160, .5, 1},
    4 = HSV{180, .5, 1},
    5 = HSV{200, .5, 1},
    6 = HSV{220, .5, 1},
    7 = HSV{240, .5, 1},
    8 = HSV{260, .5, 1},
    9 = HSV{280, .5, 1},
}

deathTimer   := f32(1.0)
currentTimer := f32(0.0)
hasDied      := false


main :: proc() {
    screen_width  := i32(1920)
    screen_height := i32(1080)
    monitor_id    := i32(0)
    is_running    := true

    rl.InitWindow(screen_width, screen_height, "Brick Breakers")
    rl.InitAudioDevice()

    rl.SetWindowMonitor(monitor_id)
    rl.SetConfigFlags(rl.ConfigFlags{rl.ConfigFlag.VSYNC_HINT})

    screen_params := m.float2{f32(screen_width), f32(screen_height)}
    refresh_rate  := rl.GetMonitorRefreshRate(monitor_id)

    rl.SetTargetFPS(refresh_rate)
    
    fullscreen_texture   := rl.LoadRenderTexture(screen_width, screen_height)
    sprite_atlas     := rl.LoadTexture("resources/sprite_atlas.png")

    explosion_sound  := rl.LoadSound("resources/sounds/explosion.wav")
    brick_hit_sound  := rl.LoadSound("resources/sounds/brick_hit.wav")
    paddle_hit_sound := rl.LoadSound("resources/sounds/paddle_hit.wav")
    lose_sound       := rl.LoadSound("resources/sounds/lose.wav")

    rl.SetSoundVolume(brick_hit_sound, 0.2)
    rl.SetSoundVolume(explosion_sound, 0.6)
    rl.SetSoundVolume(paddle_hit_sound, 0.2)
    rl.SetSoundVolume(lose_sound, 0.2)

    // Game Data
    player_paddle = Paddle {
        textureCoords = rl.Rectangle{0, 0, 120, 20},
        position      = rl.Vector2{
            screen_params.x / 2 - 150,
            screen_params.y - 20,
        },
    }

    ball = Ball {
        textureCoords = rl.Rectangle{120, 0, 20, 20},
        position      = rl.Vector2{f32(screen_params.x / 2), f32(screen_params.y / 2) + 300},
        velocity      = rl.Vector2{0, -200},
        size          = 20,
    }

    number_of_bricks :: 1024
    bricks   := [number_of_bricks]Brick{}
    x_offset := f32(screen_width) * 0.5 - 960

    for i := 0; i < number_of_bricks; i += 1 {
        row := i / 32
        x_position := f32((i & 31) * 60) + x_offset
        y_position := f32(row) * 20

        bricks[i] = Brick {
            textureCoords = rl.Rectangle{0, 20, 60, 20},
            damageCoords  = rl.Rectangle{0, 40, 60, 20},
            position      = rl.Vector2{x_position, y_position},
            size          = rl.Vector2{60, 20},
            health        = 2,
            hasDied       = false,
            color         = hsv_to_rgb(color_map[i % 10])
        }
    }

    for is_running && !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        set_window_parameters(screen_width, screen_height, &screen_params)
        rl.BeginTextureMode(fullscreen_texture)
        rl.ClearBackground(rl.BLACK)

        // input
        if (rl.IsKeyDown(rl.KeyboardKey.RIGHT)) {
            player_paddle.position.x += PADDLE_SPEED * delta_time
        }
        if (rl.IsKeyDown(rl.KeyboardKey.LEFT)) {
            player_paddle.position.x -= PADDLE_SPEED * delta_time
        }

        // paddle bounds
        if (player_paddle.position.x < 0) {
            player_paddle.position.x = 0
        }
        if (player_paddle.position.x > screen_params.x - 160) {
            player_paddle.position.x = screen_params.x - 160
        }

        // bricks
        for i := 0; i < number_of_bricks; i += 1 {
            if (bricks[i].health > 0) {
                coords := bricks[i].textureCoords
                if (bricks[i].health == 1) {
                    coords = bricks[i].damageCoords
                }
                rl.DrawTexturePro(
                    sprite_atlas, 
                    coords, 
                    rl.Rectangle{bricks[i].position.x, bricks[i].position.y, 60, 20},
                    rl.Vector2{0, 0}, 
                    0, 
                    bricks[i].color
                )
                check_brick_collision(&ball, &bricks[i], explosion_sound, brick_hit_sound)
            }
        }

        // paddle
        rl.DrawTexturePro(
            sprite_atlas, 
            player_paddle.textureCoords, 
            rl.Rectangle{player_paddle.position.x, player_paddle.position.y, 160, 20},
            rl.Vector2{0, 0}, 
            0, 
            rl.WHITE
        )
        currentTimer -= delta_time
        currentTimer = m.max_float(currentTimer, 0)

        // ball
        if currentTimer != 0 {
            ball.velocity = rl.Vector2{0, 0}
        }
        else
        {
            if hasDied {
                angle := rand.float32_range(0, 2 * m.PI)
                direction := rl.Vector2{
                    m.cos(angle),
                    m.sin(angle),
                }
                ball.velocity = direction * 200
            }
            ball.position += ball.velocity * delta_time * BALL_SPEED
            hasDied = false
        }

        rl.DrawTexturePro(
            sprite_atlas, 
            ball.textureCoords, 
            rl.Rectangle{ball.position.x, ball.position.y, ball.size, ball.size},
            rl.Vector2{0, 0}, 
            0, 
            rl.WHITE
        )

        // ball collision with sides of the screen
        if (ball.position.x <= 0 || ball.position.x >= f32(screen_width) - ball.size) {
            ball.velocity.x *= -1
        }
        if (ball.position.y <= 0) {
            ball.velocity.y *= -1
        }
        if (ball.position.y >= f32(screen_height) - ball.size)
        {
            rl.PlaySound(lose_sound)
            ball.position = rl.Vector2{f32(screen_params.x / 2), f32(screen_params.y / 2) + 300}
            ball.velocity = rl.Vector2{0, 0}
            currentTimer = deathTimer
            hasDied = true
        }


        check_paddle_collision(&ball, &player_paddle, paddle_hit_sound)

        rl.EndTextureMode()

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLUE)
        
        // fullscreen quad
        rl.DrawTexturePro(
            texture  = fullscreen_texture.texture,
            source   = rl.Rectangle{0, 0, f32(fullscreen_texture.texture.width), -f32(fullscreen_texture.texture.height)},
            dest     = rl.Rectangle{0, 0, f32(screen_params.x), f32(screen_params.y)},
            origin   = rl.Vector2{0, 0},
            rotation = 0,
            tint     = rl.WHITE
        )

        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }

    // Clean up
    rl.UnloadTexture(sprite_atlas)
    rl.UnloadRenderTexture(fullscreen_texture)
    rl.CloseWindow()
    rl.UnloadSound(brick_hit_sound)
    rl.UnloadSound(explosion_sound)
    rl.UnloadSound(paddle_hit_sound)
    rl.CloseAudioDevice()
    free(&screen_params)
}

check_paddle_collision :: proc(ball: ^Ball, paddle: ^Paddle, paddle_hit_sound: rl.Sound) {
    ball_rect := rl.Rectangle{ball.position.x, ball.position.y, ball.size, ball.size}
    paddle_rect := rl.Rectangle{paddle.position.x, paddle.position.y, 160, 50}

    if rl.CheckCollisionRecs(ball_rect, paddle_rect) {
        collision_point := rl.Vector2{
            rl.Clamp(ball.position.x, paddle.position.x, paddle.position.x + 160),
            ball.position.y + ball.size,
        }

        relative_collision_x := (collision_point.x - paddle.position.x) / 160

        angle := rl.Lerp(-60, 60, relative_collision_x) * rl.DEG2RAD

        speed := rl.Vector2Length(ball.velocity)
        ball.velocity.x = speed * m.sin(angle)
        ball.velocity.y = -speed * m.cos(angle)

        ball.position.y = paddle.position.y - ball.size - 1

        rl.PlaySound(paddle_hit_sound)
    }
}

check_brick_collision :: proc(ball: ^Ball, brick: ^Brick, explosion_sound: rl.Sound, brick_hit_sound: rl.Sound) {
    ball_rect := rl.Rectangle{ball.position.x, ball.position.y, ball.size, ball.size}
    brick_rect := rl.Rectangle{brick.position.x, brick.position.y, brick.size.x, brick.size.y}

    if rl.CheckCollisionRecs(ball_rect, brick_rect) {
        overlap_left   := (ball.position.x + ball.size) - brick.position.x
        overlap_right  := (brick.position.x + brick.size.x) - ball.position.x
        overlap_top    := (ball.position.y + ball.size) - brick.position.y
        overlap_bottom := (brick.position.y + brick.size.y) - ball.position.y

        min_overlap := min(overlap_left, overlap_right, overlap_top, overlap_bottom)

        if min_overlap == overlap_left || min_overlap == overlap_right {
            ball.velocity.x *= -1
        } else {
            ball.velocity.y *= -1
        }

        if min_overlap == overlap_left {
            ball.position.x = brick.position.x - ball.size
        } else if min_overlap == overlap_right {
            ball.position.x = brick.position.x + brick.size.x
        } else if min_overlap == overlap_top {
            ball.position.y = brick.position.y - ball.size
        } else {
            ball.position.y = brick.position.y + brick.size.y
        }
        brick.health -= 1
        rl.PlaySound(brick_hit_sound)
        if (brick.health == 0) {
            rl.PlaySound(explosion_sound)
            brick.hasDied = true
        }
    }
}