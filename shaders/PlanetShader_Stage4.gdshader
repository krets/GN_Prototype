shader_type canvas_item;

// === PLANET PARAMETERS ===
// Basic shape and size
uniform float planet_radius : hint_range(0.1, 0.5) = 0.4;
uniform float edge_softness : hint_range(0.0, 0.1) = 0.02;

// === SPHERE WARPING ===
// Spherical distortion to simulate 3D curvature
uniform float sphere_strength : hint_range(-20.0, 20.0) = 1.0;

// === CONTINENTAL SYSTEM ===
// Continental generation
uniform float continent_scale : hint_range(0.3, 10.0) = 1.2;
uniform float continent_threshold : hint_range(0.0, 0.8) = 0.4;
uniform float continent_sharpness : hint_range(0.01, 0.3) = 0.1;
uniform float ocean_depth : hint_range(0.0, 0.5) = 0.2;

// Domain warping for realistic coastlines
uniform float warp_strength : hint_range(0.0, 0.5) = 0.15;
uniform float warp_scale : hint_range(1.0, 8.0) = 3.0;

// === TERRAIN SYSTEM ===
// Primary terrain noise (large features)
uniform float terrain_scale : hint_range(0.5, 8.0) = 2.0;
uniform float terrain_strength : hint_range(0.0, 1.0) = 0.6;
uniform float terrain_octaves : hint_range(1, 6) = 4;
uniform float terrain_persistence : hint_range(0.1, 0.9) = 0.5;

// Secondary detail noise (fine features)
uniform float detail_scale : hint_range(2.0, 20.0) = 8.0;
uniform float detail_strength : hint_range(0.0, 0.5) = 0.2;
uniform float detail_octaves : hint_range(1, 4) = 2;

// === GEOGRAPHIC FEATURES ===
// River system
uniform float river_scale : hint_range(2.0, 15.0) = 6.0;
uniform float river_strength : hint_range(0.0, 2) = 0.1;
uniform float river_width : hint_range(0.01, 0.1) = 0.03;

// Polar ice caps
uniform float ice_cap_size : hint_range(0.0, 0.4) = 0.15;
uniform float ice_cap_softness : hint_range(0.01, 0.2) = 0.05;

// Desert zones
uniform float desert_latitude : hint_range(0.1, 0.8) = 0.4;
uniform float desert_width : hint_range(0.05, 0.3) = 0.15;
uniform float desert_intensity : hint_range(0.0, 1.0) = 0.7;

// === MATERIAL COLORS ===
// Ocean and water
uniform vec3 deep_ocean_color : source_color = vec3(0.1, 0.2, 0.4);
uniform vec3 shallow_water_color : source_color = vec3(0.2, 0.4, 0.6);
uniform vec3 river_color : source_color = vec3(0.3, 0.5, 0.7);

// Land biomes
uniform vec3 mountain_color : source_color = vec3(0.5, 0.4, 0.3);
uniform vec3 highland_color : source_color = vec3(0.3, 0.5, 0.2);
uniform vec3 lowland_color : source_color = vec3(0.2, 0.6, 0.3);
uniform vec3 desert_color : source_color = vec3(0.8, 0.6, 0.3);
uniform vec3 ice_color : source_color = vec3(0.9, 0.95, 1.0);

// Coastal transitions
uniform float coastal_blend : hint_range(0.01, 0.1) = 0.03;
uniform vec3 beach_color : source_color = vec3(0.7, 0.6, 0.4);

// === PLANETARY GRADIENT ===
// Core color system
uniform vec3 core_color : source_color = vec3(1.0, 0.8, 0.3);
uniform float core_size : hint_range(0.1, 0.5) = 0.2;

// Additional color variation
uniform float color_variation : hint_range(0.0, 1.0) = 0.2;
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

// Domain warping function for realistic coastlines
vec2 domain_warp(vec2 p, float strength, float scale) {
    float warp_x = fractal_noise(p * scale, 3.0, 0.5);
    float warp_y = fractal_noise(p * scale + vec2(100.0, 100.0), 3.0, 0.5);
    return p + vec2(warp_x, warp_y) * strength;
}

// Flow noise for river generation
float flow_noise(vec2 p, float scale) {
    // Create flow field using multiple noise octaves
    vec2 flow_p = p * scale;
    float n1 = fractal_noise(flow_p, 2.0, 0.5);
    float n2 = fractal_noise(flow_p + vec2(100.0, 50.0), 2.0, 0.5);
    
    // Create ridged noise for river valleys
    float ridge = abs(n1 - 0.5) * 2.0;
    ridge = 1.0 - ridge;
    ridge = pow(ridge, 3.0); // Sharpen the ridges
    
    return ridge;
}

// Proper sphere warping function
vec2 sphere_warp(vec2 uv, float strength) {
    // Calculate distance from center
    float dist = length(uv);
    
    // Only apply warping within the planet radius
    if (dist > planet_radius) {
        return uv;
    }
    
    // Calculate the Z coordinate on the sphere
    float z = sqrt(max(0.0, planet_radius * planet_radius - dist * dist));
    
    // Project back to 2D with perspective scaling
    float scale_factor = mix(1.0, z / planet_radius, strength);
    
    return uv * scale_factor;
}

