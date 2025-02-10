int led_state = 0;
int ledPin = 13;      //For Uno and Nano
void setup() {
  pinMode(ledPin, OUTPUT);
}

void loop() {
  digitalWrite(ledPin, !led_state);
  led_state = !led_state;
  delay(1000);
}
