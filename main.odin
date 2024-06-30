package main

import rl "vendor:raylib"
import m  "core:math/linalg/hlsl"
import    "core:fmt"

Paddle :: struct {
    texture       : rl.Texture2D,
    textureCoords : rl.Rectangle,
    position      : rl.Vector2,
}

Ball :: struct {
    texture       : rl.Texture2D,
    textureCoords : rl.Rectangle,
    position      : m.float2,
    velocity      : m.float2,
    size          : f32,
}

player_paddle : Paddle
ball : Ball

main :: proc() {
    // Set the window parameters
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
            screen_params.y - 75,
        },
    }

    ball = Ball {
        texture       = sprite_atlas,
        textureCoords = rl.Rectangle{60, 0, 20, 20},
        position      = m.float2{f32(screen_params.x / 2), f32(screen_params.y / 2)},
        velocity      = m.float2{200, -200},
        size          = 40,
    }

    for is_running && !rl.WindowShouldClose() {
        delta_time := rl.GetFrameTime()
        set_window_parameters(screen_width, screen_height, &screen_params)
        rl.BeginTextureMode(render_texture)
        rl.ClearBackground(rl.BLACK)
        rl.DrawFPS(10, 10)

        // Update paddle position
        if (rl.IsKeyDown(rl.KeyboardKey.RIGHT)) {
            player_paddle.position.x += 1000 * delta_time
        }
        if (rl.IsKeyDown(rl.KeyboardKey.LEFT)) {
            player_paddle.position.x -= 1000 * delta_time
        }

        // Draw paddle
        rl.DrawTexturePro(
            player_paddle.texture, 
            player_paddle.textureCoords, 
            rl.Rectangle{player_paddle.position.x, player_paddle.position.y, 300, 75},
            rl.Vector2{0, 0}, 
            0, 
            rl.WHITE
        )

        // Update and draw ball
        ball.position += ball.velocity * delta_time * 5
        rl.DrawTexturePro(
            ball.texture, 
            ball.textureCoords, 
            rl.Rectangle{ball.position.x, ball.position.y, ball.size, ball.size},
            rl.Vector2{0, 0}, 
            0, 
            rl.WHITE
        )

        //Check for collision with sides of the screen
        if (ball.position.x <= 0 || ball.position.x >= f32(screen_width) - ball.size) {
            ball.velocity.x *= -1
        }
        if (ball.position.y <= 0 || ball.position.y >= f32(screen_height) - ball.size) {
            ball.velocity.y *= -1
        }

        check_collision(&ball, &player_paddle)

        rl.EndTextureMode()

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLUE)
        
        rl.DrawTexturePro(
            texture  = render_texture.texture,
            source   = rl.Rectangle{0, 0, f32(render_texture.texture.width), -f32(render_texture.texture.height)},
            dest     = rl.Rectangle{0, 0, f32(screen_params.x), f32(screen_params.y)},
            origin   = rl.Vector2{0, 0},
            rotation = 0,
            tint     = rl.WHITE
        )

        rl.EndDrawing()
    }

    // Clean up
    rl.UnloadTexture(sprite_atlas)
    rl.UnloadRenderTexture(render_texture)
    rl.CloseWindow()
    free(&screen_params)
}

check_collision :: proc(ball: ^Ball, paddle: ^Paddle) {
    ball_rect := rl.Rectangle{ball.position.x, ball.position.y, ball.size, ball.size}
    //change this eventually to have the paddle_rect be a member of the paddle struct
    paddle_rect := rl.Rectangle{paddle.position.x, paddle.position.y, 300, 75}

    if (rl.CheckCollisionRecs(ball_rect, paddle_rect)) {
        ball^.velocity.y *= -1
    }
}