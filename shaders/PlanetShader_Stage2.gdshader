shader_type canvas_item;

// === PLANET PARAMETERS ===
// Basic shape and size
uniform float planet_radius : hint_range(0.1, 0.5) = 0.4;
uniform float edge_softness : hint_range(0.0, 0.1) = 0.02;

// === TERRAIN SYSTEM ===
// Primary terrain noise (large features)
uniform float terrain_scale : hint_range(0.1, 50.0) = 2.0;
uniform float terrain_strength : hint_range(0.0, 1.0) = 0.6;
uniform float terrain_octaves : hint_range(1, 6) = 4;
uniform float terrain_persistence : hint_range(0.1, 0.9) = 0.5;

// Secondary detail noise (fine features)
uniform float detail_scale : hint_range(2.0, 20.0) = 8.0;
uniform float detail_strength : hint_range(0.0, 0.5) = 0.2;
uniform float detail_octaves : hint_range(1, 4) = 2;

// Micro detail noise (surface texture)
uniform float micro_scale : hint_range(10.0, 50.0) = 25.0;
uniform float micro_strength : hint_range(0.0, 0.3) = 0.1;

// === BIOME SYSTEM ===
// Biome zones based on terrain height
uniform float mountain_threshold : hint_range(0.3, 0.9) = 0.7;
uniform float lowland_threshold : hint_range(0.1, 0.6) = 0.4;
uniform float biome_blend : hint_range(0.01, 0.2) = 0.05;

// Biome colors
uniform vec3 mountain_color : source_color = vec3(0.6, 0.5, 0.4);
uniform vec3 highland_color : source_color = vec3(0.4, 0.6, 0.3);
uniform vec3 lowland_color : source_color = vec3(0.2, 0.5, 0.3);
uniform vec3 valley_color : source_color = vec3(0.3, 0.4, 0.6);

// === PLANETARY GRADIENT ===
// Core color system - from center to surface
uniform vec3 core_color : source_color = vec3(1.0, 0.8, 0.3);
uniform float core_size : hint_range(0.1, 0.5) = 0.2;

// Additional color variation
uniform float color_variation : hint_range(0.0, 1.0) = 0.3;
uniform vec3 variation_tint : source_color = vec3(0.2, 0.5, 0.8);

// === NOISE FUNCTIONS ===
// Hash function for better random distribution
vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Improved noise function using gradients (similar to Perlin noise)
float improved_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Get gradient vectors for each corner
    vec2 ga = hash22(i + vec2(0.0, 0.0));
    vec2 gb = hash22(i + vec2(1.0, 0.0));
    vec2 gc = hash22(i + vec2(0.0, 1.0));
    vec2 gd = hash22(i + vec2(1.0, 1.0));
    
    // Calculate dot products with distance vectors
    float va = dot(ga, f - vec2(0.0, 0.0));
    float vb = dot(gb, f - vec2(1.0, 0.0));
    float vc = dot(gc, f - vec2(0.0, 1.0));
    float vd = dot(gd, f - vec2(1.0, 1.0));
    
    // Smooth interpolation (quintic for better results)
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    
    // Bilinear interpolation
    return mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
}

// Smooth noise interpolation using the improved noise
float smooth_noise(vec2 p) {
    return improved_noise(p) * 0.5 + 0.5; // Remap from [-1,1] to [0,1]
}

// Fractal noise with multiple octaves
float fractal_noise(vec2 p, float octaves, float persistence) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;
    
    for (int i = 0; i < int(octaves); i++) {
        value += smooth_noise(p * frequency) * amplitude;
        max_value += amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
    }
    
    return value / max_value;
}

// === MAIN SHADER FUNCTION ===
void fragment() {
    // Get UV coordinates centered around (0.5, 0.5)
    vec2 uv = UV - 0.5;
    
    // Calculate distance from center
    float distance = length(uv);
    
    // Create circular planet mask with soft edges
    float planet_mask = 1.0 - smoothstep(planet_radius - edge_softness, planet_radius, distance);
    
    // === TERRAIN GENERATION ===
    // Generate primary terrain (large features like continents)
    vec2 terrain_uv = uv * terrain_scale;
    float primary_terrain = fractal_noise(terrain_uv, terrain_octaves, terrain_persistence);
    
    // Generate secondary detail (medium features like hills)
    vec2 detail_uv = uv * detail_scale;
    float secondary_detail = fractal_noise(detail_uv, detail_octaves, 0.5);
    
    // Generate micro detail (fine surface texture)
    vec2 micro_uv = uv * micro_scale;
    float micro_detail = fractal_noise(micro_uv, 2.0, 0.4);
    
    // Combine all terrain layers
    float terrain_height = primary_terrain * terrain_strength +
                          secondary_detail * detail_strength +
                          micro_detail * micro_strength;
    
    // Apply radial falloff to make terrain fade toward edges
    float radial_gradient = distance / planet_radius;
    radial_gradient = clamp(radial_gradient, 0.0, 1.0);
    
    // Modify terrain based on distance from center
    float surface_terrain = terrain_height * (1.0 - radial_gradient * 0.5);
    
    // === BIOME SYSTEM ===
    // Determine biome based on terrain height
    vec3 biome_color;
    
    if (surface_terrain > mountain_threshold) {
        // Mountain regions
        float mountain_blend = smoothstep(mountain_threshold - biome_blend, 
                                        mountain_threshold + biome_blend, surface_terrain);
        biome_color = mix(highland_color, mountain_color, mountain_blend);
    } else if (surface_terrain > lowland_threshold) {
        // Highland regions
        float highland_blend = smoothstep(lowland_threshold - biome_blend, 
                                        lowland_threshold + biome_blend, surface_terrain);
        biome_color = mix(lowland_color, highland_color, highland_blend);
    } else {
        // Lowland and valley regions
        float valley_blend = smoothstep(0.0, lowland_threshold, surface_terrain);
        biome_color = mix(valley_color, lowland_color, valley_blend);
    }
    
    // === PLANETARY CORE GRADIENT ===
    // Create core glow effect
    float core_influence = 1.0 - smoothstep(0.0, core_size, radial_gradient);
    vec3 core_glow = core_color * core_influence;
    
    // Blend core with surface biomes
    vec3 base_color = mix(biome_color, core_glow, core_influence * 0.3);
    
    // === COLOR VARIATION ===
    // Add subtle color variation using different noise
    float variation_noise = fractal_noise(uv * 4.0, 3.0, 0.6);
    vec3 varied_color = mix(base_color, base_color * variation_tint, 
                           variation_noise * color_variation);
    
    // Apply planet mask to create final color
    vec3 final_color = varied_color * planet_mask;
    
    // Set output color with alpha for transparency
    COLOR = vec4(final_color, planet_mask);
}