shader_type canvas_item;

// Expose a gradient texture uniform
uniform sampler2D gradient_tex;

// Expose smoothstep edge params
uniform float edge_start : hint_range(0.0, 1.0) = 0.5; // fade starts at
uniform float edge_end   : hint_range(0.0, 1.0) = 0.25; // fade ends at

void fragment() {
    float dist = length(UV - vec2(0.5));
    float t = clamp(dist / 0.5, 0.0, 1.0); // 0=center, 1=edge
    vec4 grad_color = texture(gradient_tex, vec2(t, 0.0)); // sample the gradient
    
    // Now smoothstep params use uniforms
    float alpha = grad_color.a * smoothstep(edge_start, edge_end, dist);

    COLOR = vec4(grad_color.rgb, alpha);
}