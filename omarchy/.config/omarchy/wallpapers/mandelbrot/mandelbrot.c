// Mandelbrot live wallpaper: a slow dive from the whole Mandelbrot set into one
// of its tiny copies (a minibrot), which then is the whole set again.
//
// The loop: a minibrot of period p with nucleus c is, very nearly, the whole
// set scaled and turned by a complex factor s: minibrot = c + s * M, where s
// comes from the standard minibrot size estimate. The camera follows the
// continuous similarity that carries the full-set view onto the minibrot view:
// at time t it shows fixed + s^t * (w - fixed), with w covering the full-set
// view and `fixed` the fixed point of z -> c + s z. It spirals into a point
// that stays put on screen. Over the last CROSSFADE_SECONDS the frame fades
// into the view from just before the start (time t - 1), which becomes exactly
// the first frame when the loop wraps, so the seam cannot be seen.
//
// The speed-up: rendering every 4K frame directly would take days, so a few
// large keyframes are rendered instead, at most MAX_KEYFRAME_ZOOM of zoom
// apart, each with at least KEYFRAME_DENSITY texels per screen pixel. Frames
// are cut out of the current keyframe with SAMPLES x SAMPLES samples per pixel,
// which keeps the filaments crisp without shimmering.
//
// The colours: escape counts near the minibrot are about p times those near
// the whole set. Stretching the palette by sqrt(p) over the dive keeps the
// bands from crowding into white near the minibrot while staying colourful
// along the way.
//
// 64-bit floats are required: at the end of the dive neighbouring texels
// differ by far less than 32-bit floats can tell apart.
//
// Writes raw 16-bit RGB frames (rgb48le) to stdout, for ffmpeg.
// Usage: mandelbrot width height seconds fps cx cy period maxiter
//                   palette_iterations hex hex hex hex hex
#include <complex.h>
#include <limits.h>
#include <math.h>
#include <omp.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

enum { SAMPLES = 3, ACCENTS = 5 };
static const double START_CENTRE = -0.75;  // the whole set, centred
static const double START_WIDTH = 3.8;
static const double CROSSFADE_SECONDS = 60;
static const double MAX_KEYFRAME_ZOOM = M_SQRT2;
static const double KEYFRAME_DENSITY = 2.5;
static const double GLOW_PIXELS = 0.25;  // how far the light reaches out; wider washes dense areas white
static const double EXPOSURE = 0.8;
static const double BLACK_POINT = 0.002;  // light below this is true black (deep blacks for OLED)

typedef struct {
  float mu;        // smooth escape count; negative inside the set
  float distance;  // estimated distance to the set, in plane units
} Texel;

typedef struct {
  Texel *texels;
  int index;  // which keyframe is loaded, INT_MIN for none
  double texel;
} Keyframe;

typedef struct {
  double complex fixed;         // the point the camera spirals into
  double complex log_scale;     // log of s, the minibrot's scale and turn
  double complex start_offset;  // the start view's centre, relative to `fixed`
  double start_pixel;
  int period;
  int keyframes;                // per loop
  int size;                     // keyframe width and height in texels
  int maxiter;
  double palette_iterations;
  double accents[ACCENTS][3];
} Dive;

// Theme accents, boosted towards vivid, in linear light.
static void accent_from_hex(const char *hex, double linear[3]) {
  unsigned rgb[3];
  sscanf(hex[0] == '#' ? hex + 1 : hex, "%2x%2x%2x", &rgb[0], &rgb[1], &rgb[2]);
  double luma = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
  for (int k = 0; k < 3; k++) {
    double vivid = fmin(fmax((luma + (rgb[k] - luma) * 2.2) * 1.15, 0), 255);
    linear[k] = pow(vivid / 255, 2.2);
  }
}

