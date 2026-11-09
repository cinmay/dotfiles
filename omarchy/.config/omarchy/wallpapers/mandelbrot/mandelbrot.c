// Mandelbrot live wallpaper: an endless, slow zoom into a Misiurewicz point.
//
// The loop: at a Misiurewicz point c the orbit of 0 lands on a cycle after
// `preperiod` steps, and the cycle repeats every `period` steps. Around c the
// set is self-similar: magnifying by the cycle's multiplier lambda shows the
// same picture turned by arg(lambda). Zooming by |lambda|^steps while the
// camera turns the leftover angle ends on the frame it started from, so the
// video loops seamlessly.
//
// The speed-up: rendering every 4K frame directly would take hours, so a few
// large keyframes are rendered instead, at most MAX_KEYFRAME_ZOOM of zoom
// apart, each with at least KEYFRAME_DENSITY texels per screen pixel. Frames
// are cut out of the current keyframe with SAMPLES x SAMPLES samples per pixel,
// which keeps the filaments crisp without shimmering. The keyframes split the
// loop's zoom evenly, so the loop's end is sampled like its start.
//
// The colours: keyframes keep the raw escape data and colour is applied per
// frame. Escape counts grow by steps * period over one loop and the palette
// shifts back by the same amount, so the colours meet at the seam too.
//
// 64-bit floats are required: at these depths neighbouring texels differ by
// less than 32-bit floats can tell apart.
//
// Writes raw 16-bit RGB frames (rgb48le) to stdout, for ffmpeg.
// Usage: mandelbrot width height seconds fps cx cy preperiod period steps
//                   span maxiter palette_iterations hex hex hex hex hex
#include <complex.h>
#include <math.h>
#include <omp.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

enum { SAMPLES = 3, ACCENTS = 5 };
static const double MAX_KEYFRAME_ZOOM = M_SQRT2;
static const double KEYFRAME_DENSITY = 2.5;
static const double GLOW_PIXELS = 0.6;  // how far the light reaches out from the set
static const double EXPOSURE = 1.3;
static const double BLACK_POINT = 0.002;  // light below this is true black (deep blacks for OLED)

typedef struct {
  float mu;        // smooth escape count; negative inside the set
  float distance;  // estimated distance to the set, in plane units
} Texel;

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

static void render_keyframe(Texel *texels, int size, double cx, double cy, double texel, int maxiter) {
#pragma omp parallel for schedule(dynamic, 1)
  for (int row = 0; row < size; row++) {
    for (int col = 0; col < size; col++) {
      double x0 = cx + (col - size / 2.0 + 0.5) * texel, y0 = cy + (size / 2.0 - row - 0.5) * texel;
      double x = 0, y = 0, x2 = 0, y2 = 0, dx = 0, dy = 0;
      int i = 0;
      while (x2 + y2 < 1e6 && i < maxiter) {
        double next_dx = 2 * (x * dx - y * dy) + 1;
        dy = 2 * (x * dy + y * dx);
        dx = next_dx;
        y = 2 * x * y + y0;
        x = x2 - y2 + x0;
        x2 = x * x;
        y2 = y * y;
        i++;
      }
      Texel *out = &texels[(size_t)row * size + col];
      if (i == maxiter) {
        *out = (Texel){-1, 0};
        continue;
      }
      double modulus = sqrt(x2 + y2);
      out->mu = i + 1 - log2(log(modulus));
      out->distance = 0.5 * modulus * log(modulus) / hypot(dx, dy);
    }
  }
}

