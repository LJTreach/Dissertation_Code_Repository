#include <Arduino.h>
#include <avr/pgmspace.h>
#include <string.h>

// ------------------------------------------------------------
// Fixed benchmark settings
// ------------------------------------------------------------
static const uint8_t W = 32;
static const uint8_t H = 32;
static const uint8_t THRESHOLD = 120;

// ------------------------------------------------------------
// Benchmark-report settings
// ------------------------------------------------------------
static const uint32_t BAUD = 115200;
static const uint32_t START_DELAY_MS = 3000;
static const uint32_t BENCHMARK_MS   = 60000;

// ------------------------------------------------------------
// 32x32 grayscale image from input_32x32.mem
// Stored in flash memory (PROGMEM), not SRAM
// ------------------------------------------------------------
const uint8_t IMG[W * H] PROGMEM = {
  16, 17, 16, 16, 17, 17, 16, 16, 16, 17, 16, 16, 17, 17, 17, 16,
  17, 17, 16, 17, 17, 17, 17, 16, 16, 16, 17, 16, 17, 16, 16, 16,
  16, 17, 16, 16, 17, 17, 16, 16, 16, 16, 17, 17, 17, 17, 16, 16,
  16, 16, 16, 16, 17, 16, 17, 16, 16, 16, 16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 17, 16, 16, 16, 16, 17, 17, 17, 17, 17, 16, 15,
  16, 17, 17, 17, 17, 17, 17, 17, 16, 16, 16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 17, 17, 16, 16, 17, 17, 17, 16, 15, 13, 16, 24,
  21, 15, 16, 17, 17, 16, 17, 17, 16, 17, 17, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 14, 17, 30, 49, 48, 67,
  74, 45, 26, 17, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 15, 15,
  16, 16, 16, 16, 16, 16, 16, 16, 16, 13, 28, 91, 109, 116, 98, 51,
  47, 67, 70, 34, 15, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 16, 16, 16, 11, 36, 110, 134, 118, 121, 108, 72,
  48, 61, 57, 27, 15, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 17, 16, 13, 59, 112, 116, 134, 145, 119, 98, 76,
  78, 40, 53, 30, 15, 16, 17, 16, 16, 17, 16, 16, 16, 16, 16, 16,
  17, 16, 16, 17, 17, 17, 12, 56, 121, 144, 129, 139, 148, 138, 99, 83,
  76, 34, 29, 25, 16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 16, 16,
  16, 16, 16, 17, 17, 12, 50, 138, 140, 129, 131, 135, 136, 119, 103, 110,
  80, 64, 20, 16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 16,
  16, 16, 16, 16, 12, 45, 130, 141, 140, 127, 120, 132, 128, 115, 114, 106,
  85, 70, 41, 16, 16, 16, 16, 17, 16, 17, 17, 16, 17, 17, 17, 16,
  16, 16, 16, 14, 28, 137, 144, 121, 123, 127, 128, 135, 100, 110, 114, 74,
  71, 70, 46, 17, 16, 16, 16, 16, 16, 16, 17, 16, 16, 16, 16, 17,
  16, 16, 16, 14, 107, 165, 135, 130, 126, 119, 131, 106, 60, 65, 75, 78,
  57, 77, 41, 18, 16, 16, 16, 17, 16, 17, 17, 17, 16, 17, 17, 16,
  16, 16, 12, 71, 163, 139, 119, 124, 120, 127, 130, 102, 78, 63, 72, 87,
  81, 75, 44, 34, 17, 16, 17, 16, 16, 16, 17, 17, 17, 17, 17, 17,
  17, 14, 45, 136, 149, 142, 120, 108, 130, 139, 135, 106, 88, 80, 107, 85,
  100, 79, 25, 26, 19, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
  17, 15, 113, 147, 148, 155, 148, 128, 140, 130, 120, 107, 106, 102, 102, 82,
  85, 79, 34, 15, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
  15, 31, 145, 140, 145, 151, 166, 151, 139, 127, 102, 84, 101, 114, 91, 93,
  66, 55, 51, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
  12, 61, 165, 131, 146, 146, 153, 143, 144, 113, 99, 88, 112, 114, 98, 116,
  70, 44, 30, 18, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
  13, 47, 162, 141, 136, 157, 159, 130, 131, 139, 121, 109, 129, 109, 101, 103,
  82, 56, 21, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
  16, 18, 125, 157, 137, 166, 160, 129, 140, 144, 121, 119, 111, 110, 106, 73,
  67, 52, 26, 18, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
  17, 14, 35, 134, 140, 145, 140, 138, 140, 137, 123, 104, 95, 101, 98, 74,
  58, 63, 31, 18, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17,
  16, 17, 12, 64, 143, 133, 134, 146, 131, 119, 118, 103, 99, 95, 86, 98,
  78, 66, 47, 31, 16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 16, 16,
  16, 16, 16, 13, 77, 138, 130, 135, 138, 113, 111, 123, 104, 103, 87, 91,
  95, 81, 68, 22, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
  16, 16, 16, 15, 23, 108, 139, 129, 137, 133, 123, 122, 114, 99, 89, 102,
  79, 75, 36, 19, 16, 17, 17, 17, 16, 16, 16, 16, 16, 16, 16, 16,
  16, 16, 16, 17, 15, 22, 98, 144, 137, 131, 125, 117, 130, 103, 92, 86,
  51, 57, 43, 17, 17, 17, 17, 17, 17, 17, 17, 16, 16, 16, 16, 16,
  16, 16, 17, 17, 17, 15, 22, 109, 119, 108, 129, 130, 124, 102, 84, 74,
  49, 58, 32, 18, 17, 17, 17, 17, 17, 17, 17, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 16, 11, 79, 69, 61, 129, 133, 121, 101, 75, 72,
  67, 65, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 16, 15, 29, 35, 64, 118, 121, 94, 101, 88, 91,
  65, 54, 27, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 15,
  16, 16, 16, 16, 16, 16, 16, 15, 15, 19, 46, 93, 113, 107, 123, 95,
  71, 55, 38, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 15, 15,
  16, 16, 16, 16, 16, 16, 16, 16, 16, 15, 12, 20, 54, 90, 109, 85,
  77, 54, 23, 15, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 15, 16,
  16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 15, 12, 16, 34, 48,
  50, 36, 18, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 17, 17, 16, 16, 16, 16, 17, 17, 17, 16, 14, 13,
  15, 15, 16, 17, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
};

