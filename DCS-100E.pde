
//extern "C" {
#include <stdlib.h>
//}
#include <string.h>
#include <SPI.h>
#include <Ethernet.h>
#include <SD.h>
// size of buffer used to capture HTTP requests
#define REQ_BUF_SZ  100
//#include <stdio.h>

// MAC address from Ethernet shield sticker under board
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
IPAddress ip(192, 168, 24, 177); // IP address, may need to change depending on network
EthernetServer server(80);  // create a server at port 80



File webFile;               // the web page file on the SD card
char HTTP_req[REQ_BUF_SZ] = {0}; // buffered HTTP request stored as null terminated string
char req_index = 0;              // index into HTTP_req buffer
boolean LED_state[4] = {0}; // stores the states of the LEDs


int output1_brightness = 0;
int output1_pulsewidth = 0;
int output1_pulsedelay = 0;
int output1_triggernum = 0;
int output1_mode = 0;

int output2_brightness = 0;
int output2_pulsewidth = 0;
int output2_pulsedelay = 0;
int output2_triggernum = 0;
int output2_mode = 0;

const int sdchipSelect = SD_CHIP_SELECT_PIN;


void setup()
{
  
  #ifdef MAPLE
Serial.begin(BPS_115200);       // for debugging
#endif 

#ifdef ARDUINO
Serial.begin(115200);
#endif



  pinMode(3, PWM);
  pinMode(2, INPUT);
  pinMode(5, INPUT);
  pinMode(6, OUTPUT);
  pinMode(7, OUTPUT);
  pinMode(8, OUTPUT);
  pinMode(9, OUTPUT);


  // disable w5100 SPI while starting SD
  pinMode(BOARD_SPI2_NSS_PIN,OUTPUT);
  digitalWrite(BOARD_SPI2_NSS_PIN,HIGH);
  

  
    // initialize SD card
//  Serial.println("Initializing SD card...");
  if (!SD.begin(sdchipSelect)) {
    Serial.println("ERROR!");
    return;    // init failed
  }
  Serial.println("SUCCESS.");
  // check for index.htm file
  if (!SD.exists("index.htm")) {
//    Serial.println("ERROR - no index.htm!");
    return;  // can't find index file
  }
//  Serial.println("SUCCESS - Found index.htm file.");
 
  

 // disable SD SPI
  pinMode(SD_CHIP_SELECT_PIN, OUTPUT);
  digitalWrite(SD_CHIP_SELECT_PIN, HIGH);


pinMode(W5100_RESET_PIN, OUTPUT);
digitalWrite(W5100_RESET_PIN, LOW);
delay(100);
digitalWrite(W5100_RESET_PIN, HIGH);
delay(1000);

  Ethernet.begin(mac, ip);  // initialize Ethernet device
  server.begin();           // start to listen for clients






}

void loop()
{
  
 int html;
  
 EthernetClient client = server.available();  // try to get client
 
  if (client) {  // got client?
  
    boolean currentLineIsBlank = true;
    while (client.connected()) {
      if (client.available()) {   // client data available to read
     
        char c = client.read(); // read 1 byte (character) from client
        // limit the size of the stored received HTTP request
        // buffer first part of HTTP request in HTTP_req array (string)
        // leave last element in array as 0 to null terminate string (REQ_BUF_SZ - 1)
        if (req_index < (REQ_BUF_SZ - 1)) {
          HTTP_req[req_index] = c;          // save HTTP request character
          req_index++;
        }
        // last line of client request is blank and ends with \n
        // respond to client only after last line received
        if (c == '\n' && currentLineIsBlank) {
          // send a standard http response header
          client.println("HTTP/1.1 200 OK");
          // remainder of header follows below, depending on if
          // web page or XML page is requested
          // Ajax request - send XML file
          if (StrContains(HTTP_req, "ajax_inputs")) {
            // send rest of HTTP header
            client.println("Content-Type: text/xml");
            client.println("Connection: keep-alive");
            client.println();
            SetLEDs();
            // send XML file containing input states
            XML_response(client);
          }
          else {  // web page request
            // send rest of HTTP header
            client.println("Content-Type: text/html");
            client.println("Connection: keep-alive");
            client.println();
            // send web page
            digitalWrite(SD_CHIP_SELECT_PIN, LOW);
            webFile = SD.open("index.htm");        // open web page file
                if (webFile) {
              while(webFile.available()) {
               client.write(webFile.read()); // send web page to client
              }
              webFile.close(); // Try keeping the file in memory instead
             digitalWrite(SD_CHIP_SELECT_PIN, HIGH);
            } 
          }
          // display received HTTP request on serial port
          
         //Serial.print(HTTP_req); // comment this out to see if it improves reliability
         
         
          // reset buffer index and all buffer elements to 0
          req_index = 0;
          StrClear(HTTP_req, REQ_BUF_SZ);
          break;
        }
        // every line of text received from the client ends with \r\n
        if (c == '\n') {
          // last character on line of received text
          // starting new line with next character read
          currentLineIsBlank = true;
        } 
        else if (c != '\r') {
          // a text character was received from client
          currentLineIsBlank = false;
        }
      } // end if (client.available())
    } // end while (client.connected())
    delay(1);      // give the web browser time to receive the data
    client.stop(); // close the connection
  } // end if (client)
}