static double aces(double x) {
  return fmin(fmax((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0), 1);
}

static void load_keyframe(const Dive *dive, Keyframe *keyframe, int index) {
  if (keyframe->index == index) return;
  double started = omp_get_wtime();
  keyframe->index = index;
  // Keyframe `index` serves times [index, index + 1) / keyframes: sharpest at
  // the start, still KEYFRAME_DENSITY at the end.
  keyframe->texel = dive->start_pixel * exp(creal(dive->log_scale) * (index + 1) / dive->keyframes) / KEYFRAME_DENSITY;
  int size = dive->size;
#pragma omp parallel for schedule(dynamic, 1)
  for (int row = 0; row < size; row++) {
    for (int col = 0; col < size; col++) {
      double x0 = creal(dive->fixed) + (col - size / 2.0 + 0.5) * keyframe->texel;
      double y0 = cimag(dive->fixed) + (size / 2.0 - row - 0.5) * keyframe->texel;
      double x = 0, y = 0, x2 = 0, y2 = 0, dx = 0, dy = 0;
      // Periodicity check: an orbit that returns to a remembered point is
      // caught in a cycle, so the point is inside. Saves running to the
      // iteration limit on the large black areas.
      double remembered_x = 0, remembered_y = 0;
      int i = 0, since_remembered = 0, remember_every = 8, inside = 0;
      while (x2 + y2 < 1e6 && i < dive->maxiter) {
        double next_dx = 2 * (x * dx - y * dy) + 1;
        dy = 2 * (x * dy + y * dx);
        dx = next_dx;
        y = 2 * x * y + y0;
        x = x2 - y2 + x0;
        x2 = x * x;
        y2 = y * y;
        i++;
        if (fabs(x - remembered_x) < 1e-15 && fabs(y - remembered_y) < 1e-15) {
          inside = 1;
          break;
        }
        if (++since_remembered == remember_every) {
          since_remembered = 0;
          remember_every *= 2;
          remembered_x = x;
          remembered_y = y;
        }
      }
      Texel *out = &keyframe->texels[(size_t)row * size + col];
      if (inside || i == dive->maxiter) {
        *out = (Texel){-1, 0};
        continue;
      }
      double modulus = sqrt(x2 + y2);
      out->mu = i + 1 - log2(log(modulus));
      out->distance = 0.5 * modulus * log(modulus) / hypot(dx, dy);
    }
  }
  fprintf(stderr, "keyframe %d: %.1f s\n", index, omp_get_wtime() - started);
}

// Adds `weight` times the light of the view at time tau to one screen pixel.
static void shade(const Dive *dive, const Keyframe *keyframe, double tau, double weight, int px, int py,
                  int width, int height, double light[3]) {
  double complex zoom = cexp(tau * dive->log_scale);  // the camera's scale and turn
  double pixel = dive->start_pixel * cabs(zoom);
  double palette_iterations = dive->palette_iterations * pow(dive->period, tau / 2);
  weight /= SAMPLES * SAMPLES;
  for (int sy = 0; sy < SAMPLES; sy++) {
    for (int sx = 0; sx < SAMPLES; sx++) {
      double u = (px + (sx + 0.5) / SAMPLES - width / 2.0) * dive->start_pixel;
      double v = (height / 2.0 - py - (sy + 0.5) / SAMPLES) * dive->start_pixel;
      double complex offset = zoom * (dive->start_offset + u + v * I);  // from `fixed`
      int col = (int)floor(creal(offset) / keyframe->texel + dive->size / 2.0);
      int row = (int)floor(dive->size / 2.0 - cimag(offset) / keyframe->texel);
      if (col < 0 || row < 0 || col >= dive->size || row >= dive->size) continue;
      Texel sample = keyframe->texels[(size_t)row * dive->size + col];
      if (sample.mu < 0) continue;  // inside the set: deep black

      double phase = sample.mu / palette_iterations;
      double position = (phase - floor(phase)) * ACCENTS;
      int a = (int)position % ACCENTS;
      double blend = position - floor(position);
      blend = blend * blend * (3 - 2 * blend);
      double reach = sample.distance / pixel / GLOW_PIXELS;
      double glow = weight * EXPOSURE / (1 + reach * reach);
      for (int k = 0; k < 3; k++)
        light[k] += (dive->accents[a][k] + (dive->accents[(a + 1) % ACCENTS][k] - dive->accents[a][k]) * blend) * glow;
    }
  }
}

int main(int argc, char **argv) {
  if (argc != 15) {
    fprintf(stderr, "usage: mandelbrot width height seconds fps cx cy period maxiter "
                    "palette_iterations hex hex hex hex hex\n");
    return 2;
  }
  int width = atoi(argv[1]), height = atoi(argv[2]);
  double seconds = atof(argv[3]);
  int frames = (int)(seconds * atoi(argv[4]));
  double complex nucleus = atof(argv[5]) + atof(argv[6]) * I;
  Dive dive = {.period = atoi(argv[7]), .maxiter = atoi(argv[8]), .palette_iterations = atof(argv[9])};
  for (int a = 0; a < ACCENTS; a++) accent_from_hex(argv[10 + a], dive.accents[a]);

  // The minibrot size estimate: the copy is nucleus + s * M.
  double complex z = 0, l = 1, b = 1;
  for (int i = 1; i < dive.period; i++) {
    z = z * z + nucleus;
    l = 2 * z * l;
    b += 1 / l;
  }
  double complex s = 1 / (b * l * l);
  dive.log_scale = clog(s);
  dive.fixed = nucleus / (1 - s);
  dive.start_offset = START_CENTRE - dive.fixed;
  dive.start_pixel = START_WIDTH / width;
  dive.keyframes = (int)ceil(-creal(dive.log_scale) / log(MAX_KEYFRAME_ZOOM));
  fprintf(stderr, "dive: zoom x%.3g, camera turn %.1f deg, %d keyframes, %d frames\n", 1 / cabs(s),
          carg(s) * 180 / M_PI, dive.keyframes, frames);

  // Every view spirals around `fixed`, so a keyframe centred there must reach
  // the far screen corner plus the distance from the screen centre to `fixed`.
  double keyframe_zoom = exp(-creal(dive.log_scale) / dive.keyframes);
  double reach = hypot(width, height) / 2 + cabs(dive.start_offset) / dive.start_pixel;
  dive.size = 2 * (int)ceil(reach * keyframe_zoom * KEYFRAME_DENSITY) + 2;

  Keyframe current = {.index = INT_MIN}, before_start = {.index = INT_MIN};
  current.texels = malloc((size_t)dive.size * dive.size * sizeof(Texel));
  before_start.texels = malloc((size_t)dive.size * dive.size * sizeof(Texel));
  uint16_t *frame = malloc((size_t)width * height * 3 * sizeof(uint16_t));
  if (!current.texels || !before_start.texels || !frame) {
    fprintf(stderr, "out of memory for %dx%d keyframes\n", dive.size, dive.size);
    return 1;
  }

  double crossfade = CROSSFADE_SECONDS / seconds;
  for (int f = 0; f < frames; f++) {
    double t = (double)f / frames;
    double fade = t > 1 - crossfade ? (t - (1 - crossfade)) / crossfade : 0;
    fade = fade * fade * (3 - 2 * fade);
    load_keyframe(&dive, &current, (int)floor(t * dive.keyframes));
    if (fade > 0) load_keyframe(&dive, &before_start, (int)floor((t - 1) * dive.keyframes));

#pragma omp parallel for schedule(static)
    for (int py = 0; py < height; py++) {
      for (int px = 0; px < width; px++) {
        double light[3] = {0, 0, 0};
        shade(&dive, &current, t, 1 - fade, px, py, width, height, light);
        if (fade > 0) shade(&dive, &before_start, t - 1, fade, px, py, width, height, light);
        uint16_t *out = &frame[((size_t)py * width + px) * 3];
        for (int k = 0; k < 3; k++)
          out[k] = (uint16_t)(65535 * pow(aces(fmax(light[k] - BLACK_POINT, 0)), 1 / 2.2) + 0.5);
      }
    }
    fwrite(frame, sizeof(uint16_t), (size_t)width * height * 3, stdout);
  }
  free(frame);
  free(before_start.texels);
  free(current.texels);
  return 0;
}
