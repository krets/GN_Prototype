shader_type canvas_item;

uniform float star_density : hint_range(0.0, 0.1) = 0.02;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float twinkle_speed : hint_range(0.0, 5.0) = 2.0;
uniform float min_star_size : hint_range(0.5, 2.0) = 0.5;
uniform float max_star_size : hint_range(1.0, 4.0) = 2.0;
uniform vec2 world_offset = vec2(0.0, 0.0);
uniform float layer_scale : hint_range(0.1, 10.0) = 1.0;

// Hash function for procedural generation
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Generate star at grid position
float star(vec2 grid_pos, float time) {
    vec2 cell_center = grid_pos + vec2(0.5);
    
    // Random offset within cell
    float rand1 = hash(grid_pos);
    float rand2 = hash(grid_pos + vec2(17.0, 31.0));
    vec2 offset = vec2(rand1, rand2) - vec2(0.5);
    
    // Only create star based on density
    if (hash(grid_pos + vec2(7.0, 13.0)) > star_density) {
        return 0.0;
    }
    
    // Star properties
    vec2 star_pos = cell_center + offset * 0.8;
    float distance = length(grid_pos - star_pos + vec2(0.5));
    
    // Variable star size
    float size_variation = hash(grid_pos + vec2(23.0, 41.0));
    float star_size = mix(min_star_size, max_star_size, size_variation);
    
    // Twinkle effect (much subtler)
    float twinkle = sin(time * twinkle_speed + rand1 * 6.28) * 0.1 + 0.9;  // Only varies between 0.8 and 1.0
    
    // Star intensity falloff
    float intensity = 1.0 - smoothstep(0.0, star_size, distance);
    intensity *= twinkle;
    
    // Vary star brightness
    float brightness_variation = hash(grid_pos + vec2(11.0, 37.0));
    intensity *= mix(0.3, 1.0, brightness_variation);
    
    return intensity;
}

void fragment() {
    // Get position in world space (accounting for camera movement)
    vec2 world_pos = (UV * vec2(textureSize(TEXTURE, 0))) + world_offset;
    world_pos *= layer_scale;
    
    // Grid-based star generation
    vec2 grid_pos = floor(world_pos / 200.0);  // Larger grid = fewer stars
    
    float stars = 0.0;
    
    // Check neighboring cells for smooth transitions
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 neighbor = grid_pos + vec2(float(x), float(y));
            vec2 relative_pos = world_pos / 200.0 - neighbor;  // Match the grid size
            stars += star(neighbor + relative_pos, TIME);
        }
    }
    
    // Apply brightness
    stars *= star_brightness;
    
    // Output white stars on transparent background
    COLOR = vec4(1.0, 1.0, 1.0, stars);
}