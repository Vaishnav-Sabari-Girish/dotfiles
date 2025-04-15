#include <BluetoothSerial.h>

BluetoothSerial ESP_BT;

void setup() {
	Serial.begin(9600);
	ESP_BT.begin("Heil_Hitler");
	
}

void loop() {
	if(ESP_BT.available() > 0)
	{
		char BT_Char = ESP_BT.read();
		Serial.println("BT_Char : " + BT_Char);
	}
}
