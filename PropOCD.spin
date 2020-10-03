{{
+-------------------------------------------------+
| OpenOCD Binary Protocol                         |
| Interface Object                                |
|                                                 |
| Authors: Ben Gardiner & Joe Grand               |                     
| Copyright (c) 2020                              |
|                                                 |
| Distributed under a Creative Commons            |
| Attribution 3.0 United States license           |
| http://creativecommons.org/licenses/by/3.0/us/  |
+-------------------------------------------------+

Program Description:

This object provides the low-level communication interface for the SUMP-compatible
logic analyzer functionality (http://sigrok.org/wiki/Openbench_Logic_Sniffer#Protocol
and http://dangerousprototypes.com/docs/Logic_Analyzer_core:_Background#2.3_The_SUMP_Protocol)

TODOs:
* 

}}
   
   
CON
  ' Serial terminal
  BaudRate      = 115_200                                             
  RxPin         = |<31                                              
  TxPin         = |<30

  ' Control characters
  CAN   = 24  ''CAN: Cancel (Ctrl-X)
                       
  MAX_INPUT_LEN                 = 5                    'SUMP long commands are five bytes

  MAX_RX_DELAY_MS               = 100                  'Wait time (in ms) for the each byte in long commands to be sent before aborting
 
  CMD_RESET                     = $00    ' reset
  CMD_RUN                       = $01    ' start capture or arm trigger
  CMD_QUERY_ID                  = $02    ' query device identification

  ' TEMP
  LF    = 10  ''LF: Line Feed
  CR    = 13  ''CR: Carriage Return  
VAR
  long Cog                      ' Used to store ID of newly started cog

  byte vCmd[MAX_INPUT_LEN + 1]  ' Buffer for command input string
  long larg

  
OBJ
  g             : "JTAGulatorCon"      ' JTAGulator global constants
  u             : "JTAGulatorUtil"     ' JTAGulator general purpose utilities
  pst           : "JDCogSerial"        ' UART/Asynchronous Serial communication engine (Carl Jacobs, http://obex.parallax.com/object/298)
  jtag          : "PropJTAG"           ' JTAG/IEEE 1149.1 low-level methods

  ' TEMP
    rr            : "RealRandom"         ' Random number generation (Chip Gracey, https://github.com/parallaxinc/propeller/tree/master/libraries/community/p1/All/Real%20Random) 

PUB Go(tdi, tdo, tck, tms, tckspeed) | i, dataIn, dataOut, num
  pst.Start(RxPin, TxPin, BaudRate)            ' Configure UART

  u.LEDRed                                     ' We are initialized and ready to go
  u.TXSEnable                                  ' Enable level shifter outputs
  u.Set_Pins_High(0, g#MAX_CHAN)               ' In case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#
  jtag.Config(tdi, tdo, tck, tms, tckspeed)    ' Configure JTAG
  
  ' Start command receive/process cycle
  repeat
    vCmd[0]:=pst.Rx

    case vCmd[0]
      CAN:          ' If Ctrl-X (CAN) character received, exit SUMP mode
        pst.Stop      ' Stop serial communications
        return        ' Go back to main JTAGulator mode
    
      'the 'short' commands follow; all are 1 byte, no parameters

      CMD_RESET:
        u.LEDRed

      CMD_QUERY_ID:
        pst.Str(@ID)

      other:   ' Run BYPASS Test for testing purposes
        num := jtag.Detect_Devices                 ' Get number of devices in the chain
        pst.Str(String(CR, LF))
        pst.Str(String("Number of devices detected: "))
        pst.Tx(num + $30)
        dataIn := rr.random                         ' Get 32-bit random number to use as the BYPASS pattern
        dataOut := jtag.Bypass_Test(num, dataIn)    ' Run the BYPASS instruction 
        if (dataIn == dataOut)
          pst.Str(String(CR, LF, "Match!"))
        else
          pst.Str(String(CR, LF, "No Match!"))    

    
DAT             

              ORG
ID            byte "1ALS", 0

