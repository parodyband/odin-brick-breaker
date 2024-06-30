package main

import rl "vendor:raylib"
import    "core:fmt"
import m  "core:math/linalg/hlsl"

when ODIN_OS == .Windows {
    foreign import kernel32 "system:kernel32.lib"
    
    @(default_calling_convention="stdcall")
    foreign kernel32 {
        AllocConsole :: proc() -> i32 ---
        FreeConsole :: proc() -> i32 ---
    }
}

Paddle :: struct {
    texture       : rl.Texture2D,
    textureCoords : rl.Rectangle,
    position      : rl.Vector2,
}

Ball :: struct {
    texture       : rl.Texture2D,
    textureCoords : rl.Rectangle,
    position      : rl.Vector2,
    velocity      : rl.Vector2,
    size          : f32,
}

Brick :: struct {
    texture       : rl.Texture2D,
    textureCoords : rl.Rectangle,
    damageCoords  : rl.Rectangle,
    position      : rl.Vector2,
    size          : rl.Vector2,
    health        : i32,
}

player_paddle : Paddle
ball : Ball

PADDLE_SPEED :: 1500
BALL_SPEED :: 3

main :: proc() {
    screen_width  := i32(1920)
    screen_height := i32(1080)
    monitor_id    := i32(0)
    is_running    := true

    rl.InitWindow(screen_width, screen_height, "Brick Breakers")
    rl.SetWindowMonitor(monitor_id)
    rl.SetConfigFlags(rl.ConfigFlags{rl.ConfigFlag.VSYNC_HINT})

    screen_params := m.float2{f32(screen_width), f32(screen_height)}
    refresh_rate := rl.GetMonitorRefreshRate(monitor_id)

    rl.SetTargetFPS(refresh_rate)
    
    render_texture := rl.LoadRenderTexture(screen_width, screen_height)
    sprite_atlas := rl.LoadTexture("resources/sprite_atlas.png")

    // Game Data
    player_paddle = Paddle {
        texture       = sprite_atlas,
        textureCoords = rl.Rectangle{0, 0, 60, 20},
        position      = rl.Vector2{
            screen_params.x / 2 - 150,
            screen_params.y - 20,
        },
    }

    ball = Ball {
        texture       = sprite_atlas,
        textureCoords = rl.Rectangle{60, 0, 20, 20},
        position      = rl.Vector2{f32(screen_params.x / 2), f32(screen_params.y / 2) + 300},
        velocity      = rl.Vector2{200, -200},
        size          = 20,
    }

    number_of_bricks :: 1024
    bricks := [number_of_bricks]Brick{}

    for i := 0; i < number_of_bricks; i += 1 {
        row := i / 32
        bricks[i] = Brick {
            texture       = sprite_atlas,
            textureCoords = rl.Rectangle{0, 20, 60, 20},
            damageCoords  = rl.Rectangle{0, 40, 60, 20},
            position      = rl.Vector2{((f32(i % 32) * 60) + f32(screen_width) / 2) - 60 * 16, f32(row) * 20},
            size          = rl.Vector2{60, 20},
            health        = 2,
        }
    }

    for is_running && !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        set_window_parameters(screen_width, screen_height, &screen_params)
        rl.BeginTextureMode(render_texture)
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
                    bricks[i].texture, 
                    coords, 
                    rl.Rectangle{bricks[i].position.x, bricks[i].position.y, 60, 20},
                    rl.Vector2{0, 0}, 
                    0, 
                    rl.WHITE
                )
                check_brick_collision(&ball, &bricks[i])
            }
        }

        // paddle
        rl.DrawTexturePro(
            player_paddle.texture, 
            player_paddle.textureCoords, 
            rl.Rectangle{player_paddle.position.x, player_paddle.position.y, 160, 20},
            rl.Vector2{0, 0}, 
            0, 
            rl.WHITE
        )

        // ball
        ball.position += ball.velocity * delta_time * BALL_SPEED
        rl.DrawTexturePro(
            ball.texture, 
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
        if (ball.position.y <= 0 || ball.position.y >= f32(screen_height) - ball.size) {
            ball.velocity.y *= -1
        }

        check_paddle_collision(&ball, &player_paddle)

        rl.EndTextureMode()

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLUE)
        
        // fullscreen quad
        rl.DrawTexturePro(
            texture  = render_texture.texture,
            source   = rl.Rectangle{0, 0, f32(render_texture.texture.width), -f32(render_texture.texture.height)},
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
    rl.UnloadRenderTexture(render_texture)
    rl.CloseWindow()
    free(&screen_params)
}

check_paddle_collision :: proc(ball: ^Ball, paddle: ^Paddle) {
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
    }
}

check_brick_collision :: proc(ball: ^Ball, brick: ^Brick) {
    ball_rect := rl.Rectangle{ball.position.x, ball.position.y, ball.size, ball.size}
    brick_rect := rl.Rectangle{brick.position.x, brick.position.y, brick.size.x, brick.size.y}

    if rl.CheckCollisionRecs(ball_rect, brick_rect) {
        overlap_left := (ball.position.x + ball.size) - brick.position.x
        overlap_right := (brick.position.x + brick.size.x) - ball.position.x
        overlap_top := (ball.position.y + ball.size) - brick.position.y
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
    }
}