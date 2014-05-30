//main.cpp

#include <string.h>

#include <wiz820io.h>
#include <wiz_defines.h>
#include <telnet.h>
#include <Types.h>
#include <socket.h>
#include <abst_wiz.h>



static char mac[6] = {0x0A, 0x1B, 0x3C, 0x4D, 0x5E, 0x6F};

static char local_ip[4] = {192, 168, 100, 2};
static char subnet[4] = {255, 255, 255, 0};
static char gateway[4] = {192, 168, 100, 1};


HardwareSPI spi2(2);
wiz820io wiz;
Telnet telnet;

//user functions
static void toggle_led(const char * args, const void * user_data, const char *out_buffer){
  int led_value = 0;
  toggleLED();
  led_value = digitalRead(BOARD_LED_PIN);
  snprintf((char *)out_buffer, TF_OUT_BUF_SIZE, "LED is %d\r\n", led_value);
}

static void get_led_state(const char * args, const void * user_data, const char *out_buffer){
  int led_value = digitalRead(BOARD_LED_PIN);
  snprintf((char *)out_buffer, TF_OUT_BUF_SIZE, "LED is %d\r\n", led_value);
}

static void set_led_state(const char * args, const void * user_data, const char *out_buffer){
  int led_value = 0;
  sscanf(args, "%d", &led_value); 
  Serial3.print("args: ");
  Serial3.println(args);
  Serial3.print("value: ");
  Serial3.println(led_value);
  digitalWrite(BOARD_LED_PIN, led_value);
}

void setup(){
  Serial3.begin(115200);
  pinMode(BOARD_BUTTON_PIN, INPUT);
  pinMode(BOARD_LED_PIN, OUTPUT);
  
  Serial3.println();
  Serial3.println("Starting WizzEthernet Main Project");
  wiz.begin(&spi2);	
  Serial3.println("Opened up WizzEthernet MAC and PHY");

  //pre initialize MAC stuff

  //set all the pins to values
  //wiz.set_interrupt_pin(9);
  //wiz.set_reset_pin(7);
  //wiz.set_power_pin(8);

	
  Serial3.println("Initializing the MAC and PHY layer");
  wiz.init_mac();
  Serial3.println("Initialized");
	
  //wiz.set_timeout_millis(6000);
  //wiz.set_timeout_retries(3);
	
  wiz.set_ip(&local_ip[0]);
  wiz.set_gateway(&gateway[0]);
  wiz.set_subnet_mask(&subnet[0]);
  wiz.set_mac_addr(&mac[0]);

  telnet.begin(&wiz, 23, &Serial3);

  Serial3.println("Generated a new Telnet instance");

  telnet.add_command(
    "TOGGLE_LED", 
    "Toggle the LED",
    toggle_led, 
    NULL);

  telnet.add_command(
    "GET_LED", 
    "Get the LED state",
    get_led_state, 
    NULL);

  telnet.add_command(
    "SET_LED",
    "Sets the state of the LED format: set_led 1",
    set_led_state,
    NULL);

}

void loop(){
 
 telnet.periodic();
 delay(10);
 
}
