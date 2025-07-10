shader_type canvas_item;

// === PLANET PARAMETERS ===
// Basic shape and size
uniform float planet_radius : hint_range(0.1, 0.5) = 0.4;
uniform float edge_softness : hint_range(0.0, 0.1) = 0.02;

// Core color system - from center to surface
uniform vec3 core_color : source_color = vec3(1.0, 0.8, 0.3);
uniform vec3 mid_color : source_color = vec3(0.8, 0.6, 0.4);
uniform vec3 surface_color : source_color = vec3(0.4, 0.7, 0.3);

// Noise parameters for surface variation
uniform float noise_scale : hint_range(0.1, 100.0) = 3.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.5;
uniform float noise_octaves : hint_range(1, 10) = 3;
uniform float noise_persistence : hint_range(0.1, 0.9) = 0.5;

// Color variation controls
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
    
    // Generate noise for surface variation
    vec2 noise_uv = uv * noise_scale;
    float surface_noise = fractal_noise(noise_uv, noise_octaves, noise_persistence);
    
    // Create radial gradient from core to surface
    float radial_gradient = distance / planet_radius;
    radial_gradient = clamp(radial_gradient, 0.0, 1.0);
    
    // Apply noise to the gradient for surface variation
    float modified_gradient = radial_gradient + (surface_noise - 0.5) * noise_strength;
    modified_gradient = clamp(modified_gradient, 0.0, 1.0);
    
    // Create base color using three-point gradient
    vec3 base_color;
    if (modified_gradient < 0.5) {
        // Blend from core to mid color
        base_color = mix(core_color, mid_color, modified_gradient * 2.0);
    } else {
        // Blend from mid to surface color
        base_color = mix(mid_color, surface_color, (modified_gradient - 0.5) * 2.0);
    }
    
    // Add color variation using noise
    float variation_noise = fractal_noise(noise_uv * 0.5, 2.0, 0.6);
    vec3 varied_color = mix(base_color, base_color * variation_tint, 
                           variation_noise * color_variation);
    
    // Apply planet mask to create final color
    vec3 final_color = varied_color * planet_mask;
    
    // Set output color with alpha for transparency
    COLOR = vec4(final_color, planet_mask);
}