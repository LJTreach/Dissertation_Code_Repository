#include <Arduino.h>

// ------------------------------------------------------------
// Idle baseline sketch:
// Arduino powered, clocked, and executing code,
// but not running the Sobel workload.
// LED is forced OFF.
// ------------------------------------------------------------

volatile uint32_t idle_counter = 0;
volatile uint16_t idle_mix = 0;
volatile uint8_t idle_acc = 0;

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);
}

void loop() {
  idle_counter++;
  idle_mix += (uint16_t)(idle_counter & 0xFFFF);
  idle_acc ^= (uint8_t)(idle_counter >> 8) ^ (uint8_t)idle_mix;
}