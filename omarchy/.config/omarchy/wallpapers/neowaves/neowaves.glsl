// NeoWaves: glowing lines on black, lit in linear light so crossings bloom white-hot.
// An mpv/libplacebo user shader body; `render` prepends the hook header and theme colours.
// Every speed is a whole number of cycles per LOOP seconds, so the video loops seamlessly.
precision highp float;
#define T (float(frame) / 30.0)
#define PI 3.14159265
#define LOOP 480.0
#define W (2.0 * PI / LOOP)
#define LINES 7

float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec3 vivid(vec3 c) { float l = dot(c, vec3(0.299, 0.587, 0.114)); return clamp(mix(vec3(l), c, 2.2) * 1.15, 0.0, 1.0); }
vec3 lineColor(float i) {
  int k = int(mod(i, 5.0));
  return vivid(k == 0 ? C_BLUE : k == 1 ? C_MAGENTA : k == 2 ? C_CYAN : k == 3 ? C_ORANGE : C_RED);
}
vec3 toLinear(vec3 c) { return pow(c, vec3(2.2)); }
vec3 aces(vec3 x) { return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0); }

vec4 hook() {
  float aspect = HOOKED_size.x / HOOKED_size.y;
  vec2 p = vec2((HOOKED_pos.x - 0.5) * aspect, 0.5 - HOOKED_pos.y);   // centred, height 1, y up
  vec3 light = vec3(0.0);
  float coreSum = 0.0, coreSq = 0.0, glowSum = 0.0, glowSq = 0.0;
  for (int i = 0; i < LINES; i++) {
    float fi = float(i);
    float k1 = 3.0 + mod(fi, 2.0), k2 = 2.0 + step(1.5, mod(fi, 3.0));
    float a1 = 0.14 * (0.65 + 0.35 * sin(T * W + fi));
    float ph1 = p.x * 1.1 + T * W * k1 + fi * 0.55;
    float ph2 = p.x * 2.9 - T * W * k2 + fi * 1.3;
    float y = a1 * sin(ph1) + 0.045 * sin(ph2) + (fi - 3.0) * 0.034;
    float slope = a1 * 1.1 * cos(ph1) + 0.045 * 2.9 * cos(ph2);
    float d = abs(p.y - y) / sqrt(1.0 + slope * slope);          // true distance, so steep parts stay thick
    float core = exp(-pow(d / 0.0032, 2.0));
    float glow = 0.10 * exp(-d / 0.0085) + 0.025 * exp(-d / 0.04);  // the blur: two soft halos
    light += toLinear(lineColor(fi)) * (core * 0.9 + glow);
    coreSum += core; coreSq += core * core;
    glowSum += glow; glowSq += glow * glow;
  }
  float crossing = (coreSum * coreSum - coreSq) * 3.0 + (glowSum * glowSum - glowSq) * 6.0;  // nonzero only where lines overlap
  light += vec3(1.0, 0.93, 0.88) * crossing;
  vec3 col = pow(aces(light), vec3(1.0 / 2.2));
  col += (hash(HOOKED_pos * HOOKED_size + T) - 0.5) / 255.0;           // dither against banding in the glow
  return vec4(col, 1.0);
}