// checks if received HTTP request is switching on/off LEDs
// also saves the state of the LEDs
void SetLEDs(void)
{
  // LED 1 (pin 6)
  if (StrContains(HTTP_req, "LED1=1")) {
    LED_state[0] = 1;  // save LED state
    digitalWrite(6, HIGH);
  }
  else if (StrContains(HTTP_req, "LED1=0")) {
    LED_state[0] = 0;  // save LED state
    digitalWrite(6, LOW);
  }
  // LED 2 (pin 7)
  if (StrContains(HTTP_req, "LED2=1")) {
    LED_state[1] = 1;  // save LED state
    digitalWrite(7, HIGH);
  }
  else if (StrContains(HTTP_req, "LED2=0")) {
    LED_state[1] = 0;  // save LED state
    digitalWrite(7, LOW);
  }
  // LED 3 (pin 8)
  if (StrContains(HTTP_req, "LED3=1")) {
    LED_state[2] = 1;  // save LED state
    digitalWrite(8, HIGH);
  }
  else if (StrContains(HTTP_req, "LED3=0")) {
    LED_state[2] = 0;  // save LED state
    digitalWrite(8, LOW);
  }
  // LED 4 (pin 9)
  if (StrContains(HTTP_req, "LED4=1")) {
    LED_state[3] = 1;  // save LED state
    digitalWrite(9, HIGH);
  }
  else if (StrContains(HTTP_req, "LED4=0")) {
    LED_state[3] = 0;  // save LED state
    digitalWrite(9, LOW);
  }
  if (StrContains(HTTP_req, "OP1B=")) {  
      
    char *req = HTTP_req;
    char *ptr = strstr(req, "OP1B=");
    //Serial.print("pointer: ");Serial.println(ptr);
    if(ptr){
       int val;
        sscanf(ptr, "OP1B=%i", &val);
        printf("%i\n", val);
        Serial.print("Integer in string: ");Serial.println(val);
        pwmWrite(3, val);
        
        output1_brightness = val;
        
    }

    }

   
  } 

  


// send the XML file with analog values, switch status
//  and LED status
void XML_response(EthernetClient cl)
{
  int analog_val;            // stores value read from analog inputs
  int count;                 // used by 'for' loops
  int sw_arr[] = { 2, 5  };  // pins interfaced to switches

  cl.print("<?xml version = \"1.0\" ?>");
  cl.print("<inputs>");
  // read analog inputs
  for (count = 2; count <= 5; count++) { // A2 to A5
    analog_val = analogRead(count);
    cl.print("<analog>");
    cl.print(analog_val);
    cl.println("</analog>");
  }
  // read switches
  for (count = 0; count < 2; count++) {
    cl.print("<switch>");
    if (digitalRead(sw_arr[count])) {
      cl.print("ON");
    }
    else {
      cl.print("OFF");
    }
    cl.println("</switch>");
  }
  // checkbox LED states
  // LED1
  cl.print("<LED>");
  if (LED_state[0]) {
    cl.print("checked");
  }
  else {
    cl.print("unchecked");
  }
  cl.println("</LED>");
  // LED2
  cl.print("<LED>");
  if (LED_state[1]) {
    cl.print("checked");
  }
  else {
    cl.print("unchecked");
  }
  cl.println("</LED>");
  // button LED states
  // LED3
  cl.print("<LED>");
  if (LED_state[2]) {
    cl.print("on");
  }
  else {
    cl.print("off");
  }
  cl.println("</LED>");
  // LED4
  cl.print("<LED>");
  if (LED_state[3]) {
    cl.print("on");
  }
  else {
    cl.print("off");
  }
  cl.println("</LED>");

//read output 1

  cl.print("<op1>");         
  cl.print(output1_brightness);
  cl.println("</op1>");
  
  cl.print("<op1>"); 
  cl.print(output1_pulsewidth);
  cl.println("</op1>"); 
 
  cl.print("<op1>"); 
  cl.print(output1_pulsedelay);
  cl.println("</op1>");
  
 cl.print("<RDY>");
 cl.print("YES");
 cl.println("</RDY>");
  
  cl.print("</inputs>");
}

// sets every element of str to 0 (clears array)
void StrClear(char *str, char length)
{
  for (int i = 0; i < length; i++) {
    str[i] = 0;
  }
}

// searches for the string sfind in the string str
// returns 1 if string found
// returns 0 if string not found
char StrContains(char *str, char *sfind)
{
  char found = 0;
  char index = 0;
  char len;

  len = strlen(str);

  if (strlen(sfind) > len) {
    return 0;
  }
  while (index < len) {
    if (str[index] == sfind[found]) {
      found++;
      if (strlen(sfind) == found) {
        return 1;
      }
    }
    else {
      found = 0;
    }
    index++;
  }

  return 0;
}


