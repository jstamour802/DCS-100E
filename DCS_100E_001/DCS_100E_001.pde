
//extern "C" {
#include <stdlib.h>
//}
#include <string.h>
#include <SPI.h>
#include <Ethernet.h>
#include <SD.h>

#define REQ_BUF_SZ  100    // size of buffer used to capture HTTP requests
//#include <stdio.h>

/* --------- Device Info ----------------------------------------------------------------*/
#define DEVICE_NAME "DCS-100E"
#define FIRMWARE_VER "FW070906_001"

/* --------------------------------------------------------------------------------------*/
/* ---------  CI ( command interface) ---------------------------------------------------*/
#define MAX_COMMAND_LEN             (10)
#define MAX_PARAMETER_LEN           (10)
#define COMMAND_TABLE_SIZE          (16)
#define TO_UPPER(x) (((x >= 'a') && (x <= 'z')) ? ((x) - ('a' - 'A')) : (x))

char gCommandBuffer[MAX_COMMAND_LEN + 1];
char gParamBuffer[MAX_PARAMETER_LEN + 1];
long gParamValue;


typedef struct {
  char const    *name;
  void          (*function)(void);
} command_t;

//the list of commands
command_t const gCommandTable[COMMAND_TABLE_SIZE] = {

  //***standard SCPI commands
  
  {"*IDN?",     get_device_ID, },
 // {"*RST",      reset_device, },
 // {"SYST:ERR?", get_syst_err,  },
 // {"CLS",       clear_syst_err, },
 // {"*CFG?",     get_config_info,},	     // returns configuration info, current settings, etc..
  
  //***manufacturing only commands
 
  
  //*** User Commands - non SCPI standard 
 
  {NULL,      NULL }

};


/* --------------------------------------------------------------------------------------*/
/* --------- TCP-IP/UDP Default setup----------------------------------------------------*/
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
IPAddress ip(192, 168, 24, 177);                     // IP address, may need to change depending on network
EthernetServer server(80);                           // create a server at port 80
char HTTP_req[REQ_BUF_SZ] = {0};                     // buffered HTTP request stored as null terminated string
char req_index = 0;                                  // index into HTTP_req buffer
//todo add UDP

/* ---------------------------------------------------------------------------------------*/
/*---------- SD Card Setup----------------------------------------------------------------*/
const int sdchipSelect = SD_CHIP_SELECT_PIN;
File webFile;                                        // the web page file on the SD card

/* ---------------------------------------------------------------------------------------*/
/*---------- Output Settings Variables ---------------------------------------------------*/
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

int previousMillis = 0;        // will store the last time the LED was updated
int interval = 1000; 

boolean LED_state[4] = {0};                          // stores the states of the LEDs

//---------------------------------------------------------------------------------------//
/*~~~~~~~~~~~~~~~~~~~~~~~~Begin Program Setup ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
void setup()
{
  
  #ifdef MAPLE
Serial.begin(BPS_115200);       // for debugging
#endif 

#ifdef ARDUINO
Serial.begin(115200);
#endif

pinMode(BOARD_LED_PIN, OUTPUT);

  pinMode(3, PWM);
  pinMode(2, INPUT);
  pinMode(5, INPUT);
  pinMode(6, OUTPUT);
  pinMode(7, OUTPUT);
  pinMode(8, OUTPUT);
  pinMode(9, OUTPUT);


  // disable w5100 SPI while starting SD
//  pinMode(BOARD_SPI2_NSS_PIN,OUTPUT);
//  digitalWrite(BOARD_SPI2_NSS_PIN,HIGH);
  

  
//    // initialize SD card
////  Serial.println("Initializing SD card...");
//  if (!SD.begin(sdchipSelect)) {
//    Serial.println("ERROR!");
//    return;    // init failed
//  }
//  Serial.println("SUCCESS.");
//  // check for index.htm file
//  if (!SD.exists("index.htm")) {
////    Serial.println("ERROR - no index.htm!");
//    return;  // can't find index file
//  }
////  Serial.println("SUCCESS - Found index.htm file.");
 
  

 // disable SD SPI
//  pinMode(SD_CHIP_SELECT_PIN, OUTPUT);
//  digitalWrite(SD_CHIP_SELECT_PIN, HIGH);


pinMode(W5100_RESET_PIN, OUTPUT);
digitalWrite(W5100_RESET_PIN, LOW);
delay(100);
digitalWrite(W5100_RESET_PIN, HIGH);
delay(1000);

  Ethernet.begin(mac, ip);  // initialize Ethernet device
  server.begin();           // start to listen for clients






}  // End of Setup()
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
//****************************************************************************************//
//****************************************************************************************//
//~~~~~~~~~~~~~~~~~~~~~~~~Main Loop~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
void loop()
{
  
    if (millis() - previousMillis > interval) {
        // Save the last time you blinked the LED
        previousMillis = millis();

        // If the LED is off, turn it on, and vice-versa:
        toggleLED();
    }
    
    
  
 int html;
  
 EthernetClient client = server.available();  // try to get client
 
  //~~~~~~~~~~~~~~~~~~~ Check for Clients and Serve the webpage from the SD Card~~~~~~~~~~// 
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
  //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  
} // End of Loop()




//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//
//****************************************************************************************//
//****************************************************************************************//
//~~~~~~~~~~~~~~~~~~~~~~~~FUNCTIONS~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~//

