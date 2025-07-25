shader_type canvas_item;

// Shape Controls
uniform float asteroid_size : hint_range(0.1, 1.0) = 0.8;
uniform float edge_smoothness : hint_range(0.001, 0.1) = 0.02;
uniform float shape_distortion : hint_range(0.0, 0.5) = 0.15;
uniform float shape_distortion_scale : hint_range(1.0, 20.0) = 6.0;
uniform vec2 shape_distortion_offset = vec2(0.0);

// Base Color Controls
uniform vec3 base_color : source_color = vec3(0.4, 0.35, 0.3);
uniform float color_variation : hint_range(0.0, 1.0) = 0.3;
uniform vec3 dark_color : source_color = vec3(0.2, 0.15, 0.1);

// Surface Detail Controls
uniform float surface_roughness : hint_range(0.0, 2.0) = 1.0;
uniform float crater_depth : hint_range(0.0, 1.0) = 0.6;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.4;

// Realistic Crater Controls
uniform float crater_density : hint_range(1.0, 20.0) = 8.0;
uniform float crater_size_min : hint_range(0.01, 0.2) = 0.03;
uniform float crater_size_max : hint_range(0.1, 0.5) = 0.15;
uniform float crater_depth_variation : hint_range(0.1, 2.0) = 0.8;
uniform float crater_rim_height : hint_range(0.0, 1.0) = 0.4;
uniform float crater_rim_width : hint_range(0.1, 0.5) = 0.15;
uniform float large_crater_probability : hint_range(0.0, 1.0) = 0.3;
uniform float crater_clustering : hint_range(0.0, 1.0) = 0.6;

// Noise Scale Controls
uniform float large_feature_scale : hint_range(1.0, 20.0) = 4.0;
uniform float medium_detail_scale : hint_range(5.0, 50.0) = 15.0;
uniform float fine_detail_scale : hint_range(10.0, 100.0) = 35.0;

// Noise offset controls
uniform vec2 large_feature_offset = vec2(0.0);
uniform vec2 medium_detail_offset = vec2(0.0);
uniform vec2 fine_detail_offset = vec2(0.0);

// Better hash function for noise
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// Better hash function for crater placement
vec3 hash3(vec2 p) {
    vec3 q = vec3(dot(p, vec2(127.1, 311.7)), 
                  dot(p, vec2(269.5, 183.3)), 
                  dot(p, vec2(419.2, 371.9)));
    return fract(sin(q) * 43758.5453);
}

// Generate individual realistic craters
float generate_craters(vec2 uv, float density, vec2 offset) {
    vec2 grid_uv = (uv + offset) * density;
    vec2 grid_id = floor(grid_uv);
    vec2 grid_pos = fract(grid_uv);
    
    float crater_effect = 0.0;
    
    // Check 3x3 grid around current cell for overlapping craters
    for(int x = -1; x <= 1; x++) {
        for(int y = -1; y <= 1; y++) {
            vec2 neighbor_id = grid_id + vec2(float(x), float(y));
            vec3 crater_data = hash3(neighbor_id);
            
            // Determine if this cell has a crater
            float has_crater = step(0.5, crater_data.x);
            
            if (has_crater > 0.5) {
                // Crater position within its cell (with clustering)
                vec2 cluster_offset = (crater_data.yz - 0.5) * crater_clustering;
                vec2 crater_center = vec2(float(x), float(y)) + 0.5 + cluster_offset;
                
                // Distance from current position to crater center
                float dist = length(grid_pos - crater_center);
                
                // Determine crater size (larger craters are rarer)
                float size_rand = hash3(neighbor_id + vec2(123.4, 567.8)).x;
                float is_large = step(1.0 - large_crater_probability, size_rand);
                float crater_size = mix(crater_size_min, crater_size_max, crater_data.z);
                crater_size *= mix(1.0, 2.5, is_large); // Large craters are bigger
                
                // Crater depth varies with size
                float crater_depth_local = crater_depth_variation * crater_size * (0.5 + crater_data.y * 0.5);
                
                // Rim characteristics
                float rim_start = crater_size * (1.0 - crater_rim_width);
                float rim_end = crater_size * 1.2;
                
                if (dist < rim_end) {
                    if (dist < rim_start) {
                        // Inside crater - create depression
                        float crater_falloff = 1.0 - smoothstep(0.0, rim_start, dist);
                        crater_falloff = pow(crater_falloff, 1.5); // Steeper crater walls
                        crater_effect -= crater_falloff * crater_depth_local;
                    } else {
                        // Crater rim - raised edge
                        float rim_falloff = 1.0 - smoothstep(rim_start, rim_end, dist);
                        rim_falloff = smoothstep(0.0, 1.0, rim_falloff);
                        float rim_height_local = crater_rim_height * crater_size * 0.5;
                        crater_effect += rim_falloff * rim_height_local;
                    }
                }
            }
        }
    }
    
    return crater_effect;
}

// Smooth noise function with gradient vectors
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Quintic interpolation for smoother results
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    
    // Get gradient vectors for each corner
    vec2 ga = hash2(i + vec2(0.0, 0.0)) * 2.0 - 1.0;
    vec2 gb = hash2(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
    vec2 gc = hash2(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
    vec2 gd = hash2(i + vec2(1.0, 1.0)) * 2.0 - 1.0;
    
    // Calculate dot products
    float va = dot(ga, f - vec2(0.0, 0.0));
    float vb = dot(gb, f - vec2(1.0, 0.0));
    float vc = dot(gc, f - vec2(0.0, 1.0));
    float vd = dot(gd, f - vec2(1.0, 1.0));
    
    // Interpolate
    return mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y) * 0.5 + 0.5;
}

