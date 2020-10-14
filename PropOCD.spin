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
                       
  'MAX_INPUT_LEN                 = 3      ' OpenOCD commands are three bytes maximum
  
  MAX_RX_DELAY_MS               = 100    ' Wait time (in ms) for the each byte in commands to be sent before aborting
  
  CMD_UNKNOWN                   = $00    ' unknown command
  CMD_PORT_MODE                 = $01    ' port type
  CMD_FEATURE                   = $02    ' hardware-specific configuration
  CMD_READ_ADCS                 = $03    ' read A/Ds
  'CMD_TAP_SHIFT                 = $04    ' shift TAP (old protocol)
  CMD_TAP_SHIFT                 = $05    ' shift TAP
  CMD_ENTER_OOCD                = $06    ' enter OCD mode
  CMD_UART_SPEED                = $07    ' UART speed select
  CMD_JTAG_SPEED                = $08    ' JTAG speed select
  CMD_RESET                     = $0F    ' reset (from buspirate_jtag_reset in OpenOCD buspirate.c)
  
  FEATURE_LED                   = $01    ' LED on/off
  FEATURE_VREG                  = $02    ' voltage regulator on/off
  FEATURE_TRST                  = $04    ' set TRST logic state
  FEATURE_SRST                  = $08    ' set SRST logic state
  FEATURE_PULLUP                = $10    ' pull up resistors on/off

  SERIAL_NORMAL                 = 0
  SERIAL_FAST                   = 1      ' ~1 MHz

  MODE_HIZ                      = 0      ' high impedance (hi Z), input  
  MODE_JTAG                     = 1      ' push-pull, output
  MODE_JTAG_OD                  = 2      ' open drain, output

  MAX_BIT_SEQUENCES             = 8192   ' Maximum number of bit sequences allowed per CMD_TAP_SHIFT

  
VAR
  'byte vCmd[MAX_INPUT_LEN + 1]  ' Buffer for command input string
  byte vCmd[(MAX_BIT_SEQUENCES / 4) + 1]

  
OBJ
  g             : "JTAGulatorCon"      ' JTAGulator global constants
  u             : "JTAGulatorUtil"     ' JTAGulator general purpose utilities
  pst           : "JDCogSerial"        ' UART/Asynchronous Serial communication engine (Carl Jacobs, http://obex.parallax.com/object/298)
  jtag          : "PropJTAG"           ' JTAG/IEEE 1149.1 low-level methods


PUB Go(tdi, tdo, tck, tms) | ctr
  pst.Start(RxPin, TxPin, BaudRate)            ' Configure UART

  u.LEDRed                                     ' We are initialized and ready to go
  u.TXSEnable                                  ' Enable level shifter outputs
  u.Set_Pins_High(0, g#MAX_CHAN)               ' In case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#
  jtag.Config(tdi, tdo, tck, tms)              ' Configure JTAG
  
  ' Start command receive/process cycle
  repeat
    vCmd[0]:=pst.Rx

    case vCmd[0]
      CAN:          ' If Ctrl-X (CAN) character received, exit OpenOCD mode
        pst.Stop      ' Stop serial communications
        return        ' Go back to main JTAGulator mode

      'the 'short' commands follow; all are 1 byte, no parameters

      CMD_UNKNOWN:
        pst.Str(@BBIO)
        
      CMD_ENTER_OOCD:
        pst.Str(@OCD)
        
      CMD_READ_ADCS:     ' Not supported
        pst.Tx(CMD_READ_ADCS)    ' Send acknowledgement
        pst.Tx(8)                ' Number of bytes
        repeat 8
          pst.Tx(0)

      'remaining commands are 'long' commands, which take 1 or more parameters

      CMD_PORT_MODE:     ' Not supported
        if (GetMoreParamBytes(1) == -1)
          next
        
        case vCmd[1]
          MODE_HIZ:
            next

          MODE_JTAG:
            next
             
          MODE_JTAG_OD:
            next

      CMD_FEATURE:
        if (GetMoreParamBytes(2) == -1) 
          pst.Tx(0)
          next

        case vCmd[1]
          FEATURE_LED:
            next
          
          FEATURE_VREG:   
            next
            
          FEATURE_TRST:   
            next
            
          FEATURE_SRST:   
            next
            
          FEATURE_PULLUP:
            next           

      CMD_JTAG_SPEED:    ' Not supported
        if (GetMoreParamBytes(2) == -1)
          next

      CMD_UART_SPEED:    ' Not supported
        if (GetMoreParamBytes(1) == -1)
          pst.Tx(0)
          next

        pst.Tx(CMD_UART_SPEED)   ' Send acknowledgement
        pst.Tx(SERIAL_NORMAL)
            
      CMD_TAP_SHIFT:
        if (++ctr // 6) == 0
          !outa[g#LED_G]          ' Toggle LED between red and yellow
        
        if (GetMoreParamBytes(2) == -1)
          pst.Tx(0)

        Do_Tap_Shift

      CMD_RESET:
        next
      
      other:             ' Invalid byte
        pst.Tx(0)
        

PRI Do_Tap_Shift | num_sequences, num_bytes, bits, value, i
   ' based on HydraBus implementation of Bus Pirate binary protocol
   ' https://github.com/hydrabus/hydrafw/blob/master/src/hydrabus/hydrabus_mode_jtag.c

   ' calculate number of requested bit sequences
   num_sequences := vCmd[1]
   num_sequences <<= 8
   num_sequences |= vCmd[2]

   if num_sequences > MAX_BIT_SEQUENCES    ' Upper bounds check
     num_sequences := MAX_BIT_SEQUENCES
     
   pst.Tx(CMD_TAP_SHIFT)   ' Send acknowledgement
   pst.Tx(vCmd[1])
   pst.Tx(vCmd[2])

   ' calculate number of bytes to read
   num_bytes := ((num_sequences + 7) / 8) * 2

   ' get bytes from OpenOCD with the TDI and TMS data to shift into target
   if (GetMoreParamBytes(num_bytes) == -1)
     pst.Tx(0)
     return  ' exit if we don't receive the correct number of bytes 

   i := 0
   repeat while (num_sequences > 0)
     if (num_sequences > 8)    ' Do 8 bits at a time until the last set
       bits := 8
     else
       bits := num_sequences

     value := OpenOCD_Shift(vCmd[i+1] {TDI}, vCmd[i+2] {TMS}, bits) 
     pst.Tx(value & $FF)
     
     i += 2
     num_sequences -= bits
   

PRI OpenOCD_Shift(ocd_tdi, ocd_tms, num_bits) : ocd_tdo | num  ' Shift data from OpenOCD into target and receive result
  num := num_bits        
  
  repeat while (num_bits > 0)
    if (ocd_tms & 1)
      jtag.TMS_High
    else
      jtag.TMS_Low

    if (ocd_tdi & 1)
      jtag.TDI_High
    else
      jtag.TDI_Low   

    ocd_tdo <<= 1
    ocd_tdo |= jtag.TDO_Read
    
    ocd_tdi >>= 1       ' Shift to the next bit in the sequence
    ocd_tms >>= 1
    num_bits -= 1       ' Adjust number of remaining bits

  ocd_tdo ><= num   ' Bitwise reverse since LSB came in first (we want MSB to be first)

   
PRI GetMoreParamBytes(num) : val | i
  repeat i from 1 to num
    if (vCmd[i]:=pst.RxTime(MAX_RX_DELAY_MS)) < 0
      val:=-1

      
DAT
              ORG
BBIO          byte "BBIO1", 0
OCD           byte "OCD1", 0
