// BETTER DEBUG SHADER - Small, dense stars
shader_type canvas_item;

uniform float star_density : hint_range(0.0001, 10) = 0.002;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;
uniform float star_size : hint_range(0.001, 2.0) = 1.0;

// Simple hash function
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

void fragment() {
    // Create a grid of potential star positions
    vec2 grid_size = vec2(50.0);  // 30x30 grid across the UV space
    vec2 grid_pos = floor(UV * grid_size);
    vec2 cell_uv = fract(UV * grid_size);
    
    float star_alpha = 0.0;
    
    // Use hash to randomly decide if this cell has a star
    float star_chance = hash21(grid_pos);
    
    // Adjust the density scaling to make stars more visible
    float adjusted_density = star_density * 50000.0;  // Much higher multiplier
    
    // Only create a star if the random value is within our density range
    if (star_chance < adjusted_density) {
        // Position the star randomly within the cell
        vec2 star_pos = vec2(hash21(grid_pos + vec2(12.34, 56.78)), 
                            hash21(grid_pos + vec2(78.90, 23.45)));
        
        // Distance from current pixel to star center
        float dist = length(cell_uv - star_pos) * grid_size.x;
        
        // Create small, sharp stars
        float star_radius = star_size;
        if (dist < star_radius) {
            float intensity = 1.0 - (dist / star_radius);
            intensity = pow(intensity, 5.0);  // Sharp but not too sharp
            star_alpha = intensity * star_brightness;
        }
    }
    
    COLOR = vec4(1.0, 1.0, 1.0, star_alpha);
}