// Fractional Brownian Motion (fBm) - layered noise
float fbm(vec2 p, int octaves, float lacunarity, float gain) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        max_value += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }
    
    return value / max_value;
}

// Convert UV to spherical coordinates for 3D mapping (pole-free version)
vec3 uv_to_sphere(vec2 uv) {
    // Center the UV coordinates
    vec2 centered = (uv - 0.5) * 2.0;
    
    // Calculate distance from center
    float dist = length(centered);
    
    // If outside unit circle, return invalid
    if (dist > 1.0) {
        return vec3(0.0, 0.0, -1.0); // Invalid marker
    }
    
    // Calculate sphere coordinates
    float x = centered.x;
    float y = centered.y;
    float z = sqrt(1.0 - dist * dist);
    
    return vec3(x, y, z);
}

// Better texture mapping that reduces pole distortion
vec2 sphere_to_texture(vec3 sphere_pos) {
    // Use a more balanced coordinate system
    // Instead of pure spherical coordinates, use a hybrid approach
    
    // Project onto cube faces first to reduce pole distortion
    vec3 abs_pos = abs(sphere_pos);
    float max_axis = max(abs_pos.x, max(abs_pos.y, abs_pos.z));
    
    vec2 uv;
    if (max_axis == abs_pos.z) {
        // Front/back face
        uv = vec2(sphere_pos.x, sphere_pos.y) / max_axis;
    } else if (max_axis == abs_pos.x) {
        // Left/right face
        uv = vec2(sphere_pos.z * sign(sphere_pos.x), sphere_pos.y) / max_axis;
    } else {
        // Top/bottom face
        uv = vec2(sphere_pos.x, sphere_pos.z * sign(sphere_pos.y)) / max_axis;
    }
    
    // Normalize to 0-1 range and add some variation
    uv = uv * 0.5 + 0.5;
    
    return uv;
}

void fragment() {
    vec2 uv = UV;
    
    // Convert UV to sphere coordinates
    vec3 sphere_pos = uv_to_sphere(uv);
    
    // Initialize default values
    vec3 surface_color = vec3(0.0);
    float alpha = 0.0;
    
    // Check if we're inside the sphere
    if (sphere_pos.z >= 0.0) {
        // Get texture coordinates on the sphere
        vec2 tex_uv = sphere_to_texture(sphere_pos);
        
        // Calculate distance from center for shape distortion
        float center_dist = length((uv - 0.5) * 2.0);
        
        // Generate shape distortion noise with new controls
        float shape_noise = fbm(tex_uv * shape_distortion_scale + shape_distortion_offset, 4, 2.0, 0.5);
        
        // Apply shape distortion to the radius
        float distorted_radius = asteroid_size + (shape_noise - 0.5) * shape_distortion;
        
        // Calculate alpha based on distorted radius
        alpha = 1.0 - smoothstep(distorted_radius - edge_smoothness, distorted_radius + edge_smoothness, center_dist);
        
        // Only calculate surface details if alpha is significant
        if (alpha > 0.01) {
            // Generate realistic craters
            float crater_heights = generate_craters(tex_uv, crater_density, vec2(0.0));
            float small_craters = generate_craters(tex_uv, crater_density * 2.5, vec2(123.45, 678.90)) * 0.4;
            
            // Generate surface detail using spherical coordinates
            float large_features = fbm(tex_uv * large_feature_scale + large_feature_offset, 4, 2.0, 0.5);
            float medium_details = fbm(tex_uv * medium_detail_scale + medium_detail_offset, 5, 2.0, 0.4);
            float fine_details = fbm(tex_uv * fine_detail_scale + fine_detail_offset, 6, 2.0, 0.3);
            
            // Combine surface features - start with base noise
            float surface_height = large_features * 0.4; // Reduced to make room for craters
            surface_height += (medium_details - 0.5) * surface_roughness * 0.25;
            surface_height += (fine_details - 0.5) * detail_strength * 0.15;
            
            // Add realistic craters on top
            surface_height += crater_heights;
            surface_height += small_craters;
            
            // Legacy crater effect (much reduced)
            float legacy_crater_mask = 1.0 - smoothstep(0.3, 0.7, large_features);
            legacy_crater_mask = pow(legacy_crater_mask, 2.0);
            surface_height -= legacy_crater_mask * crater_depth * 0.1; // Much smaller effect
            
            // Clamp surface height
            surface_height = clamp(surface_height, 0.0, 1.0);
            
            // Calculate basic lighting based on sphere normal
            vec3 normal = normalize(sphere_pos);
            vec3 light_dir = normalize(vec3(0.5, 0.5, 1.0));
            float light_intensity = max(0.3, dot(normal, light_dir));
            
            // Create color variation based on surface height and lighting
            surface_color = mix(dark_color, base_color, surface_height);
            
            // Add color variation noise
            float color_noise = fbm(tex_uv * 12.0, 3, 2.0, 0.6);
            surface_color = mix(surface_color, base_color, color_noise * color_variation);
            
            // Apply lighting
            surface_color *= light_intensity;
            
            // Basic contrast adjustment
            surface_color = pow(surface_color, vec3(0.9));
        }
    }
    
    COLOR = vec4(surface_color, alpha);
}