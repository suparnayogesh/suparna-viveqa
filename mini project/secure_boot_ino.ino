/*
  esp32_firmware_sender.ino
  Runs on the ESP32-C3-MINI-1 on the AT-STLN-ARTIX7-001 board.

  Sends a fixed 32-byte "firmware image" to the FPGA over UART0
  (GPIO20 = RX, GPIO21 = TX), broken out to header J13 pins 5/6.

  Wiring: jumper J13 pin 6 (ESP_TX / GPIO21) -> PMOD J16 pin IO_0
          (FPGA pin T2). Share GND (already common on-board).

  Programming: connect to the ESP32's own USB-C port (J9), NOT the
  FPGA's USB-C (J1).

  Usage (via Arduino Serial Monitor @115200, USB CDC):
    type 'n' + Enter  -> send the genuine/trusted firmware  -> FPGA should PASS
    type 't' + Enter  -> send a 1-byte-tampered firmware     -> FPGA should FAIL
*/

#include <Arduino.h>
#include <HardwareSerial.h>
#include <string.h>

// Dedicated hardware UART0 mapped to GPIO20 (RX) / GPIO21 (TX)
HardwareSerial FpgaUART(0);

// Trusted 32-byte firmware image (must match the reference hash
// baked into secure_boot_top.v)
const uint8_t firmware_genuine[32] = {
  'A','N','M','A','Y','A','-','F','P','G','A','-','S','E','C','U',
  'R','E','B','O','O','T','-','D','E','M','O','-','0','0','1','!'
};

void sendFirmware(const uint8_t *fw, size_t len, const char *label) {
  Serial.print("Sending ");
  Serial.print(label);
  Serial.print(" firmware (");
  Serial.print((unsigned)len);
  Serial.println(" bytes) to FPGA...");

  // Sync header - lets the FPGA ignore any boot-log noise on this
  // same UART and reliably find the start of the real payload.
  FpgaUART.write(0xAA);
  delay(2);
  FpgaUART.write(0x55);
  delay(2);

  for (size_t i = 0; i < len; i++) {
    FpgaUART.write(fw[i]);
    delay(2); // small gap between bytes, generous margin over the FPGA UART rx timing
  }
  Serial.println("Done. Watch LED_PASS / LED_FAIL and the LCD on the board.");
}

void setup() {
  Serial.begin(115200);           // USB CDC serial monitor (J9)
  while (!Serial) { delay(10); }

  FpgaUART.begin(115200, SERIAL_8N1, /*RX=*/20, /*TX=*/21);

  Serial.println();
  Serial.println("=== FPGA Secure Boot Demo - ESP32-C3 firmware sender ===");
  Serial.println("Type 'n' + Enter to send genuine firmware (expect PASS)");
  Serial.println("Type 't' + Enter to send tampered firmware (expect FAIL)");
}

void loop() {
  if (Serial.available()) {
    char c = Serial.read();

    if (c == 'n' || c == 'N') {
      sendFirmware(firmware_genuine, sizeof(firmware_genuine), "GENUINE");
    }
    else if (c == 't' || c == 'T') {
      // Tamper: flip the last byte (bit-flip on '!' -> ' ')
      uint8_t firmware_tampered[32];
      memcpy(firmware_tampered, firmware_genuine, sizeof(firmware_genuine));
      firmware_tampered[31] ^= 0x01;
      sendFirmware(firmware_tampered, sizeof(firmware_tampered), "TAMPERED");
    }
  }
}