int main(int argc, char **argv) {
  if (argc != 18) {
    fprintf(stderr, "usage: mandelbrot width height seconds fps cx cy preperiod period steps "
                    "span maxiter palette_iterations hex hex hex hex hex\n");
    return 2;
  }
  int width = atoi(argv[1]), height = atoi(argv[2]), frames = atoi(argv[3]) * atoi(argv[4]);
  double complex c = atof(argv[5]) + atof(argv[6]) * I;
  int preperiod = atoi(argv[7]), period = atoi(argv[8]), steps = atoi(argv[9]);
  double span = atof(argv[10]);
  int maxiter = atoi(argv[11]);
  double palette_iterations = atof(argv[12]);
  double accents[ACCENTS][3];
  for (int a = 0; a < ACCENTS; a++) accent_from_hex(argv[13 + a], accents[a]);

  double complex z = 0, multiplier = 1;
  for (int i = 0; i < preperiod + period; i++) {
    if (i >= preperiod) multiplier *= 2 * z;
    z = z * z + c;
  }
  double loop_zoom = pow(cabs(multiplier), steps);
  double loop_turn = remainder(steps * carg(multiplier), 2 * M_PI);
  double loop_iterations = (double)steps * period;
  fprintf(stderr, "loop: zoom x%.3f, camera turn %.2f deg, %d frames\n", loop_zoom, -loop_turn * 180 / M_PI, frames);

  int keyframes = (int)ceil(log(loop_zoom) / log(MAX_KEYFRAME_ZOOM));
  double keyframe_zoom = pow(loop_zoom, 1.0 / keyframes);
  double start_pixel = span / width;
  double screen_radius = hypot(width, height) / 2;  // the turning camera needs a circle covered
  int size = 2 * (int)ceil(screen_radius * keyframe_zoom * KEYFRAME_DENSITY) + 2;
  Texel *texels = malloc((size_t)size * size * sizeof(Texel));
  uint16_t *frame = malloc((size_t)width * height * 3 * sizeof(uint16_t));
  if (!texels || !frame) {
    fprintf(stderr, "out of memory for a %dx%d keyframe\n", size, size);
    return 1;
  }

  int keyframe = -1;
  double texel = 0;
  for (int f = 0; f < frames; f++) {
    double t = (double)f / frames;
    double zoom = pow(loop_zoom, t);
    int needed = (int)floor(t * keyframes);
    if (needed != keyframe) {
      keyframe = needed;
      texel = start_pixel / (pow(keyframe_zoom, keyframe + 1) * KEYFRAME_DENSITY);
      double started = omp_get_wtime();
      render_keyframe(texels, size, creal(c), cimag(c), texel, maxiter);
      fprintf(stderr, "keyframe %d (%dx%d): %.1f s\n", keyframe, size, size, omp_get_wtime() - started);
    }

    double pixel = start_pixel / zoom, turn = -loop_turn * t, palette_shift = loop_iterations * t;
    double cos_turn = cos(turn), sin_turn = sin(turn);
#pragma omp parallel for schedule(static)
    for (int py = 0; py < height; py++) {
      for (int px = 0; px < width; px++) {
        double light[3] = {0, 0, 0};
        for (int sy = 0; sy < SAMPLES; sy++) {
          for (int sx = 0; sx < SAMPLES; sx++) {
            double u = (px + (sx + 0.5) / SAMPLES - width / 2.0) * pixel;
            double v = (height / 2.0 - py - (sy + 0.5) / SAMPLES) * pixel;
            double x = u * cos_turn - v * sin_turn, y = u * sin_turn + v * cos_turn;
            int col = (int)floor(x / texel + size / 2.0), row = (int)floor(size / 2.0 - y / texel);
            Texel sample = texels[(size_t)row * size + col];
            if (sample.mu < 0) continue;  // inside the set: deep black

            double phase = (sample.mu - palette_shift) / palette_iterations;
            double position = (phase - floor(phase)) * ACCENTS;
            int a = (int)position % ACCENTS;
            double blend = position - floor(position);
            blend = blend * blend * (3 - 2 * blend);
            double reach = sample.distance / pixel / GLOW_PIXELS;
            double glow = EXPOSURE / (1 + reach * reach);
            for (int k = 0; k < 3; k++)
              light[k] += (accents[a][k] + (accents[(a + 1) % ACCENTS][k] - accents[a][k]) * blend) * glow;
          }
        }
        uint16_t *out = &frame[((size_t)py * width + px) * 3];
        for (int k = 0; k < 3; k++)
          out[k] = (uint16_t)(65535 * pow(aces(fmax(light[k] / (SAMPLES * SAMPLES) - BLACK_POINT, 0)), 1 / 2.2) + 0.5);
      }
    }
    fwrite(frame, sizeof(uint16_t), (size_t)width * height * 3, stdout);
  }
  free(frame);
  free(texels);
  return 0;
}
