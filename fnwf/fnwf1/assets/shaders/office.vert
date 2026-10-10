#version 330 core
// Game-provided office shader (vertex). Edit freely — this shader lives in the
// game package, not in the engine. Loaded by the game with
// neko.shader.load_files(...). A missing file falls back to the built-in
// cylinder shader.
layout(location = 0) in vec2 a_pos;
layout(location = 1) in vec2 a_uv;
out vec2 v_screen;
void main() {
    v_screen = a_pos;
    gl_Position = vec4(a_pos.x * 2.0 - 1.0, 1.0 - a_pos.y * 2.0, 0.0, 1.0);
}
