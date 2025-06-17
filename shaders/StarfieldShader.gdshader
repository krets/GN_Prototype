shader_type canvas_item;

uniform float star_density : hint_range(0.0, 0.1) = 0.002;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float twinkle_speed : hint_range(0.0, 5.0) = 0.5;
uniform float star_size : hint_range(1.0, 50.0) = 10.0;
uniform vec2 world_offset = vec2(0.0, 0.0);
uniform float layer_scale : hint_range(0.1, 10.0) = 1.0;

// Hash function for procedural generation
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    // Get world position
    vec2 world_pos = (UV * vec2(2000.0, 2000.0)) + world_offset;
    world_pos *= layer_scale;
    
    // Grid-based star generation
    vec2 grid_pos = floor(world_pos / 100.0);
    
    float stars = 0.0;
    
    // Check neighboring cells
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 neighbor = grid_pos + vec2(float(x), float(y));
            
            // Only create star based on density
            if (hash(neighbor + vec2(7.0, 13.0)) > star_density) {
                continue;
            }
            
            // Star position
            vec2 star_offset = vec2(hash(neighbor), hash(neighbor + vec2(17.0, 31.0)));
            vec2 star_pos = (neighbor + star_offset) * 100.0;
            
            // Distance to star
            float dist = length(world_pos - star_pos);
            
            if (dist < star_size) {
                // Star intensity
                float intensity = 1.0 - (dist / star_size);
                intensity = pow(intensity, 2.0); // Softer falloff
                
                // Twinkle
                float twinkle = sin(TIME * twinkle_speed + hash(neighbor) * 6.28) * 0.1 + 0.9;
                intensity *= twinkle;
                
                stars = max(stars, intensity);
            }
        }
    }
    
    // Apply brightness
    stars *= star_brightness;
    
    // Output
    COLOR = vec4(1.0, 1.0, 1.0, stars);
}