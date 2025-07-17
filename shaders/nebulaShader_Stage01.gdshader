shader_type canvas_item;

// Basic parameters for Stage 1
uniform float scale : hint_range(0.1, 10.0) = 2.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform vec4 base_color : source_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.3;
uniform float overall_shape : hint_range(0.1, 2.0) = 1.0;

// Better noise function using gradients (eliminates grid artifacts)
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

// Fractal Brownian Motion (FBM) for more organic clouds
float fbm(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    // 3 octaves for Stage 1 (we'll expand this later)
    for (int i = 0; i < 3; i++) {
        value += amplitude * noise(uv * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    // Normalize from [-1, 1] to [0, 1]
    return value * 0.5 + 0.5;
}

// Create a circular mask with soft edges
float create_mask(vec2 uv, float shape_param, float softness) {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    
    // Create an elliptical shape that can be adjusted
    float mask_radius = 0.4 * shape_param;
    return 1.0 - smoothstep(mask_radius - softness, mask_radius + softness, dist);
}

void fragment() {
    vec2 uv = UV;
    
    // Create the overall mask first
    float mask = create_mask(uv, overall_shape, edge_softness);
    
    // Scale the UV coordinates for noise
    vec2 noise_uv = uv * scale;
    
    // Generate the base noise pattern
    float noise_value = fbm(noise_uv);
    
    // Apply density threshold to create cloud-like appearance
    float cloud_mask = smoothstep(density - 0.1, density + 0.1, noise_value);
    
    // Combine with overall mask
    float final_alpha = cloud_mask * intensity * mask;
    
    // Create the final color
    vec3 final_color = base_color.rgb * brightness * final_alpha;
    
    // Output with alpha blending
    COLOR = vec4(final_color, final_alpha);
}