// ------------------------------------------------------------
// Rolling line buffers (SRAM)
// ------------------------------------------------------------
static uint8_t lineA[W];
static uint8_t lineB[W];
static uint8_t lineC[W];

// ------------------------------------------------------------
// Sink/state variables so the workload remains real
// ------------------------------------------------------------
volatile uint32_t frame_count  = 0;
volatile uint32_t valid_count  = 0;
volatile uint32_t edge_sum     = 0;
volatile uint8_t  activity_acc = 0;

// ------------------------------------------------------------
// Benchmark state
// ------------------------------------------------------------
static bool benchmark_started = false;
static bool benchmark_done    = false;
static uint32_t start_ms      = 0;
static uint32_t end_ms        = 0;

static inline uint16_t abs16(int16_t v) {
  return (v < 0) ? (uint16_t)(-v) : (uint16_t)v;
}

static void process_one_frame() {
  memset(lineA, 0, sizeof(lineA));
  memset(lineB, 0, sizeof(lineB));
  memset(lineC, 0, sizeof(lineC));

  uint8_t *row0 = lineA;  // y-2
  uint8_t *row1 = lineB;  // y-1
  uint8_t *row2 = lineC;  // y

  for (uint8_t y = 0; y < H; y++) {
    for (uint8_t x = 0; x < W; x++) {
      uint8_t pixel_in = pgm_read_byte(&IMG[(uint16_t)y * W + x]);
      row2[x] = pixel_in;

      uint8_t pixel_out = 0x00;

      // Match FPGA-style valid-window behaviour:
      // first two rows and first two columns produce 0
      if (y >= 2 && x >= 2) {
        int16_t gx =
            (int16_t)row0[x]     + ((int16_t)row1[x]     << 1) + (int16_t)row2[x]
          - (int16_t)row0[x - 2] - ((int16_t)row1[x - 2] << 1) - (int16_t)row2[x - 2];

        int16_t gy =
            (int16_t)row2[x - 2] + ((int16_t)row2[x - 1] << 1) + (int16_t)row2[x]
          - (int16_t)row0[x - 2] - ((int16_t)row0[x - 1] << 1) - (int16_t)row0[x];

        uint16_t mag = abs16(gx) + abs16(gy);

        pixel_out = (mag > THRESHOLD) ? 0xFF : 0x00;

        valid_count++;
        edge_sum += pixel_out;
        activity_acc ^= pixel_out ^ x ^ y;
      }
    }

    uint8_t *tmp = row0;
    row0 = row1;
    row1 = row2;
    row2 = tmp;
  }

  frame_count++;
  activity_acc ^= (uint8_t)frame_count;
}

