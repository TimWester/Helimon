shader_type canvas_item;

uniform float threshold : hint_range(0.0, 0.2) = 0.08;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	// Treat near-black pixels as transparent so sprite-sheet backgrounds drop out
	if (color.r <= threshold && color.g <= threshold && color.b <= threshold) {
		color.a = 0.0;
	}
	COLOR = color;
}
