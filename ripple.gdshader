shader_type canvas_item;

uniform vec2 screen_size = vec2(720.0, 1280.0);
uniform vec2 pos1;
uniform vec2 vel1;
uniform float energy1 = 0.0;
uniform vec2 pos2;
uniform vec2 vel2;
uniform float energy2 = 0.0;
// Touch points: pos3/energy3 = Player 1's finger, pos4/energy4 = Player 2's finger
uniform vec2 pos3;
uniform float energy3 = 0.0;
uniform vec2 pos4;
uniform float energy4 = 0.0;
uniform vec4 color1 : source_color = vec4(0.18, 0.83, 0.45, 1.0);
uniform vec4 color2 : source_color = vec4(0.12, 0.56, 1.0, 1.0);
uniform float strength = 1.0;

// Puck: pos5/vel5/energy5, tinted with color3 (the puck's color)
uniform vec2 pos5;
uniform vec2 vel5;
uniform float energy5 = 0.0;
uniform vec4 color3 : source_color = vec4(0.46, 0.0, 1.0, 1.0);

const float PUCK_REACH = 350.0;    // how far the effect spreads from the puck

// Ripple knobs (unchanged)
const float WAVE_LENGTH = 118.0;
const float WAVE_SPEED = 2.0;
const float REACH = 350.0;
const float TOUCH_REACH = 350.0;
const float LINE_LEVELS = 4.0;
const float LINE_THICKNESS = 0.01;
const float LINE_OPACITY = 0.6;

// Trippy knobs
const float FLOW_SCALE = 50.0;    // px size of the cloud swirls (bigger = larger, lazier clouds)
const float FLOW_SPEED = 0.2;     // how fast the clouds drift and boil
const float WARP_AMOUNT = 3.0;     // how hard the clouds twist into themselves (0 = calm)
const float BAND_DENSITY = 38.0;   // how many color bands the clouds are sliced into
const float CLOUD_OPACITY = 0.75;  // how solid the cloud bands are (the contour lines are separate)
const float HUE_SPEED = 0.00;      // how fast the rainbow rotates
const float RAINBOW_MIX = 0.0;     // 0 = players' colors only, 1 = full rainbow
const float RIPPLE_WARP = 0.72;    // how much the ripples bend the clouds
const float BREATHE = 0.55;        // slow zoom in and out (0 = off)

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Three layers of noise at doubling detail = a cloud
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

// Rainbow palette: t cycles through the whole spectrum every 1.0
vec3 pal(float t) {
	return 0.5 + 0.5 * cos(6.2831853 * (vec3(0.0, 0.33, 0.67) + t));
}

// Height of one source's ripple at point p. 'env' returns how strong that source's influence is there.
float ring(vec2 p, vec2 m, vec2 v, float e, float reach, out float env) {
	vec2 d = p - m;
	float dist = length(d);
	float speed = length(v);
	float along = (speed > 1.0) ? dot(d, v / speed) : 0.0;
	float squash = clamp(speed / 2500.0, 0.0, 1.0);
	float warped = dist + along * squash * 0.4;
	env = e * exp(-(dist * dist) / (reach * reach));
	return env * cos(warped * 6.2831853 / WAVE_LENGTH - TIME * WAVE_SPEED);
}

void fragment() {
	vec2 p = UV * screen_size;
	float env1;
	float env2;
	float env3;
	float env4;
	float env5;
	float h = ring(p, pos1, vel1, energy1, REACH, env1)
			+ ring(p, pos2, vel2, energy2, REACH, env2)
			+ ring(p, pos3, vec2(0.0), energy3, TOUCH_REACH, env3)
			+ ring(p, pos4, vec2(0.0), energy4, TOUCH_REACH, env4);
			+ ring(p, pos5, vel5, energy5, PUCK_REACH, env5);
	float amount = env1 + env2 + env3 + env4 + env5;
	float mask = smoothstep(0.03, 0.25, amount);   // nothing drawn where no source reaches
	if (mask < 0.003) {
		discard;   // far from every source: skip the expensive cloud math entirely
	}

	// Contour lines of the combined ripple height (as before)
	float t = h * LINE_LEVELS;
	float dist_to_line = abs(fract(t + 0.5) - 0.5);
	float line = 1.0 - smoothstep(LINE_THICKNESS, LINE_THICKNESS + fwidth(t), dist_to_line);

	// Clouds: noise bent by noise, drifting in time, stirred by the ripples
	float breathe = 1.0 + BREATHE * sin(TIME * 0.4);
	vec2 q = (p - 0.5 * screen_size) / (FLOW_SCALE * breathe);
	float ct = TIME * FLOW_SPEED;
	vec2 w = vec2(fbm(q + vec2(0.0, ct)), fbm(q + vec2(5.2, 1.3) - ct));
	float cloud = fbm(q + WARP_AMOUNT * w + h * RIPPLE_WARP);

	// Slice the cloud into soft glowing bands, each band a different point on the rainbow
	float bands = 0.5 + 0.5 * cos(cloud * BAND_DENSITY - TIME * 0.6);
	float hue_t = cloud * 2.5 + h * 0.15 + TIME * HUE_SPEED;
	vec3 rainbow = pal(hue_t);
	vec3 players = (color1.rgb * (env1 + env3) + color2.rgb * (env2 + env4) + color3.rgb * env5) / (amount + 0.0001);
	vec3 base = mix(players, rainbow, RAINBOW_MIX);

	// Lines take the opposite end of the rainbow so they pop against the clouds
	vec3 line_col = pal(hue_t + 0.5);
	vec3 rgb = mix(base, line_col, line);
	float a = max(CLOUD_OPACITY * smoothstep(0.4, 1.0, bands), line * LINE_OPACITY);
	COLOR = vec4(rgb, a * mask * strength);
}