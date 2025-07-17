shader_type canvas_item;

// Stage 2: Multi-color parameters
uniform float scale : hint_range(0.1, 10.0) = 2.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.3;
uniform float overall_shape : hint_range(0.1, 2.0) = 1.0;

// Shape warping parameters
uniform float warp_strength : hint_range(0.0, 2.0) = 0.5;
uniform float warp_scale : hint_range(0.1, 5.0) = 1.0;

// Multi-color system
uniform vec4 color_1 : source_color = vec4(0.1, 0.2, 0.8, 1.0);  // Deep blue
uniform vec4 color_2 : source_color = vec4(0.6, 0.2, 0.8, 1.0);  // Purple
uniform vec4 color_3 : source_color = vec4(0.8, 0.4, 0.2, 1.0);  // Orange
uniform vec4 color_4 : source_color = vec4(0.2, 0.8, 0.6, 1.0);  // Cyan

// Color mixing controls
uniform float color_mix_1 : hint_range(0.0, 1.0) = 0.8;
uniform float color_mix_2 : hint_range(0.0, 1.0) = 0.6;
uniform float color_mix_3 : hint_range(0.0, 1.0) = 0.4;
uniform float color_mix_4 : hint_range(0.0, 1.0) = 0.2;

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

// Create a warped mask with organic shape
float create_warped_mask(vec2 uv, float shape_param, float softness, float warp_str, float warp_sc) {
    vec2 center = vec2(0.5, 0.5);
    vec2 centered_uv = uv - center;
    
    // Create warp displacement using noise
    vec2 warp_offset = vec2(
        noise(uv * warp_sc) * warp_str,
        noise(uv * warp_sc + vec2(100.0, 200.0)) * warp_str
    );
    
    // Apply warp to the distance calculation
    vec2 warped_pos = centered_uv + warp_offset * 0.1;
    float dist = length(warped_pos);
    
    // Create an organic shape that can be adjusted
    float mask_radius = 0.4 * shape_param;
    return 1.0 - smoothstep(mask_radius - softness, mask_radius + softness, dist);
}

// Multi-color mixing based on noise values with smooth gradients
vec3 mix_colors(float noise_val, float density_mask, vec2 uv) {
    // Use different noise patterns for color distribution
    float color_noise1 = noise_val;
    float color_noise2 = fbm(uv * scale * 0.7 + vec2(50.0, 30.0)) * 0.5 + 0.5;
    float color_noise3 = fbm(uv * scale * 1.3 + vec2(100.0, 200.0)) * 0.5 + 0.5;
    
    // Create smooth gradient weights for each color
    // These create overlapping zones where colors blend naturally
    float weight1 = color_mix_1 * exp(-2.0 * pow(color_noise1 - 0.2, 2.0));
    float weight2 = color_mix_2 * exp(-2.0 * pow(color_noise2 - 0.4, 2.0));
    float weight3 = color_mix_3 * exp(-2.0 * pow(color_noise3 - 0.6, 2.0));
    float weight4 = color_mix_4 * exp(-2.0 * pow(color_noise1 - 0.8, 2.0));
    
    // Add some cross-influence between noise patterns
    weight1 += color_mix_1 * 0.3 * exp(-3.0 * pow(color_noise2 - 0.1, 2.0));
    weight2 += color_mix_2 * 0.3 * exp(-3.0 * pow(color_noise3 - 0.3, 2.0));
    weight3 += color_mix_3 * 0.3 * exp(-3.0 * pow(color_noise1 - 0.5, 2.0));
    weight4 += color_mix_4 * 0.3 * exp(-3.0 * pow(color_noise2 - 0.7, 2.0));
    
    // Normalize weights to ensure smooth blending
    float total_weight = weight1 + weight2 + weight3 + weight4 + 0.001; // Small epsilon to avoid division by zero
    
    // Mix colors with normalized weights
    vec3 final_color = (color_1.rgb * weight1 + 
                       color_2.rgb * weight2 + 
                       color_3.rgb * weight3 + 
                       color_4.rgb * weight4) / total_weight;
    
    // Apply density influence to make colors more intense in dense areas
    final_color = mix(final_color * 0.3, final_color, density_mask);
    
    return final_color;
}

void fragment() {
    vec2 uv = UV;
    
    // Create the warped mask
    float mask = create_warped_mask(uv, overall_shape, edge_softness, warp_strength, warp_scale);
    
    // Scale the UV coordinates for noise
    vec2 noise_uv = uv * scale;
    
    // Generate the base noise pattern
    float noise_value = fbm(noise_uv);
    
    // Apply density threshold to create cloud-like appearance
    float cloud_mask = smoothstep(density - 0.1, density + 0.1, noise_value);
    
    // Mix colors based on noise patterns
    vec3 final_color = mix_colors(noise_value, cloud_mask, uv);
    
    // Combine with overall mask and apply brightness
    float final_alpha = cloud_mask * intensity * mask;
    final_color *= brightness * final_alpha;
    
    // Output with alpha blending
    COLOR = vec4(final_color, final_alpha);
}