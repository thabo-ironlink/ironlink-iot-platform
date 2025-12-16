#include <WiFi.h>
#include <PubSubClient.h>
#include "DHT.h"

// ---------- MODIFY THESE 3 LINES ----------
const char* ssid = "Thabo";          // <--- CHANGE
const char* password = "********";  // <--- CHANGE
const char* mqtt_server = "192.168.0.104";    // <--- Pi IP address
// ------------------------------------------

// ===== CHANGE FOR CLIENT / ENV =====
#define MQTT_TOPIC "ironlink/env/HOME/esp32/dht11"

#define DHTPIN 26
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

WiFiClient espClient;
PubSubClient client(espClient);

void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println(WiFi.localIP());
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("esp32-dht11")) {
      Serial.println("connected");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  dht.begin();

  setup_wifi();
  client.setServer(mqtt_server, 1883);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  float h = dht.readHumidity();
  float t = dht.readTemperature();

  if (!isnan(h) && !isnan(t)) {
    char payload[80];
    sprintf(payload, "{\"temp_c\": %.2f, \"humidity\": %.2f}", t, h);

    client.publish(MQTT_TOPIC, payload);
    Serial.print("Published: ");
    Serial.println(payload);
  } else {
    Serial.println("Failed to read DHT11");
  }

  delay(3000);
}