static void send_one_verification_frame() {
  memset(lineA, 0, sizeof(lineA));
  memset(lineB, 0, sizeof(lineB));
  memset(lineC, 0, sizeof(lineC));

  uint8_t *row0 = lineA;  // y-2
  uint8_t *row1 = lineB;  // y-1
  uint8_t *row2 = lineC;  // y

  // Header:
  // A5 5A F1 W H THRESHOLD
  Serial.write((uint8_t)0xA5);
  Serial.write((uint8_t)0x5A);
  Serial.write((uint8_t)0xF1);
  Serial.write((uint8_t)W);
  Serial.write((uint8_t)H);
  Serial.write((uint8_t)THRESHOLD);

  for (uint8_t y = 0; y < H; y++) {
    for (uint8_t x = 0; x < W; x++) {
      uint8_t pixel_in = pgm_read_byte(&IMG[(uint16_t)y * W + x]);
      row2[x] = pixel_in;

      uint8_t pixel_out = 0x00;

      // Match FPGA-style valid-window behaviour:
      // first two rows and first two columns produce 0
      if (y >= 2 && x >= 2) {
        int16_t gx =
            (int16_t)row0[x]     + ((int16_t)row1[x]     << 1) + (int16_t)row2[x]
          - (int16_t)row0[x - 2] - ((int16_t)row1[x - 2] << 1) - (int16_t)row2[x - 2];

        int16_t gy =
            (int16_t)row2[x - 2] + ((int16_t)row2[x - 1] << 1) + (int16_t)row2[x]
          - (int16_t)row0[x - 2] - ((int16_t)row0[x - 1] << 1) - (int16_t)row0[x];

        uint16_t mag = abs16(gx) + abs16(gy);
        pixel_out = (mag > THRESHOLD) ? 0xFF : 0x00;
      }

      Serial.write(pixel_out);
    }

    uint8_t *tmp = row0;
    row0 = row1;
    row1 = row2;
    row2 = tmp;
  }
}

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  Serial.begin(BAUD);
  delay(START_DELAY_MS);

  send_one_verification_frame();

  frame_count = 0;
  valid_count = 0;
  edge_sum = 0;
  activity_acc = 0;

  start_ms = millis();
  benchmark_started = true;
}

void loop() {
  if (!benchmark_started || benchmark_done) {
    return;
  }

  uint32_t now = millis();

  if ((now - start_ms) < BENCHMARK_MS) {
    process_one_frame();
  } else {
    end_ms = now;
    benchmark_done = true;

    uint32_t elapsed_ms = end_ms - start_ms;
    float elapsed_s = elapsed_ms / 1000.0f;
    float fps = (elapsed_s > 0.0f) ? (frame_count / elapsed_s) : 0.0f;

    Serial.println(F("Benchmark complete."));
    Serial.print(F("Elapsed ms: "));
    Serial.println(elapsed_ms);
    Serial.print(F("Elapsed s: "));
    Serial.println(elapsed_s, 6);
    Serial.print(F("Frames processed: "));
    Serial.println(frame_count);
    Serial.print(F("Frame rate (frames/s): "));
    Serial.println(fps, 6);

    while (true) {
      // Hold result
    }
  }
}