// === MAIN SHADER FUNCTION ===
void fragment() {
    // Get UV coordinates centered around (0.5, 0.5)
    vec2 original_uv = UV - 0.5;
    
    // Calculate original distance for planet mask
    float original_distance = length(original_uv);
    
    // Apply sphere warping for 3D effect
    vec2 uv = sphere_warp(original_uv, sphere_strength);
    
    // Calculate distance from center and angle for polar features
    float distance = length(uv);
    float angle = atan(uv.y, uv.x);
    
    // Create circular planet mask with soft edges (use original distance)
    float planet_mask = 1.0 - smoothstep(planet_radius - edge_softness, planet_radius, original_distance);
    
    // === CONTINENTAL GENERATION ===
    // Apply domain warping for realistic coastlines
    vec2 warped_uv = domain_warp(uv, warp_strength, warp_scale);
    
    // Generate continental base using warped coordinates
    float continent_noise = fractal_noise(warped_uv * continent_scale, 4.0, 0.6);
    
    // Create sharp continent/ocean boundaries
    float continent_mask = smoothstep(continent_threshold - continent_sharpness, 
                                    continent_threshold + continent_sharpness, 
                                    continent_noise);
    
    // === TERRAIN GENERATION ===
    // Generate primary terrain (only on land)
    vec2 terrain_uv = warped_uv * terrain_scale;
    float primary_terrain = fractal_noise(terrain_uv, terrain_octaves, terrain_persistence);
    
    // Generate secondary detail
    vec2 detail_uv = warped_uv * detail_scale;
    float secondary_detail = fractal_noise(detail_uv, detail_octaves, 0.5);
    
    // Combine terrain layers (only affect land areas)
    float land_terrain = primary_terrain * terrain_strength + 
                        secondary_detail * detail_strength;
    land_terrain *= continent_mask; // Only on continents
    
    // === RIVER SYSTEM ===
    // Generate rivers using flow noise
    float river_noise = flow_noise(warped_uv, river_scale);
    float river_mask = smoothstep(1.0 - river_width, 1.0, river_noise);
    river_mask *= continent_mask; // Rivers only on land
    river_mask *= river_strength;
    
    // === POLAR ICE CAPS ===
    // Calculate latitude-based ice caps (use original UV for proper poles)
    float latitude = abs(original_uv.y) / planet_radius;
    float ice_cap_mask = smoothstep(1.0 - ice_cap_size - ice_cap_softness, 
                                   1.0 - ice_cap_size + ice_cap_softness, 
                                   latitude);
    
    // === DESERT ZONES ===
    // Create desert bands at specific latitudes (use original UV)
    float desert_lat = abs(original_uv.y) / planet_radius;
    float desert_mask = 1.0 - smoothstep(desert_latitude - desert_width, 
                                        desert_latitude + desert_width, 
                                        abs(desert_lat - desert_latitude));
    desert_mask *= continent_mask; // Deserts only on land
    desert_mask *= desert_intensity;
    
    // === OCEAN DEPTH CALCULATION ===
    // Create ocean depth variation
    float ocean_depth_noise = fractal_noise(uv * 2.0, 3.0, 0.5);
    float ocean_depth_factor = (1.0 - continent_mask) * (ocean_depth_noise * ocean_depth + ocean_depth);
    
    // === COLOR ASSIGNMENT ===
    vec3 final_color;
    
    if (continent_mask > 0.5) {
        // LAND AREAS
        vec3 land_color;
        
        // Determine base land color based on terrain height
        if (land_terrain > 0.6) {
            land_color = mountain_color;
        } else if (land_terrain > 0.3) {
            land_color = highland_color;
        } else {
            land_color = lowland_color;
        }
        
        // Apply desert coloring
        land_color = mix(land_color, desert_color, desert_mask);
        
        // Apply ice cap coloring
        land_color = mix(land_color, ice_color, ice_cap_mask);
        
        // Add coastal beaches near water
        float coast_distance = smoothstep(continent_threshold - coastal_blend, 
                                        continent_threshold, continent_noise);
        land_color = mix(beach_color, land_color, coast_distance);
        
        final_color = land_color;
        
    } else {
        // OCEAN AREAS
        vec3 ocean_color = mix(deep_ocean_color, shallow_water_color, 
                              1.0 - ocean_depth_factor);
        
        // Apply ice cap coloring to ocean (sea ice)
        ocean_color = mix(ocean_color, ice_color, ice_cap_mask * 0.7);
        
        final_color = ocean_color;
    }
    
    // === RIVERS ===
    // Apply river coloring on top of land
    final_color = mix(final_color, river_color, river_mask);
    
    // === PLANETARY CORE GRADIENT ===
    // Create core glow effect
    float radial_gradient = distance / planet_radius;
    float core_influence = 1.0 - smoothstep(0.0, core_size, radial_gradient);
    vec3 core_glow = core_color * core_influence;
    
    // Blend core with surface features (subtle effect)
    final_color = mix(final_color, core_glow, core_influence * 0.2);
    
    // === COLOR VARIATION ===
    // Add subtle color variation
    float variation_noise = fractal_noise(uv * 4.0, 3.0, 0.6);
    final_color = mix(final_color, final_color * variation_tint, 
                     variation_noise * color_variation);
    
    // Apply planet mask to create final color
    final_color *= planet_mask;
    
    // Set output color with alpha for transparency
    COLOR = vec4(final_color, planet_mask);
}