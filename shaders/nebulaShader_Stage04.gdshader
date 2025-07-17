shader_type canvas_item;

// Basic parameters
uniform float scale : hint_range(0.1, 20.0) = 2.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

// UV transformation controls (applied to noise, not final shape)
uniform float uv_offset_x : hint_range(-2.0, 2.0) = 0.0;
uniform float uv_offset_y : hint_range(-2.0, 2.0) = 0.0;
uniform float uv_rotation : hint_range(-3.14159, 3.14159) = 0.0;

// Enhanced noise parameters
uniform float octaves : hint_range(1.0, 20.0) = 4.0;
uniform float lacunarity : hint_range(1.0, 4.0) = 2.0;
uniform float gain : hint_range(0.1, 0.9) = 0.5;
uniform float noise_strength : hint_range(0.1, 10.0) = 1.0;

// Detail layers
uniform float detail_scale : hint_range(0.1, 10.0) = 4.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.3;
uniform float fine_detail_scale : hint_range(0.1, 20.0) = 8.0;
uniform float fine_detail_strength : hint_range(0.0, 1.0) = 0.15;

// Billow noise for internal detail
uniform float billow_scale : hint_range(0.1, 20.0) = 6.0;
uniform float billow_strength : hint_range(0.0, 2.0) = 0.4;
uniform float billow_octaves : hint_range(1.0, 6.0) = 3.0;

// Overall shape with organic edge
uniform float overall_shape : hint_range(0.1, 2.0) = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.3;
uniform float edge_noise_scale : hint_range(0.1, 100.0) = 3.0;
uniform float edge_noise_strength : hint_range(0.0, 1.0) = 0.2;
uniform float edge_octaves : hint_range(1.0, 6.0) = 3.0;

// Gradient system
uniform int gradient_type : hint_range(0, 2) = 0; // 0=radial, 1=linear, 2=noise-based
uniform float gradient_center_x : hint_range(0.0, 1.0) = 0.5;
uniform float gradient_center_y : hint_range(0.0, 1.0) = 0.5;
uniform float gradient_angle : hint_range(-3.14159, 3.14159) = 0.0;
uniform float gradient_scale : hint_range(0.1, 3.0) = 1.0;
uniform float gradient_warp_strength : hint_range(0.0, 2.0) = 0.3;
uniform float gradient_warp_scale : hint_range(0.1, 5.0) = 2.0;

// Color stops for gradient
uniform vec4 color_1 : source_color = vec4(0.1, 0.2, 0.8, 1.0);  // Deep blue
uniform vec4 color_2 : source_color = vec4(0.6, 0.2, 0.8, 1.0);  // Purple
uniform vec4 color_3 : source_color = vec4(0.8, 0.4, 0.2, 1.0);  // Orange
uniform vec4 color_4 : source_color = vec4(0.9, 0.8, 0.4, 1.0);  // Yellow

// Color remapping options
uniform float contrast : hint_range(0.1, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float color_temperature : hint_range(-1.0, 1.0) = 0.0;

// Better noise function using gradients
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

// Billow noise (ridged turbulence)
float billow_noise(vec2 p) {
    return abs(noise(p));
}

// UV transformation functions
vec2 rotate_uv(vec2 uv, float rotation) {
    float cos_r = cos(rotation);
    float sin_r = sin(rotation);
    vec2 centered = uv - 0.5;
    return vec2(
        centered.x * cos_r - centered.y * sin_r,
        centered.x * sin_r + centered.y * cos_r
    ) + 0.5;
}

vec2 transform_uv(vec2 uv) {
    vec2 rotated = rotate_uv(uv, uv_rotation);
    return rotated + vec2(uv_offset_x, uv_offset_y);
}

// Enhanced Fractal Brownian Motion
float fbm_enhanced(vec2 uv, float oct, float lac, float g, float strength) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    int max_octaves = int(oct);
    for (int i = 0; i < max_octaves; i++) {
        value += amplitude * noise(uv * frequency);
        amplitude *= g;
        frequency *= lac;
    }
    
    return (value * 0.5 + 0.5) * strength;
}

// Billow FBM for internal detail
float fbm_billow(vec2 uv, float oct, float lac, float g, float strength) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    int max_octaves = int(oct);
    for (int i = 0; i < max_octaves; i++) {
        value += amplitude * billow_noise(uv * frequency);
        amplitude *= g;
        frequency *= lac;
    }
    
    return (value * 0.5 + 0.5) * strength;
}

// Multi-layered noise for enhanced detail
float multi_layer_noise(vec2 uv) {
    // Base layer
    float base = fbm_enhanced(uv, octaves, lacunarity, gain, noise_strength);
    
    // Detail layer
    float detail = fbm_enhanced(uv * detail_scale, max(octaves - 2.0, 1.0), lacunarity, gain, detail_strength);
    
    // Fine detail layer
    float fine_detail = fbm_enhanced(uv * fine_detail_scale, max(octaves - 3.0, 1.0), lacunarity * 1.5, gain * 0.8, fine_detail_strength);
    
    // Billow layer for internal structure
    float billow = fbm_billow(uv * billow_scale, billow_octaves, lacunarity, gain, billow_strength);
    
    // Combine layers
    return base + detail * base + fine_detail * base * detail + billow * base;
}

