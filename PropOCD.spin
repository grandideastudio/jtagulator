{{
+-------------------------------------------------+
| OpenOCD Binary Protocol                         |
| Interface Object                                |
|                                                 |
| Authors: Ben Gardiner & Joe Grand               |                     
| Copyright (c) 2020 Ben Gardiner & Joe Grand     |
|                                                 |
| Distributed under a Creative Commons            |
| Attribution 3.0 United States license           |
| http://creativecommons.org/licenses/by/3.0/us/  |
+-------------------------------------------------+

Program Description:

This object provides the low-level communication interface for OpenOCD. It emulates
the binary protocol used by the Bus Pirate (http://dangerousprototypes.com/docs/Bus_Pirate#JTAG
and https://github.com/DangerousPrototypes/Bus_Pirate/blob/master/Firmware/OpenOCD.c)

}}
   
   
CON
  ' Serial terminal
  BaudRate      = 115_200                                             
  RxPin         = |<31                                              
  TxPin         = |<30

  ' Control characters
  CAN   = 24  ''CAN: Cancel (Ctrl-X)
                       
  MAX_INPUT_LEN                 = 5      ' OpenOCD commands are five bytes

  MAX_RX_DELAY_MS               = 100    ' Wait time (in ms) for the each byte in commands to be sent before aborting
 
  CMD_RESET                     = $00    ' reset
  CMD_RUN                       = $01    ' start capture or arm trigger
  CMD_QUERY_ID                  = $02    ' query device identification

  
VAR
  byte vCmd[MAX_INPUT_LEN + 1]  ' Buffer for command input string

  
OBJ
  g             : "JTAGulatorCon"      ' JTAGulator global constants
  u             : "JTAGulatorUtil"     ' JTAGulator general purpose utilities
  pst           : "JDCogSerial"        ' UART/Asynchronous Serial communication engine (Carl Jacobs, http://obex.parallax.com/object/298)
  jtag          : "PropJTAG"           ' JTAG/IEEE 1149.1 low-level methods


PUB Go(tdi, tdo, tck, tms, tckspeed)
  pst.Start(RxPin, TxPin, BaudRate)            ' Configure UART

  u.LEDRed                                     ' We are initialized and ready to go
  u.TXSEnable                                  ' Enable level shifter outputs
  u.Set_Pins_High(0, g#MAX_CHAN)               ' In case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#
  jtag.Config(tdi, tdo, tck, tms, tckspeed)    ' Configure JTAG
  
  ' Start command receive/process cycle
  repeat
    vCmd[0]:=pst.Rx

    case vCmd[0]
      CAN:          ' If Ctrl-X (CAN) character received, exit OpenOCD mode
        pst.Stop      ' Stop serial communications
        return        ' Go back to main JTAGulator mode

      CMD_QUERY_ID:
        pst.Str(@ID)

    
DAT             

              ORG
ID            byte "1ALS", 0