/**********************************************************************
 *
 * Function:    SetLEDs
 *
 * Description: checks if received HTTP request is changing values and saves the state of 
 *              values if changed
 *             
 *
 * Notes:     
 *
 * Returns:     
 *
 **********************************************************************/

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

  

/**********************************************************************
 *
 * Function:    XML_Response
 *
 * Description: sends an XML response to the web server to update forms on the web page
 *              
 *             
 *
 * Notes:      
 *             
 * Returns:     None.
 *
 **********************************************************************/
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


/**********************************************************************
 *
 * Function:    StrClear
 *
 * Description: sets every element of str to 0 (clears array)
 *              
 *             
 *
 * Notes:      
 *             
 * Returns:     None.
 *
 **********************************************************************/

void StrClear(char *str, char length)
{
  for (int i = 0; i < length; i++) {
    str[i] = 0;
  }
}




/**********************************************************************
 *
 * Function:    StrContains
 *
 * Description: searches for the string sfind in the string str
 *              
 *             
 *
 * Notes:      
 *             
 * Returns:     1 if string found
 *              0 if string not found
 *
 **********************************************************************/

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

/**********************************************************************
 *
 * Function:    get_device_ID
 *
 * Description: prints device name and firmware revision
 *             
 *
 * Notes:     
 *
 * Returns:     
 *
 **********************************************************************/

void get_device_ID(void)
{
Serial.println(DEVICE_NAME);
Serial.println(FIRMWARE_VER);
	//todo add code here
}


/**********************************************************************
 *
 * Function:    check_serial
 *
 * Description: listens for commands sent to the controller via serial
 *             
 *
 * Notes:     
 *
 * Returns:     
 *
 **********************************************************************/
void check_serial(void){
  char rcvChar;
  int  bCommandReady = false;

  if (Serial.available() > 0) {
    /* Wait for a character. */
    rcvChar = Serial.read();

    /* Echo the character back to the serial port. */
    Serial.print(rcvChar);

    /* Build a new command. */
    bCommandReady = cliBuildCommand(rcvChar);
  }

  /* Call the CLI command processing routine to verify the command entered 
   * and call the command function; then output a new prompt. */
  if (bCommandReady == true) {
    bCommandReady = false;
    cliProcessCommand();
    Serial.print('>');
  }
 }
/**********************************************************************
 *
 * Function:    cliBuildCommand
 *
 * Description: Put received characters into the command buffer or the
 *              parameter buffer. Once a complete command is received
 *              return true.
 *
 * Notes:       
 *
 * Returns:     true if a command is complete, otherwise false.
 *
 **********************************************************************/

int cliBuildCommand(char nextChar) {
  static uint8_t idx = 0; //index for command buffer
  static uint8_t idx2 = 0; //index for parameter buffer
  enum { COMMAND, PARAM };
  static uint8_t state = COMMAND;
  /* Don't store any new line characters or spaces. */
  if ((nextChar == '\n') || (nextChar == ' ') || (nextChar == '\t') || (nextChar == '\r'))
    return false;

  /* The completed command has been received. Replace the final carriage
   * return character with a NULL character to help with processing the
   * command. */
  //if (nextChar == '\r')
  if (nextChar == ';') {
    gCommandBuffer[idx] = '\0';
    gParamBuffer[idx2] = '\0';
    idx = 0;
    idx2 = 0;
    state = COMMAND;
    return true;
  }

  if (nextChar == ',') {
    state = PARAM;
    return false;
  }

  if (state == COMMAND) {
    /* Convert the incoming character to upper case. This matches the case
     * of commands in the command table. Then store the received character
     * in the command buffer. */
    gCommandBuffer[idx] = TO_UPPER(nextChar);
    idx++;

    /* If the command is too long, reset the index and process
     * the current command buffer. */
    if (idx > MAX_COMMAND_LEN) {
      idx = 0;
       return true;
    }
  }
  if (state == PARAM) {
    /* Store the received character in the parameter buffer. */
    gParamBuffer[idx2] = nextChar;
    idx2++;

    /* If the command is too long, reset the index and process
     * the current parameter buffer. */
    if (idx > MAX_PARAMETER_LEN) {
      idx2 = 0;
      return true;
    }
  }

  return false;
}



/**********************************************************************
 *
 * Function:    cliProcessCommand
 *
 * Description: Look up the command in the command table. If the
 *              command is found, call the command's function. If the
 *              command is not found, output an error message.
 *
 * Notes:       
 *
 * Returns:     None.
 *
 **********************************************************************/
void cliProcessCommand(void)
{
  int bCommandFound = false;
  int idx;

  /* Convert the parameter to an integer value. 
   * If the parameter is empty, gParamValue becomes 0. */
  gParamValue = strtol(gParamBuffer, NULL, 0);

  /* Search for the command in the command table until it is found or
   * the end of the table is reached. If the command is found, break
   * out of the loop. */
  for (idx = 0; gCommandTable[idx].name != NULL; idx++) {
  if (strcmp(gCommandTable[idx].name, gCommandBuffer) == 0) {
      bCommandFound = true;
      break;
    }
  }

  /* If the command was found, call the command function. Otherwise,
   * output an error message. */
  if (bCommandFound == true) {
    Serial.println();
    (*gCommandTable[idx].function)();
  }
  else {
    Serial.println();
    Serial.println("Command not found.");
  }
}