// Create gradient value based on type
float create_gradient(vec2 uv) {
    vec2 center = vec2(gradient_center_x, gradient_center_y);
    float gradient_val = 0.0;
    
    // Add warp to gradient
    vec2 warp_offset = vec2(
        noise(uv * gradient_warp_scale) * gradient_warp_strength,
        noise(uv * gradient_warp_scale + vec2(100.0, 200.0)) * gradient_warp_strength
    );
    vec2 warped_uv = uv + warp_offset * 0.1;
    
    if (gradient_type == 0) {
        // Radial gradient
        gradient_val = distance(warped_uv, center) * gradient_scale;
    } else if (gradient_type == 1) {
        // Linear gradient
        vec2 dir = vec2(cos(gradient_angle), sin(gradient_angle));
        gradient_val = dot(warped_uv - center, dir) * gradient_scale + 0.5;
    } else {
        // Noise-based gradient
        gradient_val = fbm_enhanced(warped_uv * gradient_scale, 3.0, 2.0, 0.5, 1.0);
    }
    
    return clamp(gradient_val, 0.0, 1.0);
}

// Color mixing based on gradient
vec3 mix_gradient_colors(float gradient_val, float noise_influence) {
    // Modify gradient with noise for more organic color distribution
    float modified_gradient = gradient_val + noise_influence * 0.3;
    modified_gradient = clamp(modified_gradient, 0.0, 1.0);
    
    vec3 final_color;
    if (modified_gradient < 0.33) {
        // Blend between color_1 and color_2
        float t = modified_gradient * 3.0;
        final_color = mix(color_1.rgb, color_2.rgb, t);
    } else if (modified_gradient < 0.66) {
        // Blend between color_2 and color_3
        float t = (modified_gradient - 0.33) * 3.0;
        final_color = mix(color_2.rgb, color_3.rgb, t);
    } else {
        // Blend between color_3 and color_4
        float t = (modified_gradient - 0.66) * 3.0;
        final_color = mix(color_3.rgb, color_4.rgb, t);
    }
    
    return final_color;
}

// RGB to HSV conversion
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Color remapping function
vec3 remap_color(vec3 color) {
    // Apply contrast
    color = (color - 0.5) * contrast + 0.5;
    
    // Convert to HSV for hue and saturation adjustments
    vec3 hsv = rgb2hsv(color);
    
    // Apply hue shift
    hsv.x = fract(hsv.x + hue_shift);
    
    // Apply saturation
    hsv.y *= saturation;
    
    // Convert back to RGB
    color = hsv2rgb(hsv);
    
    // Apply color temperature (simple approximation)
    if (color_temperature > 0.0) {
        // Warmer
        color.r = mix(color.r, color.r * 1.2, color_temperature);
        color.b = mix(color.b, color.b * 0.8, color_temperature);
    } else {
        // Cooler
        color.r = mix(color.r, color.r * 0.8, -color_temperature);
        color.b = mix(color.b, color.b * 1.2, -color_temperature);
    }
    
    return clamp(color, 0.0, 1.0);
}

// Create organic edge mask (applied last)
float create_organic_edge_mask(vec2 uv) {
    vec2 center = vec2(0.5, 0.5);
    vec2 centered_uv = uv - center;
    
    // Create noise-based edge distortion
    float edge_noise = fbm_enhanced(uv * edge_noise_scale, edge_octaves, 2.0, 0.5, edge_noise_strength);
    
    // Apply edge distortion
    float dist = length(centered_uv);
    float mask_radius = 0.4 * overall_shape + edge_noise * 0.1;
    
    return 1.0 - smoothstep(mask_radius - edge_softness, mask_radius + edge_softness, dist);
}

void fragment() {
    vec2 original_uv = UV;
    vec2 transformed_uv = transform_uv(UV);
    
    // Generate enhanced multi-layer noise pattern (using transformed UV)
    vec2 noise_uv = transformed_uv * scale;
    float noise_value = multi_layer_noise(noise_uv);
    
    // Apply density threshold to create cloud-like appearance
    float cloud_mask = smoothstep(density - 0.1, density + 0.1, noise_value);
    
    // Create gradient for color mixing (using original UV)
    float gradient_val = create_gradient(original_uv);
    
    // Mix colors based on gradient and noise
    vec3 final_color = mix_gradient_colors(gradient_val, noise_value - 0.5);
    
    // Apply color remapping
    final_color = remap_color(final_color);
    
    // Apply the organic edge mask last (using original UV)
    float edge_mask = create_organic_edge_mask(original_uv);
    
    // Combine everything
    float final_alpha = cloud_mask * intensity * edge_mask;
    final_color *= brightness * final_alpha;
    
    // Output with alpha blending
    COLOR = vec4(final_color, final_alpha);
}