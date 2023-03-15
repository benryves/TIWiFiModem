#ifndef _MODEM_H
   #define _MODEM_H

   #define DEBUG                 0
   #define DEFAULT_SPEED         1200

   #define RING_INTERVAL         1500
   #define MAX_CMD_LEN           256
   #define TX_BUF_SIZE           256
   #define ESC_CHAR              '+'
   #define ESC_COUNT             3
   #define GUARD_TIME            1000
   #define MAGIC_NUMBER          0x4321
   #define MAX_SSID_LEN          32
   #define MAX_WIFI_PWD_LEN      64
   #define DEFAULT_LISTEN_PORT   6400
   #define TELNET_PORT           23
   #define HTTP_PORT             80
   #define SPEED_DIAL_SLOTS      10
   #define MAGIC_ANSWER_RINGS    3
   #define MAX_ALIAS_LEN         16
   #define MAX_SPEED_DIAL_LEN    50
   #define MAGIC_SPEED_LEN       7
   #define MAX_MDNSNAME_LEN      80
   #define MAX_BUSYMSG_LEN       80
   #define MAX_PWD_LEN           80
   #define PASSWORD_TIME         60000
   #define PASSWORD_TRIES        3
   #define MAX_AUTOEXEC_LEN      80
   #define MAX_TERMINAL_LEN      80
   #define MAX_LOCATION_LEN      80

   #define NUL  '\x00'
   #define CTLC '\x03'
   #define BS   '\x08'
   #define LF   '\x0A'
   #define CR   '\x0D'
   #define DEL  '\x7F'

   #define NO_TELNET   ((uint8_t)0)
   #define REAL_TELNET ((uint8_t)1)
   #define FAKE_TELNET ((uint8_t)2)

   // Telnet codes
   #define VLSUP     ((uint8_t)0)
   #define VLREQ     ((uint8_t)1)
   #define LOC       ((uint8_t)23)
   #define TTYPE     ((uint8_t)24)
   #define NAWS      ((uint8_t)31)
   #define TSPEED    ((uint8_t)32)
   #define LFLOW     ((uint8_t)33)
   #define LINEMODE  ((uint8_t)34)
   #define XDISPLOC  ((uint8_t)35)
   #define NEW_ENVIRON ((uint8_t)39)
   #define COMPRESS  ((uint8_t)85)
   #define COMPRESS2 ((uint8_t)86)
   #define BINARY    ((uint8_t)0)
   #define ECHO      ((uint8_t)1)
   #define SUP_GA    ((uint8_t)3)
   #define SE        ((uint8_t)240)
   #define DM        ((uint8_t)242)
   #define AYT       ((uint8_t)246)
   #define SB        ((uint8_t)250)
   #define WILL      ((uint8_t)251)
   #define WONT      ((uint8_t)252)
   #define DO        ((uint8_t)253)
   #define DONT      ((uint8_t)254)
   #define IAC       ((uint8_t)255)

   #define NIST_HOST "time.nist.gov"
   #define NIST_PORT 13

#endif
