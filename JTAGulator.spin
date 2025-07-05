{{
+-------------------------------------------------+
| JTAGulator                                      |
|                                                 |
| Author: Joe Grand                               |
| Copyright (c) 2013-2023 Grand Idea Studio, Inc. |
| Web: http://www.grandideastudio.com             |
|                                                 |
| Distributed under a Creative Commons            |
| Attribution 3.0 United States license           |
| http://creativecommons.org/licenses/by/3.0/us/  |
+-------------------------------------------------+

Program Description:

The JTAGulator is a hardware tool that assists in identifying on-chip
debug/programming interfaces from test points, vias, component pads,
and/or connectors on a target device.

Refer to the project page for more details:

http://www.jtagulator.com

Each interface object contains the low-level routines and operational details
for that particular on-chip debugging interface. This keeps the main JTAGulator
object a bit cleaner.

Command listing is available in the DAT section at the end of this file.

}}


CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000           ' 5 MHz clock * 16x PLL = 80 MHz system clock speed
  _stack   = 128  '256                 ' Ensure we have this minimum stack space available

  ' Serial terminal
  ' Control characters
  LF     = 10   ' LF: Line Feed
  CR     = 13   ' CR: Carriage Return
  CAN    = 24   ' CAN: Cancel (Ctrl-X)
  QUOTE  = 34   ' Quotation mark


CON
  ' UI
  MAX_LEN_CMD           = 8   ' Maximum length of command string buffer

  ' Target voltage
  VTARGET_IO_MIN        = 14   ' Minimum target I/O voltage (VADJ) (for example, xy = x.yV)
  VTARGET_IO_MAX        = 33   ' Maximum target I/O voltage

  ' JTAG
  NUM_RTCK_ITERATIONS   = 10   ' Number of times to check for RTCK correlation from TCK

  ' UART/Asynchronous Serial
  MAX_LEN_UART_USER     = 34   ' Maximum length of user input string buffer (accounts for hexadecimal input of 16 bytes, \x00112233445566778899AABBCCDDEEFF)
  MAX_LEN_UART_TX       = 16   ' Maximum number of bytes to transmit to target (based on user input string)
  MAX_LEN_UART_RX       = 16   ' Maximum number of bytes to receive from target
  UART_SCAN_DELAY       = 20   ' Time to receive a byte from the target (ms)

  UART_PULSE_DELAY      = 50   ' Time for pulse width detection cog to measure pulse (ms)
  UART_PULSE_COUNT      = 32   ' Number of samples to receive during pulse width detection
  UART_PULSE_ARRAY_L    = 8    ' Range within array of captured pulses to determine minimum width (must be within UART_PULSE_COUNT)
  UART_PULSE_ARRAY_H    = 15

  ' Menu
  MENU_MAIN     = 0    ' Main/Top
  MENU_JTAG     = 1    ' JTAG
  MENU_UART     = 2    ' UART
  MENU_GPIO     = 3    ' General Purpose I/O
  MENU_SWD      = 4    ' Serial Wire Debug (SWD)

  ' EEPROM
  eepromAddress   = $8000       ' Starting address within EEPROM for system/user data storage
  MODE_NORMAL     = 0           ' JTAGulator main mode
  MODE_SUMP       = 1           ' Logic analyzer (OLS/SUMP)
  MODE_OCD        = 2           ' OpenOCD interface

  EEPROM_MODE_OFFSET            = 0
  EEPROM_VTARGET_OFFSET         = 4
  EEPROM_TDI_OFFSET             = 8
  EEPROM_TDO_OFFSET             = 12
  EEPROM_TCK_OFFSET             = 16
  EEPROM_TMS_OFFSET             = 20

  Manufacturer_begin_address    =$8020
  Manufacturer_name_length      =16


VAR                   ' Globally accessible variables
  byte vCmd[MAX_LEN_CMD + 1]           ' Buffer for command input string + \0
  long vBuf[sump#MAX_SAMPLE_PERIODS]   ' Buffer for stack/data transfer (shared across objects)
  long vTargetIO      ' Target I/O voltage
  long vMode          ' JTAGulator operating mode (determined on start-up)

  long jTDI           ' JTAG pins (must stay in this order)
  long jTDO
  long jTCK
  long jTMS
  long jTRST
  long jPinsKnown     ' Parameter for BYPASS_Scan
  long jIgnoreReg     ' Parameter for OPCODE_Discovery
  long jIR            ' Parameters for EXTEST_Scan
  long jDRFill
  long jLoopPause
  long Manufacturer

  long uTXD           ' UART pins (as seen from the target) (must stay in this order)
  long uRXD
  long uBaud
  byte uSTR[MAX_LEN_UART_TX + 1]    ' User input string buffer for UART_Scan + \0
  byte uHex           ' Is user input string ASCII (0) or hex (number of bytes)
  long uPrintable
  long uPinsKnown
  long uWaitDelay     ' Time to wait before checking for a response from the target (ms)
  long uBaudIgnore    ' Parameter for UART_Scan_TXD
  long uLocalEcho     ' Parameter for UART_Passthrough

  long gWriteValue    ' Parameter for Write_IO_Pins

  long swdClk         ' SWD pins (must stay in this order)
  long swdIo
  long swdPinsKnown   ' Are above pins valid?
  long swdFrequency

  long chStart        ' Channel range for the current scan (specified by the user)
  long chEnd

  long pinsLow        ' Bring channels LOW before each permutation attempt (used in scan methods)
  long pinsLowDelay
  long pinsHighDelay

  long idMenu         ' Menu ID of currently active menu


OBJ
  g             : "JTAGulatorCon"          ' JTAGulator global constants
  u             : "JTAGulatorUtil"         ' JTAGulator general purpose utilities
  pst           : "PropSerial"             ' Serial communication for user interface (modified version of built-in Parallax Serial Terminal)
  str           : "jm_strings"             ' String manipulation methods (JonnyMac)
  rr            : "RealRandom"             ' Random number generation (Chip Gracey, https://github.com/parallaxinc/propeller/tree/master/libraries/community/p1/All/Real%20Random)
  pulse         : "PulseWidth"             ' Measure pulse width on specified input pin
  sort          : "sort_dec"               ' Sorting algorithms (Brandon Nimon, https://github.com/parallaxinc/propeller/tree/master/libraries/community/p1/All/Sorting%20Algorithms%20in%20SPIN%20or%20PASM)
  eeprom        : "Basic_I2C_Driver"       ' I2C protocol for boot EEPROM communication (Michael Green, https://github.com/parallaxinc/propeller/tree/master/libraries/community/p1/All/Basic%20I2C%20Driver)
  uart          : "JDCogSerial"            ' UART/Asynchronous Serial communication engine (Carl Jacobs, https://github.com/parallaxinc/propeller/tree/master/libraries/community/p1/All/JDCogSerial)
  pt_in         : "jm_rxserial"            ' UART/Asynchronous Serial receive driver for passthrough (JonnyMac, https://forums.parallax.com/discussion/114492/prop-baudrates)
  pt_out        : "jm_txserial"            ' UART/Asynchronous Serial transmit driver for passthrough (JonnyMac, https://forums.parallax.com/discussion/114492/prop-baudrates)
  jtag          : "PropJTAG"               ' JTAG/IEEE 1149.1 low-level methods
  swd           : "PropSWD"                ' ARM SWD (Serial Wire Debug) low-level functions (Adam Green, https://github.com/adamgreen)
  sump          : "PropSUMP"               ' OLS/SUMP protocol for logic analyzer mode
  ocd           : "PropOCD"                ' OpenOCD binary protocol
  'id            : "IDComparison"           ' Compare ID


PUB main | cmd
  System_Init        ' Initialize system/hardware
  JTAG_Init          ' Initialize JTAG-specific items
  UART_Init          ' Initialize UART-specific items
  GPIO_Init          ' Initialize GPIO-specific items
  SWD_Init           ' Initialize SWD-specific items

  Do_Mode            ' Read EEPROM to determine/select operating mode

  ' Start command receive/process cycle
  repeat
    u.TXSDisable                   ' Disable level shifter outputs (high-impedance)
    u.LEDGreen                     ' Set status indicator to show that we're ready
    Display_Command_Prompt         ' Display command prompt
    pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
    u.LEDRed                            ' Set status indicator to show that we're processing a command

    if (strsize(@vCmd) == 1)       ' Only single character commands are supported...
      cmd := vCmd[0]

      case idMenu
        MENU_MAIN:                    ' Main/Top
          Do_Main_Menu(cmd)

        MENU_JTAG:                    ' JTAG
          Do_JTAG_Menu(cmd)

        MENU_UART:                    ' UART/Asynchronous Serial
          Do_UART_Menu(cmd)

        MENU_GPIO:                    ' General Purpose I/O
          Do_GPIO_Menu(cmd)

        MENU_SWD:                     ' Serial Wire Debug
          Do_SWD_Menu(cmd)

        other:
          idMenu := MENU_MAIN
          Do_Main_Menu(cmd)

    else
      Display_Invalid_Command


PRI Do_Mode | ackbit     ' Read EEPROM to determine/select operating mode
  ' JTAGulator's EEPROM (64KB) is larger than required by the Propeller, so there is 32KB of additional,
  ' unused area available for data storage. Values will not get overwritten when JTAGulator firmware is
  ' re-loaded into the EEPROM.
  ackbit := 0
  ackbit += readLong(eepromAddress + EEPROM_MODE_OFFSET, @vMode)
  ackbit += readLong(eepromAddress + EEPROM_VTARGET_OFFSET, @vTargetIO)

  if ackbit          ' If there's an error with the EEPROM
    pst.Str(@ErrEEPROMNotResponding)
    vMode := MODE_NORMAL

  if (vMode <> MODE_NORMAL) and (vMode <> MODE_SUMP) and (vMode <> MODE_OCD)
    vMode := MODE_NORMAL

  if (vTargetIO < VTARGET_IO_MIN) or (vTargetIO > VTARGET_IO_MAX)
    vMode := MODE_NORMAL

  ' Select operating mode
  case vMode
    MODE_SUMP:       ' Logic analyzer (OLS/SUMP)
      pst.Stop              ' Stop serial communications (this will be restarted from within the sump object)
      DACOutput(VoltageTable[vTargetIO - VTARGET_IO_MIN])    ' Set target I/O voltage
      GPIO_Logic(0)         ' Start logic analyzer mode
      idMenu := MENU_GPIO   ' Set to previously active menu upon return

    MODE_OCD:        ' OpenOCD interface
      pst.Stop              ' Stop serial communications (this will be restarted from within the ocd object)
      DACOutput(VoltageTable[vTargetIO - VTARGET_IO_MIN])    ' Set target I/O voltage
      JTAG_OpenOCD(0)       ' Start OpenOCD mode
      idMenu := MENU_JTAG   ' Set to previously active menu upon return

    MODE_NORMAL:     ' JTAGulator main mode
      Set_Config_Defaults          ' Set configuration globals to default values
      u.LEDYellow
      pst.CharIn                   ' Wait until the user presses a key before getting started
      pst.Str(@InitHeader)         ' Display header


CON {{ MENU METHODS }}

PRI Do_Main_Menu(cmd)
  case cmd
    "J", "j":                 ' Switch to JTAG submenu
      idMenu := MENU_JTAG

    "U", "u":                 ' Switch to UART submenu
      idMenu := MENU_UART

    "G", "g":                 ' Switch to GPIO submenu
      idMenu := MENU_GPIO

    "S", "s":                 ' Switch to SWD submenu
      idMenu := MENU_SWD

    "A", "a":                 ' Scan all supported protocols
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        Read_IO_Pins          ' GPIO: Read all channels (input, one shot)
        pst.Str(@MsgSpacer)
        IDCODE_Scan(1)        ' JTAG: Combined Scan
        pst.Str(@MsgSpacer)
        IDCODE_Scan(0)        ' JTAG: IDCODE Scan
        pst.Str(@MsgSpacer)
        BYPASS_Scan           ' JTAG: BYPASS Scan
        pst.Str(@MsgSpacer)
        RTCK_Scan             ' JTAG: Identify RTCK (Adaptive Clocking)
        pst.Str(@MsgSpacer)
        SWD_IDCODE_Scan       ' SWD: Identify SWD pinout (IDCODE Scan)
        pst.Str(@MsgSpacer)
        UART_Scan_TXD         ' UART: Identify UART pinout (TXD only, continuous automatic baud rate detection)
        pst.Str(@MsgSpacer)
        UART_Scan             ' UART: Identify UART pinout

    "V", "v":                 ' Set target I/O voltage
      Set_Target_IO_Voltage

    "I", "i":                 ' Display JTAGulator version information
      pst.Str(@VersionInfo)

    "H", "h":                 ' Display list of available commands
      Display_Menu_Text

    other:
      Display_Invalid_Command


PRI Do_JTAG_Menu(cmd)
  case cmd
    "J", "j":                 ' Identify JTAG pinout
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        IDCODE_Scan(1)        ' Combined IDCODE Scan and BYPASS Scan

    "I", "i":                 ' Identify JTAG pinout (IDCODE Scan)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        IDCODE_Scan(0)

    "B", "b":                 ' Identify JTAG pinout (BYPASS Scan)
      if (vTargetIO == -1)
       pst.Str(@ErrTargetIOVoltage)
      else
        BYPASS_Scan

    "R", "r":                 ' Identify RTCK (Adaptive Clocking)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        RTCK_Scan

    "D", "d":                 ' Get JTAG Device IDs (Pinout already known)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        IDCODE_Known

    "T", "t":                 ' Test BYPASS (TDI to TDO) (Pinout already known)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        BYPASS_Known

    "Y", "y":                 ' Instruction/Data Register discovery (Pinout already known, requires single device in the chain)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        OPCODE_Discovery

    "P", "p":                 ' Pin Mapper (EXTEST Scan) (Pinout already known, requires single device in the chain)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        EXTEST_Scan

    "O", "o":                 ' OpenOCD interface (Pinout already known)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        JTAG_OpenOCD(1)

    other:
      Do_Shared_Menu(cmd)


PRI Do_UART_Menu(cmd)
  case cmd
    "U", "u":                 ' Identify UART pinout
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        UART_Scan

    "T", "t":                 ' Identify UART pinout (TXD only, continuous automatic baud rate detection)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        UART_Scan_TXD

    "P", "p":                 ' UART passthrough
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        UART_Passthrough

    other:
      Do_Shared_Menu(cmd)


PRI Do_GPIO_Menu(cmd)
  case cmd
    "R", "r":                 ' Read all channels (input, one shot)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        Read_IO_Pins

    "C", "c":                 ' Read all channels (input, continuous)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        Monitor_IO_Pins

    "W", "w":                 ' Write all channels (output)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        Write_IO_Pins

    "L", "l":                 ' Logic analyzer (OLS/SUMP)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        GPIO_Logic(1)

    other:
      Do_Shared_Menu(cmd)


PRI Do_SWD_Menu(cmd)
  case cmd
    "I", "i":                 ' Identify SWD pinout (IDCODE Scan)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        SWD_IDCODE_Scan

    "D", "d":                 ' Get SWD Device ID (Pinout already known)
      if (vTargetIO == -1)
        pst.Str(@ErrTargetIOVoltage)
      else
        SWD_IDCODE_Known

    other:
      Do_Shared_Menu(cmd)


PRI Do_Shared_Menu(cmd)
  case cmd
    "V", "v":                 ' Set target I/O voltage
      Set_Target_IO_Voltage

    "H", "h":                 ' Display list of available commands
      Display_Menu_Text

    "M", "m":                 ' Return to main menu
      idMenu := MENU_MAIN

    other:
      Display_Invalid_Command


PRI Display_Menu_Text
  case idMenu
    MENU_MAIN:
      pst.Str(@MenuMain)

    MENU_JTAG:
      pst.Str(@MenuJTAG)

    MENU_UART:
      pst.Str(@MenuUART)

    MENU_GPIO:
      pst.Str(@MenuGPIO)

    MENU_SWD:
      pst.Str(@MenuSWD)

  if (idMenu <> MENU_MAIN)
    pst.Str(@MenuShared)


PRI Display_Command_Prompt
  pst.Str(String(CR, LF, LF))

  case idMenu
    MENU_MAIN:                ' Main/Top, don't display any prefix/header

    MENU_JTAG:                ' JTAG
      pst.Str(String("JTAG"))

    MENU_UART:                ' UART
      pst.Str(String("UART"))

    MENU_GPIO:                ' General Purpose I/O
      pst.Str(String("GPIO"))

    MENU_SWD:                 ' Serial Wire Debug
      pst.Str(String("SWD"))

    other:
      idMenu := MENU_MAIN

  pst.Str(String("> "))


PRI Display_Invalid_Command
  pst.Str(String(CR, LF, "? Press 'H' for available commands."))


CON {{ JTAG METHODS }}

PRI JTAG_Init
  rr.start         ' Start RealRandom cog (used during BYPASS Scan and Test BYPASS)

  ' Set default parameters
  ' BYPASS_Scan, RTCK_Scan
  jPinsKnown := 0

  ' OPCODE_Discovery
  jIgnoreReg := 1

  ' EXTEST_Scan
  jIR := $00
  jDRFill := 0
  jLoopPause := 0


PRI IDCODE_Scan(type) | value, value_new, ctr, num, id[32 {jtag#MAX_DEVICES_LEN}], i, match, data_in, data_out, xtdi, xtdo, xtck, xtms, err    ' Identify JTAG pinout (IDCODE Scan or Combined Scan)
  if (type == 0)    ' IDCODE Scan only
    if (Get_Channels(3) == -1)   ' Get the channel range to use
      return
    Display_Permutations((chEnd - chStart + 1), 3)  ' TDO, TCK, TMS
  else              ' Combined IDCODE Scan and BYPASS Scan (aka JTAG Scan)
    if (Get_Channels(4) == -1)   ' Get the channel range to use
      return
    Display_Permutations((chEnd - chStart + 1), 4)  ' TDI, TDO, TCK, TMS

  if (Get_Settings == -1)      ' Get configurable scan settings
    return

  if (type == 0)
    err := @ErrIDCODEAborted
  else
    err := @ErrJTAGAborted

  if (Wait_For_Space(err) == -1)
    return

  longfill(@id, 0, jtag#MAX_DEVICES_LEN)           ' Clear IDCODE buffer

  pst.Str(@MsgJTAGulating)
  u.TXSEnable   ' Enable level shifter outputs

  jTDI := g#PROP_SDA    ' TDI isn't used when we're just shifting data from the DR. Set TDI to a temporary pin so it doesn't interfere with enumeration.

  ' We assume the IDCODE is the default DR after reset
  ' Pin enumeration logic based on JTAGenum (http://deadhacker.com/2010/02/03/jtag-enumeration/)
  num := 0      ' Counter of possible pinouts
  ctr := 0
  match := 0
  xtdi := xtdo := xtck := xtms := 0
  repeat jTDO from chStart to chEnd   ' For every possible pin permutation (except TDI and TRST)...
    repeat jTCK from chStart to chEnd
      if (jTCK == jTDO)
        next
      repeat jTMS from chStart to chEnd
        if (jTMS == jTCK) or (jTMS == jTDO)
          next

        if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
          if (type == 0)
            JTAG_Scan_Cleanup(num, 0, xtdo, xtck, xtms)  ' TDI isn't used during an IDCODE Scan
            pst.Str(@ErrIDCODEAborted)
          else
            JTAG_Scan_Cleanup(num, xtdi, xtdo, xtck, xtms)
            pst.Str(@ErrJTAGAborted)
          pst.RxFlush
          return

        u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH (in case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#)

        if (pinsLow == 1)     ' Pulse channels LOW if requested by the user
          u.Set_Pins_Low(chStart, chEnd)      ' Set current channel range to output LOW
          u.Pause(pinsLowDelay)               ' Delay to stay asserted
          u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH
          u.Pause(pinsHighDelay)              ' Delay after deassertion before proceeding

        jtag.Config(jTDI, jTDO, jTCK, jTMS)   ' Configure JTAG
        jtag.Get_Device_IDs(1, @value)        ' Try to get a single Device ID (if it exists) by reading the DR
        if (value <> -1) and (value & 1)      ' Ignore if received Device ID is 0xFFFFFFFF or if bit 0 != 1
          if (type == 0)    ' IDCODE Scan
            Display_JTAG_Pins                 ' Display current JTAG pinout
            num += 1                          ' Increment counter
            xtdo := jTDO                      ' Keep track of most recent detection results
            xtck := jTCK
            xtms := jTMS
            jPinsKnown := 1                   ' Enable known pins flag

            ' Since we might not know how many devices are in the chain, try the maximum allowable number and verify the results afterwards
            jtag.Get_Device_IDs(jtag#MAX_DEVICES_LEN, @id)   ' We assume the IDCODE is the default DR after reset
            repeat i from 0 to (jtag#MAX_DEVICES_LEN-1)      ' For each device in the chain...
              Display_Device_ID(id[i], i + 1, 1)               ' Display Device ID of current device (without details)
          else              ' Combined IDCODE Scan and BYPASS Scan
            ' Now try to determine TDI by doing a BYPASS Test
            repeat jTDI from chStart to chEnd     ' For every remaining channel...
              if (jTDI == jTMS) or (jTDI == jTCK) or (jTDI == jTDO)
                next

              if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
                JTAG_Scan_Cleanup(num, xtdi, xtdo, xtck, xtms)
                pst.Str(@ErrJTAGAborted)
                pst.RxFlush
                return

              u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH (in case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#)

              if (pinsLow == 1)     ' Pulse channels LOW if requested by the user
                u.Set_Pins_Low(chStart, chEnd)      ' Set current channel range to output LOW
                u.Pause(pinsLowDelay)               ' Delay to stay asserted
                u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH
                u.Pause(pinsHighDelay)              ' Delay after deassertion before proceeding

              jtag.Config(jTDI, jTDO, jTCK, jTMS)              ' Re-configure JTAG
              value := jtag.Detect_Devices                     ' Get number of devices in the chain (if any)

              ' Run a BYPASS test to ensure TDO is actually passing TDI
              data_in := rr.random                             ' Get 32-bit random number to use as the BYPASS pattern
              data_out := jtag.Bypass_Test(value, data_in)     ' Run the BYPASS instruction

              if (data_in == data_out)   ' If match, then we've found a JTAG interface on this current pinout
                Display_JTAG_Pins                 ' Display current JTAG pinout
                num += 1                          ' Increment counter
                xtdi := jTDI                      ' Keep track of most recent detection results
                xtdo := jTDO
                xtck := jTCK
                xtms := jTMS
                jPinsKnown := 1                   ' Enable known pins flag
                match := 1                        ' Set flag to enable subsequent TRST# search

                u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH (in case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#)

                if (pinsLow == 1)     ' Pulse channels LOW if requested by the user
                  u.Set_Pins_Low(chStart, chEnd)      ' Set current channel range to output LOW
                  u.Pause(pinsLowDelay)               ' Delay to stay asserted
                  u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH
                  u.Pause(pinsHighDelay)              ' Delay after deassertion before proceeding

                jtag.Config(jTDI, jTDO, jTCK, jTMS)              ' Re-configure JTAG

                jtag.Get_Device_IDs(value, @id)   ' We assume the IDCODE is the default DR after reset
                repeat i from 0 to (value-1)      ' For each device in the chain...
                  Display_Device_ID(id[i], i + 1, 1)       ' Display Device ID of current device (with details)

                quit                              ' Break out of the search for TDI and continue...
              else
                match := 0

              ' Progress indicator
              ++ctr
              if (pinsLow == 0)
                Display_Progress(ctr, 100, 1)
              else
                Display_Progress(ctr, 1, 1)

          if (type == 0) or (type == 1 and match <> 0)
            ' Now try to determine if the TRST# pin is being used on the target
            repeat jTRST from chStart to chEnd     ' For every remaining channel...
              if (jTRST == jTMS) or (jTRST == jTCK) or (jTRST == jTDO) or (jTRST == jTDI)
                next

              if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
                if (type == 0)
                  JTAG_Scan_Cleanup(num, 0, xtdo, xtck, xtms)  ' TDI isn't used during an IDCODE Scan
                  pst.Str(@ErrIDCODEAborted)
                else
                  JTAG_Scan_Cleanup(num, xtdi, xtdo, xtck, xtms)
                  pst.Str(@ErrJTAGAborted)
                pst.RxFlush
                return

              u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH (in case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#)

              if (pinsLow == 1)     ' Pulse channels LOW if requested by the user
                u.Set_Pins_Low(chStart, chEnd)      ' Set current channel range to output LOW
                u.Pause(pinsLowDelay)               ' Delay to stay asserted
                u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH
                u.Pause(pinsHighDelay)              ' Delay after deassertion before proceeding

              jtag.Config(jTDI, jTDO, jTCK, jTMS)   ' Re-configure JTAG

              dira[jTRST] := 1  ' Set current pin to output
              outa[jTRST] := 0  ' Output LOW
              u.Pause(100)      ' Give target time to react

              jtag.Get_Device_IDs(1, @value_new)  ' Try to get a single Device ID again by reading the DR
              if (value_new <> id[0])             ' If the new value doesn't match what we already have, then the current pin may be a reset line.
                pst.Str(String("TRST#: "))          ' Display the pin number
                pst.Dec(jTRST)
                pst.Str(String(CR, LF))

              ' Progress indicator
              ++ctr
              if (pinsLow == 0)
                Display_Progress(ctr, 100, 0)
              else
                Display_Progress(ctr, 1, 0)

            pst.Str(String(CR, LF))

        ' Progress indicator
        ++ctr
        if (pinsLow == 0)
          Display_Progress(ctr, 100, 1)
        else
          Display_Progress(ctr, 1, 1)

  if (num == 0)
    pst.Str(@ErrNoDeviceFound)
    jPinsKnown := 0

  if (type == 0)
    JTAG_Scan_Cleanup(num, 0, xtdo, xtck, xtms)  ' TDI isn't used during an IDCODE Scan
    pst.Str(String(CR, LF, "IDCODE"))
  else
    JTAG_Scan_Cleanup(num, xtdi, xtdo, xtck, xtms)
    pst.Str(String(CR, LF, "JTAG combined"))

  pst.Str(@MsgScanComplete)


PRI BYPASS_Scan | value, value_new, ctr, num, data_in, data_out, xtdi, xtdo, xtck, xtms, tdiStart, tdiEnd, tdoStart, tdoEnd, tckStart, tckEnd, tmsStart, tmsEnd    ' Identify JTAG pinout (BYPASS Scan)
  num := 4   ' Number of pins needed to locate (TDI, TDO, TCK, TMS)

  if (Get_Channels(num) == -1)   ' Get the channel range to use
    return

  tdiStart := tdoStart := tmsStart := tckStart := chStart   ' Set default start and end channels
  tdiEnd := tdoEnd := tmsEnd := tckEnd := chEnd

  if (Get_Pins_Known(0) == -1)   ' Ask if any pins are known
    return

  if (jPinsKnown == 1)
    pst.Str(@MsgUnknownPin)
    if (Set_JTAG_Partial == -1)
      return                            ' Abort if error

    ' If the user has entered a known pin, set it as both start and end to make it static during the scan
    if (jTDI <> -2)
      tdiStart := tdiEnd := jTDI
      num -= 1
    else
      jTDI := 0   ' Reset pin

    if (jTDO <> -2)
      tdoStart := tdoEnd := jTDO
      num -= 1
    else
      jTDO := 0

    if (jTMS <> -2)
      tmsStart := tmsEnd := jTMS
      num -= 1
    else
      jTMS := 0

    if (jTCK <> -2)
      tckStart := tckEnd := jTCK
      num -= 1
    else
      jTCK := 0

  Display_Permutations((chEnd - chStart + 1) - (4 - num), num)  ' Calculate number of permutations, accounting for any known channels

  if (Get_Settings == -1)      ' Get configurable scan settings
    return

  if (Wait_For_Space(@ErrBYPASSAborted) == -1)
    return

  pst.Str(@MsgJTAGulating)
  u.TXSEnable   ' Enable level shifter outputs

  num := 0  ' Counter of possible pinouts
  ctr := 0
  xtdi := xtdo := xtck := xtms := 0
  repeat jTDI from tdiStart to tdiEnd        ' For every possible pin permutation (except TRST#)...
    repeat jTDO from tdoStart to tdoEnd
      if (jTDO == jTDI)  ' Ensure each pin number is unique
        next
      repeat jTCK from tckStart to tckEnd
        if (jTCK == jTDO) or (jTCK == jTDI)
          next
        repeat jTMS from tmsStart to tmsEnd
          if (jTMS == jTCK) or (jTMS == jTDO) or (jTMS == jTDI)
            next

          if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
            JTAG_Scan_Cleanup(num, xtdi, xtdo, xtck, xtms)
            pst.Str(@ErrBYPASSAborted)
            pst.RxFlush
            return

          u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH (in case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#)

          if (pinsLow == 1)     ' Pulse channels LOW if requested by the user
            u.Set_Pins_Low(chStart, chEnd)      ' Set current channel range to output LOW
            u.Pause(pinsLowDelay)               ' Delay to stay asserted
            u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH
            u.Pause(pinsHighDelay)              ' Delay after deassertion before proceeding

          jtag.Config(jTDI, jTDO, jTCK, jTMS)     ' Configure JTAG
          value := jtag.Detect_Devices

          ' Run a BYPASS test to ensure TDO is actually passing TDI
          data_in := rr.random                          ' Get 32-bit random number to use as the BYPASS pattern
          data_out := jtag.Bypass_Test(value, data_in)  ' Run the BYPASS instruction

          if (data_in == data_out)   ' If match, then continue with this current pinout
            Display_JTAG_Pins          ' Display pinout
            num += 1                   ' Increment counter
            xtdi := jTDI               ' Keep track of most recent detection results
            xtdo := jTDO
            xtck := jTCK
            xtms := jTMS
            jPinsKnown := 1            ' Enable known pins flag

            ' Now try to determine if the TRST# pin is being used on the target
            repeat jTRST from chStart to chEnd     ' For every remaining channel...
              if (jTRST == jTMS) or (jTRST == jTCK) or (jTRST == jTDO) or (jTRST == jTDI)
                next

              if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
                JTAG_Scan_Cleanup(num, xtdi, xtdo, xtck, xtms)
                pst.Str(@ErrBYPASSAborted)
                pst.RxFlush
                return

              u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH (in case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#)

              if (pinsLow == 1)     ' Pulse channels LOW if requested by the user
                u.Set_Pins_Low(chStart, chEnd)      ' Set current channel range to output LOW
                u.Pause(pinsLowDelay)               ' Delay to stay asserted
                u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH
                u.Pause(pinsHighDelay)              ' Delay after deassertion before proceeding

              jtag.Config(jTDI, jTDO, jTCK, jTMS)     ' Re-configure JTAG

              dira[jTRST] := 1  ' Set current pin to output
              outa[jTRST] := 0  ' Output LOW
              u.Pause(100)      ' Give target time to react

              value_new := jtag.Detect_Devices
              if (value_new <> value) and (value_new =< jtag#MAX_DEVICES_LEN)    ' If the new value doesn't match what we already have, then the current pin may be a reset line.
                pst.Str(String("TRST#: "))    ' Display the pin number
                pst.Dec(jTRST)
                pst.Str(String(CR, LF))

              ' Progress indicator
              ++ctr
              if (pinsLow == 0)
                Display_Progress(ctr, 10, 0)
              else
                Display_Progress(ctr, 1, 0)

            pst.Str(@MsgDevicesDetected)
            pst.Dec(value)
            pst.Str(String(CR, LF))

        ' Progress indicator
          ++ctr
          if (pinsLow == 0)
            Display_Progress(ctr, 10, 1)
          else
            Display_Progress(ctr, 1, 1)

  if (num == 0)
    pst.Str(@ErrNoDeviceFound)
    jPinsKnown := 0

  JTAG_Scan_Cleanup(num, xtdi, xtdo, xtck, xtms)

  pst.Str(String(CR, LF, "BYPASS"))
  pst.Str(@MsgScanComplete)


PRI RTCK_Scan : err | ctr, num, known, matches, xtck, xrtck, tckStart, tckEnd      '  Identify RTCK (Adaptive Clocking)
  num := 2   ' Number of pins needed to locate (TCK, RTCK)

  if (Get_Channels(num) == -1)   ' Get the channel range to use
    return

  tckStart := chStart   ' Set default start and end channels
  tckEnd := chEnd

  known := jPinsKnown
  pst.Str(String(CR, LF, "Is TCK already known? ["))
  if (known == 0)
    pst.Str(String("y/N]: "))
  else
    pst.Str(String("Y/n]: "))
  pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
  if (strsize(@vCmd) =< 1)            ' We're only looking for a single character (or NULL, which will have a string size of 0)
    case vCmd[0]                        ' Check the first character of the input string
      0:                                ' The user only entered a CR, so keep the same value and pass through.
      "N", "n":
        known := 0                      ' Disable flag
      "Y", "y":                         ' If the user wants to use a partial pinout
        known := 1                      ' Enable flag
      other:                            ' Any other key causes an error
        pst.Str(@ErrOutOfRange)
        return
  else
    pst.Str(@ErrOutOfRange)
    return

  if (known == 1)
    pst.Str(String(CR, LF, "Enter X if pin is unknown."))
    pst.Str(@MsgEnterTCKPin)
    pst.Dec(jTCK)               ' Display current value
    pst.Str(String("]: "))
    xtck := Get_Pin             ' Get new value from user
    if (xtck == -1)             ' If carriage return was pressed...
      xtck := jTCK                ' Keep current setting
    if (xtck < -2) or (xtck > chEnd)   ' If entered value is out of range, abort
      pst.Str(@ErrOutOfRange)
      return -1

    if (xtck <> -2)
      tckStart := tckEnd := xtck
      num -= 1

  Display_Permutations((chEnd - chStart + 1) - (2 - num), num)  ' Calculate number of permutations, accounting for any known channels

  if (Get_Settings == -1)      ' Get configurable scan settings
    return

  if (Wait_For_Space(@ErrRTCKAborted) == -1)
    return

  pst.Str(@MsgJTAGulating)
  u.TXSEnable   ' Enable level shifter outputs

  num := 0      ' Counter of possibly good pinouts
  ctr := 0      ' Counter of total loop iterations
  repeat xtck from tckStart to tckEnd   ' For every possible pin permutation
    repeat xrtck from chStart to chEnd
      if (xtck == xrtck)
        next

      if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
        pst.Str(@ErrRTCKAborted)
        pst.RxFlush
        return

      u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH (in case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#)

      if (pinsLow == 1)     ' Pulse channels LOW if requested by the user
        u.Set_Pins_Low(chStart, chEnd)      ' Set current channel range to output LOW
        u.Pause(pinsLowDelay)               ' Delay to stay asserted
        u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH
        u.Pause(pinsHighDelay)              ' Delay after deassertion before proceeding

{{

                                         _____//_____
TCK (from JTAGulator to target):  ______/            \__________
                                         |      |
                                         |<---->| _____//_____
RTCK (from target to JTAGulator):     ___|______|/            \__________

                                           ^ Delay time varies with target
}}
      matches := 0
      dira[xrtck] := 0   ' Set current pin as input
      dira[xtck] := 1    ' Set current pin as output
      outa[xtck] := 0
      repeat NUM_RTCK_ITERATIONS
        !outa[xtck]
        u.Pause(10)        ' Delay for target to propagate signal from TCK to RTCK (if it exists)
        if (outa[xtck] == ina[xrtck])      'Check if RTCK mirrors TCK
          ++matches

      if (matches == NUM_RTCK_ITERATIONS)    ' Valid candidates should match 100% of the time
        ++num

        pst.Str(String(CR, LF, "TCK: "))
        pst.Dec(xtck)

        pst.Str(String(CR, LF, "RTCK: "))
        pst.Dec(xrtck)

        pst.Str(String(CR, LF))

      ' Progress indicator
      ++ctr
      if (pinsLow == 0)
        Display_Progress(ctr, 10, 1)
      else
        Display_Progress(ctr, 1, 1)

  if (num == 0)
    pst.Str(@ErrNoDeviceFound)

  pst.Str(String(CR, LF, "RTCK"))
  pst.Str(@MsgScanComplete)


PRI IDCODE_Known | id[32 {jtag#MAX_DEVICES_LEN}], i, xtdi   ' Get JTAG Device IDs (Pinout already known)
  xtdi := jTDI   ' Save current value, if it exists

  if (Set_JTAG(0) == -1)  ' Ask user for the known JTAG pinout
    return                  ' Abort if error

  longfill(@id, 0, jtag#MAX_DEVICES_LEN)           ' Clear IDCODE buffer

  u.TXSEnable                                      ' Enable level shifter outputs
  u.Set_Pins_High(0, g#MAX_CHAN-1)                 ' In case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#
  jtag.Config(jTDI, jTDO, jTCK, jTMS)              ' Configure JTAG

  ' Since we might not know how many devices are in the chain, try the maximum allowable number and verify the results afterwards
  jtag.Get_Device_IDs(jtag#MAX_DEVICES_LEN, @id)   ' We assume the IDCODE is the default DR after reset

  repeat i from 0 to (jtag#MAX_DEVICES_LEN-1)      ' For each device in the chain...
    Display_Device_ID(id[i], i + 1, 1)               ' Display Device ID of current device (with details)

  if (i == 0)
    pst.Str(@ErrNoDeviceFound)
    jPinsKnown := 0

  jTDI := xtdi   ' Set TDI back to its current value, if it exists (it was set to a temporary pin value to avoid contention)
  pst.Str(@MsgIDCODEDisplayComplete)


PRI BYPASS_Known | num, dataIn, dataOut   ' Test BYPASS (TDI to TDO) (Pinout already known)
  if (Set_JTAG(1) == -1)  ' Ask user for the known JTAG pinout
    return                  ' Abort if error

  u.TXSEnable                                 ' Enable level shifter outputs
  u.Set_Pins_High(0, g#MAX_CHAN-1)            ' In case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#
  jtag.Config(jTDI, jTDO, jTCK, jTMS)         ' Configure JTAG

  num := jtag.Detect_Devices                  ' Get number of devices in the chain
  pst.Str(String(CR, LF))
  pst.Str(@MsgDevicesDetected)
  pst.Dec(num)
  if (num == 0)
    pst.Str(@ErrNoDeviceFound)
    jPinsKnown := 0
    return

  dataIn := rr.random                         ' Get 32-bit random number to use as the BYPASS pattern
  dataOut := jtag.Bypass_Test(num, dataIn)    ' Run the BYPASS instruction

  ' Display input/output data and check if they match
  pst.Str(String(CR, LF, "Pattern in to TDI:    "))
  pst.Bin(dataIn, 32)   ' Display value as binary characters (0/1)

  pst.Str(String(CR, LF, "Pattern out from TDO: "))
  pst.Bin(dataOut, 32)  ' Display value as binary characters (0/1)

  if (dataIn == dataOut)
    pst.Str(String(CR, LF, "Match!"))
  else
    pst.Str(String(CR, LF, "No Match!"))


PRI OPCODE_Discovery | num, ctr, gap_ctr, irLen, drLen, opcode_max, opcodeH, opcodeL, opcode   ' Discover DR length for every instruction (Pinout already known, requires single device in the chain)
  if (Set_JTAG(1) == -1)  ' Ask user for the known JTAG pinout
    return                  ' Abort if error

  pst.Str(String(CR, LF, "Ignore single-bit Data Registers? ["))   ' If DR is 1 bit, it's probably an unimplemented command (which usually defaults to BYPASS)
  if (jIgnoreReg == 0)
    pst.Str(String("y/N]: "))
  else
    pst.Str(String("Y/n]: "))
  pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
  if (strsize(@vCmd) =< 1)            ' We're only looking for a single character (or NULL, which will have a string size of 0)
    case vCmd[0]                        ' Check the first character of the input string
      0:                                ' The user only entered a CR, so keep the same value and pass through.
      "N", "n":
        jIgnoreReg := 0                 ' Disable flag
      "Y", "y":                         ' If the user wants to use a partial pinout
        jIgnoreReg := 1                 ' Enable flag
      other:                            ' Any other key causes an error
        pst.Str(@ErrOutOfRange)
        return
  else
    pst.Str(@ErrOutOfRange)
    return

  u.TXSEnable                                 ' Enable level shifter outputs
  u.Set_Pins_High(0, g#MAX_CHAN-1)            ' In case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#
  jtag.Config(jTDI, jTDO, jTCK, jTMS)         ' Configure JTAG

  num := jtag.Detect_Devices                  ' Get number of devices in the chain
  if (num == 0)
    pst.Str(@ErrNoDeviceFound)
    jPinsKnown := 0
    return
  elseif (num > 1)
    pst.Str(@ErrTooManyDevices)
    return
  pst.Str(String(CR, LF))

  ' Get instruction register length
  irLen := jtag.Detect_IR_Length
  pst.Str(@MsgIRLength)
  if (irLen == 0)
    pst.Str(String("N/A"))
    pst.Str(@ErrOutOfRange)
    return
  else
    pst.Dec(irLen)

  pst.Str(String(CR, LF, "Possible instructions: "))
  opcode_max := Bits_to_Value(irLen)   ' 2^n - 1
  pst.Dec(opcode_max + 1)

  if (Wait_For_Space(@ErrDiscoveryAborted) == -1)
    return

  pst.Str(@MsgJTAGulating)

  ctr := 0
  gap_ctr := 0
  ' For every possible instruction...
  repeat opcodeH from 0 to opcode_max.WORD[1]         ' Propeller Spin performs all mathematic operations using 32-bit signed math (MSB is the sign bit)
    repeat opcodeL from 0 to opcode_max.WORD[0]         ' So, we need to nest two loops in order to support the full 32-bit maximum IR length (thanks to balrog, whixr, and atdiy of #tymkrs)
      if (pst.RxEmpty == 0)                       ' Abort scan if any key is pressed
        pst.Str(@ErrDiscoveryAborted)
        pst.RxFlush
        return

      opcode := (opcodeH << 16) | opcodeL
      drLen := jtag.Detect_DR_Length(opcode)      ' Get the DR length

      if (drLen > 1 or jIgnoreReg == 0)
        if (gap_ctr > 1 and jIgnoreReg == 1)        ' Include a visible marker if there's a gap between instructions (for easier readibility)
          pst.Str(@CharProgress)
          pst.Str(String(CR, LF))

        Display_JTAG_IRDR(irLen, opcode, drLen)   ' Display the result
        gap_ctr := 0

      ' Progress indicator
      ++ctr
      ++gap_ctr
      Display_Progress(ctr, 8, jIgnoreReg)

  jtag.Restore_Idle   ' Reset JTAG TAP to Run-Test-Idle state
  pst.Str(String(CR, LF, "IR/DR discovery complete."))


PRI EXTEST_Scan | num, ctr, i, irLen, drLen, xir, ch, ch_start, ch_current, chmask, exit, valid, test_data   ' Pin Mapper (EXTEST Scan) (Pinout already known, requires single device in the chain)
  if (Set_JTAG(1) == -1)  ' Ask user for the known JTAG pinout
    return                  ' Abort if error

  u.TXSEnable                                 ' Enable level shifter outputs
  u.Set_Pins_High(0, g#MAX_CHAN-1)            ' In case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#
  jtag.Config(jTDI, jTDO, jTCK, jTMS)         ' Configure JTAG

  ' Get number of devices in the chain
  num := jtag.Detect_Devices
  if (num == 0)
    pst.Str(@ErrNoDeviceFound)
    jPinsKnown := 0
    return
  elseif (num > 1)
    pst.Str(@ErrTooManyDevices)
    return

  ' Get instruction register length
  irLen := jtag.Detect_IR_Length
  pst.Str(String(CR, LF))
  pst.Str(@MsgIRLength)
  if (irLen == 0)
    pst.Str(String("N/A"))
    pst.Str(@ErrOutOfRange)
    return
  else
    pst.Dec(irLen)

  pst.Str(String(CR, LF, LF, "Enter EXTEST instruction (in hex) ["))
  pst.Hex(jIR, Round_Up(irLen) >> 2)
  pst.Str(String("]: "))
  ' Receive hexadecimal value from the user and perform input sanitization
  ' This has do be done directly in the object since we may need to handle user input up to 32 bits
  pst.StrInMax(@vCmd,  MAX_LEN_CMD)
  if (vCmd[0]==0)   ' If carriage return was pressed...
    xir := jIR & Bits_To_Value(irLen)    ' Keep current setting, but adjust for a possible change in IR length
  else
    if strsize(@vCmd) > (Round_Up(irLen) >> 2)  ' If value is larger than the actual IR length
      pst.Str(@ErrOutOfRange)
      return
    ' Make sure each character in the string is hexadecimal ("0"-"9","A"-"F","a"-"f")
    repeat i from 0 to strsize(@vCmd)-1
      num := vCmd[i]
      num := -15 + --num & %11011111 + 39*(num > 56)   ' Borrowed from the Parallax Serial Terminal (PST) StrToBase method
      if (num < 0) or (num => 16)
        pst.Str(@ErrOutOfRange)
        return
    xir := pst.StrToBase(@vCmd, 16)   ' Convert valid string into actual value
  jIR := xir   ' Update global with new value

  ' Get data register length based on user provided instruction (should hopefully be Boundary Scan)
  drLen := jtag.Detect_DR_Length(xir)
  pst.Str(String(CR, LF, "Boundary Scan Register length: "))
  if (drLen == 0)
    pst.Str(String("N/A"))
    pst.Str(@ErrOutOfRange)
    return
  else
    pst.Dec(drLen)
  if (drLen == 1)
    pst.Str(@ErrOutOfRange)
    return

  pst.Str(String(CR, LF, LF, "Fill Boundary Scan Register with HIGH or LOW? ["))
  if (jDRFill == 0)
    pst.Str(String("h/L]: "))
  else
    pst.Str(String("H/l]: "))
  pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
  if (strsize(@vCmd) =< 1)            ' We're only looking for a single character (or NULL, which will have a string size of 0)
    case vCmd[0]                        ' Check the first character of the input string
        0:                                ' The user only entered a CR, so keep the same value and pass through.
        "L", "l":
          jDRFill := 0                    ' Disable flag
        "H", "h":
          jDRFill := 1                    ' Enable flag
        other:
          pst.Str(@ErrOutOfRange)
          return
  else
    pst.Str(@ErrOutOfRange)
    return

  pst.Str(String(CR, LF, LF, "Pause after successful detection? ["))
  if (jLoopPause == 0)
    pst.Str(String("y/N]: "))
  else
    pst.Str(String("Y/n]: "))
  pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
  if (strsize(@vCmd) =< 1)            ' We're only looking for a single character (or NULL, which will have a string size of 0)
    case vCmd[0]                        ' Check the first character of the input string
        0:                                ' The user only entered a CR, so keep the same value and pass through.
        "N", "n":
          jLoopPause := 0                 ' Disable flag
        "Y", "y":
          jLoopPause := 1                 ' Enable flag
        other:
          pst.Str(@ErrOutOfRange)
          return
  else
    pst.Str(@ErrOutOfRange)
    return

  if (Wait_For_Space(@ErrEXTESTAborted) == -1)
    return

  pst.Str(@MsgJTAGulating)

  ' Calculate probe mask based on available channels
  u.Set_Pins_Input(0, g#MAX_CHAN-1)               ' Set all channels to inputs (default HIGH due to level translators)
  jtag.Config(jTDI, jTDO, jTCK, jTMS)             ' Re-configure JTAG

  chmask := !(|<jTDI | |<jTDO | |<jTCK | |<jTMS)  ' Set bits for channels used for JTAG
  chmask &= $00FFFFFF                             ' Mask bits representing CH23..0

  exit := 0
  repeat
    if (exit)
      quit

    repeat num from 0 to drLen-1
      if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
        exit := 1

      if (exit)
        quit

      ch_start := ina & chmask                       ' Read current state of pins

      ' Fill the Boundary Scan Register
      ' All 1s with walking 0 or all 0s with walking 1 depending on jDRFill
      jtag.Fill_Register(drLen, jDRFill, num)

      ' Progress indicator
      ++ctr
      Display_Progress(ctr, 1, 1)                    ' Indicate each time the Boundary Scan Register is filled

      if (ch_current := ina & chmask) <> ch_start    ' Check for change on one or more channels
        ch_current ^= ch_start                         ' Isolate the bits that changed (will be set to 1)

        ' Check each channel individually
        ch := 0
        repeat while (ch < g#MAX_CHAN)
          if (ch_current & 1)
            test_data := i := $AA                      ' Set byte for testing of detected channel

            valid := 0
            repeat 8
              if (i & 1)                               ' Load the specific register bit...
                jtag.Fill_Register(drLen, jDRFill, -1)
              else
                jtag.Fill_Register(drLen, jDRFill, num)

              valid <<= 1
              valid |= ina[ch]                         ' ...and read the result
              i >>= 1

            valid ><= 8     ' Bitwise reverse since LSB came in first (we want MSB to be first)
            if (jDRFill == 0)
              valid := !valid & $FF   ' Invert bits

            if (test_data == valid)  ' If all 8-bits were read properly, then we've found a valid physical pin
              pst.Str(String(CR, LF, "CH"))
              pst.Dec(ch)
              pst.Str(String(" -> Register bit: "))
              pst.Dec(num)
              pst.Str(String(CR, LF))

              if (jLoopPause == 1)
                pst.Str(@MsgPressSpacebarToContinue)
                if (pst.CharIn <> " ")
                  exit := 1
                  quit
                else
                  pst.Str(String(CR, LF))

          ch += 1            ' Increment current channel
          ch_current >>= 1   ' Shift to the next bit in the channel mask

    if (exit <> 1)
      pst.Char("|")   ' Indicate each time a bit has walked all the way through the Boundary Scan Register

  jtag.Restore_Idle   ' Reset JTAG TAP to Run-Test-Idle state
  pst.RxFlush

  pst.Str(String(CR, LF, "Pin mapper complete."))


PRI Set_JTAG(getTDI) : err | xtdi, xtdo, xtck, xtms, buf, c     ' Set JTAG configuration to known values
  if (getTDI == 1)
    pst.Str(@MsgEnterTDIPin)
    pst.Dec(jTDI)             ' Display current value
    pst.Str(String("]: "))
    xtdi := Get_Decimal_Pin   ' Get new value from user
    if (xtdi == -1)           ' If carriage return was pressed...
      xtdi := jTDI              ' Keep current setting
    if (xtdi < 0) or (xtdi > g#MAX_CHAN-1)  ' If entered value is out of range, abort
      pst.Str(@ErrOutOfRange)
      return -1
  else
    pst.Str(String(CR, LF, "TDI not needed to retrieve Device ID.", CR, LF))
    xtdi := g#PROP_SDA          ' Set TDI to a temporary pin so it doesn't interfere with enumeration

  pst.Str(@MsgEnterTDOPin)
  pst.Dec(jTDO)               ' Display current value
  pst.Str(String("]: "))
  xtdo := Get_Decimal_Pin     ' Get new value from user
  if (xtdo == -1)             ' If carriage return was pressed...
    xtdo := jTDO                ' Keep current setting
  if (xtdo < 0) or (xtdo > g#MAX_CHAN-1)  ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  pst.Str(@MsgEnterTCKPin)
  pst.Dec(jTCK)               ' Display current value
  pst.Str(String("]: "))
  xtck := Get_Decimal_Pin     ' Get new value from user
  if (xtck == -1)             ' If carriage return was pressed...
    xtck := jTCK                ' Keep current setting
  if (xtck < 0) or (xtck > g#MAX_CHAN-1)  ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  pst.Str(@MsgEnterTMSPin)
  pst.Dec(jTMS)               ' Display current value
  pst.Str(String("]: "))
  xtms := Get_Decimal_Pin     ' Get new value from user
  if (xtms == -1)             ' If carriage return was pressed...
    xtms := jTMS                ' Keep current setting
  if (xtms < 0) or (xtms > g#MAX_CHAN-1)  ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  ' Make sure that the pin numbers are unique
  ' Set bit in a long corresponding to each pin number
  buf := 0
  buf |= (1 << xtdi)
  buf |= (1 << xtdo)
  buf |= (1 << xtck)
  buf |= (1 << xtms)

  ' Count the number of bits that are set in the long
  c := 0
  repeat 32
    c += (buf & 1)
    buf >>= 1

  if (c <> 4)         ' If there are not exactly 4 bits set (TDI, TDO, TCK, TMS), then we have a collision
    pst.Str(@ErrPinCollision)
    return -1
  else                ' If there are no collisions, update the globals with the new values
    jTDI := xtdi
    jTDO := xtdo
    jTCK := xtck
    jTMS := xtms


PRI Set_JTAG_Partial : err | xtdi, xtdo, xtck, xtms, buf, num, c     ' Set JTAG configuration to known values (used w/ partially known pinout)
  ' An "X" or "x" character will be sent by the user for any pin that is unknown. This will result in Get_Pin returning a -2 value.
  pst.Str(@MsgEnterTDIPin)
  pst.Dec(jTDI)               ' Display current value
  pst.Str(String("]: "))
  xtdi := Get_Pin             ' Get new value from user
  if (xtdi == -1)             ' If carriage return was pressed...
    xtdi := jTDI                ' Keep current setting
  if (xtdi < -2) or (xtdi > chEnd)   ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  pst.Str(@MsgEnterTDOPin)
  pst.Dec(jTDO)               ' Display current value
  pst.Str(String("]: "))
  xtdo := Get_Pin             ' Get new value from user
  if (xtdo == -1)             ' If carriage return was pressed...
    xtdo := jTDO                ' Keep current setting
  if (xtdo < -2) or (xtdo > chEnd)   ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  pst.Str(@MsgEnterTCKPin)
  pst.Dec(jTCK)               ' Display current value
  pst.Str(String("]: "))
  xtck := Get_Pin             ' Get new value from user
  if (xtck == -1)             ' If carriage return was pressed...
    xtck := jTCK                ' Keep current setting
  if (xtck < -2) or (xtck > chEnd)   ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  pst.Str(@MsgEnterTMSPin)
  pst.Dec(jTMS)               ' Display current value
  pst.Str(String("]: "))
  xtms := Get_Pin             ' Get new value from user
  if (xtms == -1)             ' If carriage return was pressed...
    xtms := jTMS                ' Keep current setting
  if (xtms < -2) or (xtms > chEnd)   ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  ' Make sure that the pin numbers are unique
  buf := 0
  num := 4
  if (xtdi <> -2)
    buf |= (1 << xtdi)    ' Set bit in a long corresponding to each pin number
  else
    num -= 1              ' If pin is unknown, don't set the bit

  if (xtdo <> -2)
    buf |= (1 << xtdo)
  else
    num -= 1

  if (xtck <> -2)
    buf |= (1 << xtck)
  else
    num -= 1

  if (xtms <> -2)
    buf |= (1 << xtms)
  else
    num -= 1

  ' Count the number of bits that are set in the long
  c := 0
  repeat 32
    c += (buf & 1)
    buf >>= 1

  if (c <> num)      ' If there are not exactly num bits set (depending on the number of known pins), then we have a collision
    pst.Str(@ErrPinCollision)
    return -1
  else                ' If there are no collisions, update the globals with the new values
    jTDI := xtdi
    jTDO := xtdo
    jTCK := xtck
    jTMS := xtms


PRI JTAG_Scan_Cleanup(num, tdi, tdo, tck, tms)
  if (num == 0)    ' If no device(s) were found during the search
    longfill(@jTDI, 0, 5)  ' Clear JTAG pinout
  else             ' Update globals with the most recent detection results
    jTDI := tdi
    jTDO := tdo
    jTCK := tck
    jTMS := tms


PRI Display_JTAG_Pins
  pst.Str(String(CR, LF, "TDI: "))
  if (jTDI => g#MAX_CHAN)   ' TDI isn't used during an IDCODE Scan (we're not shifting any data into the target), so it can't be determined
    pst.Str(String("N/A"))
  else
    pst.Dec(jTDI)

  pst.Str(String(CR, LF, "TDO: "))
  pst.Dec(jTDO)

  pst.Str(String(CR, LF, "TCK: "))
  pst.Dec(jTCK)

  pst.Str(String(CR, LF, "TMS: "))
  pst.Dec(jTMS)

  pst.Str(String(CR, LF))


PRI Display_JTAG_IRDR(irLen, opcode, drLen)    ' Display IR/DR information
  ' Display current instruction
  pst.Str(String("IR: "))

  ' ...as binary characters (0/1)
  Display_Binary(opcode, irLen)

  ' ...as hexadecimal
  pst.Str(String("(0x"))
  pst.Hex(opcode, Round_Up(irLen) >> 2)
  pst.Str(String(")"))

  ' Display DR length as a decimal value
  pst.Str(String(" -> DR: "))
  pst.Dec(drLen)
  pst.Str(String(CR, LF))


PRI Display_Device_ID(value, num, details)
  if (value == -1) or (value & $00000001 <> 1)   ' Ignore if Device ID is 0xFFFFFFFF or if bit 0 != 1
    return

  if (details == 1)
    pst.Str(String(CR, LF, LF))

  pst.Str(String("Device ID #"))
  pst.Dec(num)
  pst.Str(String(": "))

  ' Display value as binary characters (0/1) based on IEEE Std. 1149.1 2001 Device Identification Register structure
  {{ IEEE Std. 1149.1 2001
     Device Identification Register

     MSB                                                                          LSB
     +-----------+----------------------+---------------------------+--------------+
     |  Version  |      Part Number     |   Manufacturer Identity   |   Fixed (1)  |
     +-----------+----------------------+---------------------------+--------------+
        31...28          27...12                  11...1                   0
  }}
  pst.Bin(Get_Bit_Field(value, 31, 28), 4)      ' Version
  pst.Char(" ")
  pst.Bin(Get_Bit_Field(value, 27, 12), 16)     ' Part Number
  pst.Char(" ")
  pst.Bin(Get_Bit_Field(value, 11, 1), 11)      ' Manufacturer Identity
  pst.Char(" ")
  pst.Bin(Get_Bit_Field(value, 0, 0), 1)        ' Fixed (should always be 1)

  ' ...as hexadecimal
  pst.Str(String(" (0x"))
  pst.Hex(value, 8)
  pst.Str(String(")"))

  if (details == 1)
    ' JTAG MODE
    ' Extended decoding
    ' Not all vendors use these fields as specified
    pst.Str(String(CR, LF, "-> Manufacturer ID: 0x"))
    pst.Hex(Get_Bit_Field(value, 11, 1), 3)
    report_manufacturer_name(Get_Bit_Field(value, 11, 1)) 
    pst.Str(String(CR, LF, "-> Part Number: 0x"))
    pst.Hex(Get_Bit_Field(value, 27, 12), 4)
    pst.Str(String(CR, LF, "-> Version: 0x"))
    pst.Hex(Get_Bit_Field(value, 31, 28), 1)
  elseif(details==2)
    'SWD MODE
    pst.Str(String(CR, LF, "-> DESIGNER: 0x"))
    pst.Hex(Get_Bit_Field(value, 11, 1), 3)
    pst.Str(String(CR, LF, "-> PARTNO: 0x"))
    pst.Hex(Get_Bit_Field(value, 27, 12), 4)
    pst.Str(String(CR, LF, "-> Version: 0x"))
    pst.Hex(Get_Bit_Field(value, 31, 28), 1)

  pst.Str(String(CR, LF))

PRI report_manufacturer_name(manufacturer_address)  |  manufacturer_name
    pst.Str(String(CR, LF, "-> Manufacturer Name: "))
    readLong(Manufacturer_begin_address+ manufacturer_address * manufacturer_name_length - 16, @manufacturer_name)
    pst.Str(@manufacturer_name)
    readLong(Manufacturer_begin_address+ manufacturer_address * manufacturer_name_length -12, @manufacturer_name)
    pst.Str(@manufacturer_name)
    readLong(Manufacturer_begin_address+ manufacturer_address * manufacturer_name_length - 8, @manufacturer_name)
    pst.Str(@manufacturer_name)
    readLong(Manufacturer_begin_address+ manufacturer_address * manufacturer_name_length - 4, @manufacturer_name)
    pst.Str(@manufacturer_name)
PRI JTAG_OpenOCD(first_time) | ackbit   ' OpenOCD interface
  pst.Str(@MsgModeWarning)

  if (first_time == 1)
    u.LEDRed

    if (Set_JTAG(1) == -1)  ' Ask user for the known JTAG pinout
      return                  ' Abort if error

    ackbit := 0       ' Set flags so JTAGulator will start up in OpenOCD mode on next reset
    ackbit += writeLong(eepromAddress + EEPROM_MODE_OFFSET, MODE_OCD)
    ackbit += writeLong(eepromAddress + EEPROM_VTARGET_OFFSET, vTargetIO)
    ackbit += writeLong(eepromAddress + EEPROM_TDI_OFFSET, jTDI)
    ackbit += writeLong(eepromAddress + EEPROM_TDO_OFFSET, jTDO)
    ackbit += writeLong(eepromAddress + EEPROM_TCK_OFFSET, jTCK)
    ackbit += writeLong(eepromAddress + EEPROM_TMS_OFFSET, jTMS)

    if ackbit         ' If there's an error with the EEPROM
      pst.Str(@ErrEEPROMNotResponding)
      return

    pst.Str(String(CR, LF, "Entering OpenOCD mode! Press Ctrl-X to exit..."))
    pst.Str(@MsgOCDNote)
    u.Pause(100)      ' Delay to finish sending messages
    pst.Stop          ' Stop serial communications (this will be restarted from within the sump object)

  else    ' We're entering the mode from power-up, so read additional values from EEPROM
    ackbit := 0
    ackbit += readLong(eepromAddress + EEPROM_TDI_OFFSET, @jTDI)
    ackbit += readLong(eepromAddress + EEPROM_TDO_OFFSET, @jTDO)
    ackbit += readLong(eepromAddress + EEPROM_TCK_OFFSET, @jTCK)
    ackbit += readLong(eepromAddress + EEPROM_TMS_OFFSET, @jTMS)

    if ackbit         ' If there's an error with the EEPROM
      Set_Config_Defaults    ' Revert to default values in case data is invalid
      pst.Str(@ErrEEPROMNotResponding)
      return

  longfill (@vBuf, 0, sump#MAX_SAMPLE_PERIODS)  ' Clear input buffer
  ocd.Go(jTDI, jTDO, jTCK, jTMS, @vBuf)

  ' Exit from logic analyzer mode
  pst.Start(115_200)     ' Re-start serial communications

  ackbit := 0            ' Clear flag so JTAGulator will start up normally on next reset
  ackbit += writeLong(eepromAddress + EEPROM_MODE_OFFSET, MODE_NORMAL)

  if ackbit              ' If there's an error with the EEPROM
    pst.Str(@ErrEEPROMNotResponding)

  if (first_time == 0)   ' If we're returning from being disconnected, revert to default values
    Set_Config_Defaults

  pst.Str(String(CR, LF, "OpenOCD mode complete."))


CON {{ UART METHODS }}

PRI UART_Init
  bytefill (@uSTR, 0, MAX_LEN_UART_TX + 1)  ' Clear user input string buffer

  ' UART_Scan
  uHex := 0
  uPinsKnown := 0
  uPrintable := 0
  uWaitDelay := 10

  ' UART_Scan_TXD
  uBaudIgnore := 0

  ' UART_Passthrough
  uLocalEcho := 0


PRI UART_Scan | baud_idx, i, j, ctr, num, xstr[MAX_LEN_UART_USER + 1], xtxd, xrxd, xbaud, txdStart, txdEnd, rxdStart, rxdEnd     ' Identify UART pinout
  pst.Str(@MsgUARTPinout)

  num := 2   ' Number of pins needed to locate (TXD, RXD)

  if (Get_Channels(num) == -1)      ' Get the channel range to use
    return

  txdStart := rxdStart := chStart   ' Set default start and end channels
  txdEnd := rxdEnd := chEnd

  if (Get_Pins_Known(1) == -1)      ' Ask if any pins are known
    return

  if (uPinsKnown == 1)
    pst.Str(@MsgUnknownPin)
    if (Set_UART(0) == -1)
      return                        ' Abort if error

    ' If the user has entered a known pin, set it as both start and end to make it static during the scan
    if (uTXD <> -2)
      txdStart := txdEnd := uTXD
      num -= 1
    else
      uTXD := 0   ' Reset pin

    if (uRXD <> -2)
      rxdStart := rxdEnd := uRXD
      num -= 1
    else
      uRXD := 0

  Display_Permutations((chEnd - chStart + 1) - (2 - num), num)  ' Calculate number of permutations, accounting for any known channels

 ' Get user string to send during UART discovery
  pst.Str(String(CR, LF, "Enter text string to output (prefix with \x for hex) ["))
  if (uSTR[0] == 0) and (uHex == 0)
    pst.Str(String("CR"))  ' Default to a CR if string hasn't been set yet
  else
    if (uHex == 0)         ' If a previous string exists, display it
      pst.Str(@uSTR)         ' In ASCII...
    else                     ' Or in hex...
      pst.Str(String("\x"))
      i := 0
      repeat uHex
        pst.Hex(byte[@uSTR][i++], 2)
  pst.Str(String("]: "))

  pst.StrInMax(@xstr, MAX_LEN_UART_USER) ' Get input from user
  i := strsize(@xstr)

  if (i <> 0)              ' If input was anything other than a CR
    ' Make sure each character in the string is printable ASCII
    repeat j from 0 to (i - 1)
      if (byte[@xstr][j] < $20) or (byte[@xstr][j] > $7E)
        pst.Str(@ErrOutOfRange)  ' If the string contains invalid (non-printable) characters, abort
        return

    ' Check string for the \x escape sequence. If it exists, then the string is a series of hex bytes
    if (byte[@xstr][0] == "\" and byte[@xstr][1] == "x")
      if (byte[@xstr][2] == 0)  ' If the next character is a NULL byte, abort
        pst.Str(@ErrOutOfRange)
        return

      ' Make sure string is a series of complete bytes (no nibbles), should contain an even number of characters
      if (i // 2 <> 0)
         pst.Str(@ErrOutOfRange)
         return

      ' Make sure each character in the string is hexadecimal ("0"-"9","A"-"F","a"-"f") after the \x escape sequence
      if (str.is_hex(@xstr + 2) == false)
        pst.Str(@ErrOutOfRange)
        return

      ' Populate the uSTR global with up to MAX_LEN_UART_TX bytes
      ' uHex will contain the number of bytes in the string (used later as a counter to transmit the data)
      uHex := 0
      repeat j from 0 to (i - 3) step 2  ' look at two characters at a time in order to form one hex byte
        byte[@uSTR][uHex] := str.hex2dec(@xstr + 2 + j, 2)
        uHex++

    else  ' Otherwise, we are dealing with an ASCII string
      if (i > MAX_LEN_UART_TX)  ' If input is larger than MAX_LEN_UART_TX bytes, abort
        pst.Str(@ErrOutOfRange)
        return

      uHex := 0
      bytemove(@uSTR, @xstr, i)               ' Move the new string into the uSTR global
      bytefill(@uSTR+i, 0, MAX_LEN_UART_TX-i) ' Fill the remainder of the string with NULL, in case it's shorter than the last

  pst.Str(String(CR, LF, "Enter delay before checking for target response (in ms, 0 - 1000) ["))
  pst.Dec(uWaitDelay)         ' Display current value
  pst.Str(String("]: "))
  num := Get_Decimal_Pin      ' Get new value from user
  if (num <> -1)              ' If carriage return was not pressed...
    if (num < 0) or (num > 1000)  ' If entered value is out of range, abort
      pst.Str(@ErrOutOfRange)
      return
    uWaitDelay := num

  if (UART_Get_Printable == -1)    ' Ignore non-printable characters?
    return

  if (Get_Settings == -1)          ' Get configurable scan settings
    return

  if (Wait_For_Space(@ErrUARTAborted) == -1)
    return

  pst.Str(@MsgJTAGulating)
  u.TXSEnable   ' Enable level shifter outputs

  num := 0   ' Counter of possible pinouts
  ctr := 0
  xtxd := xrxd := xbaud := 0
  repeat uTXD from txdStart to txdEnd   ' For every possible pin permutation...
    repeat uRXD from rxdStart to rxdEnd
      if (uRXD == uTXD)
        next

      u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH (in case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#)

      if (pinsLow == 1)     ' Pulse channels LOW if requested by the user
        u.Set_Pins_Low(chStart, chEnd)      ' Set current channel range to output LOW
        u.Pause(pinsLowDelay)               ' Delay to stay asserted
        u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH
        u.Pause(pinsHighDelay)              ' Delay after deassertion before proceeding

      repeat baud_idx from 0 to (constant(BaudRateEnd - BaudRate) >> 2) - 1   ' For every possible baud rate in BaudRate table...
        if (pst.RxEmpty == 0)        ' Abort scan if any key is pressed
          UART_Scan_Cleanup(num, xtxd, xrxd, xbaud)
          pst.Str(@ErrUARTAborted)
          pst.RxFlush
          return

        uBaud := BaudRate[baud_idx]        ' Store current baud rate into uBaud variable

        dira[uTXD] := 0                    ' Set current pins as inputs (UART cog will configure as needed)
        dira[uRXD] := 0
        UART.Start(|<uTXD, |<uRXD, uBaud)  ' Start UART cog
        u.Pause(10)                        ' Delay for cog setup
        UART.RxFlush                       ' Flush receive buffer

        if (uHex == 0)                     ' If the user string is ASCII
          UART.str(@uSTR)                    ' Send string to target
          UART.tx(CR)                        ' Send carriage return to target
        else                               ' Otherwise, send uHex number of hex bytes
          i := 0
          repeat uHex
            UART.tx(byte[@uSTR][i++])

        if (uWaitDelay > 0)                ' Delay before checking for response from the target
          u.Pause(uWaitDelay)

        if (UART_Get_Display_Data)         ' Check for a response from the target and display data
          num += 1                           ' Increment counter
          uPinsKnown := 1                    ' Enable known pins flag
          xtxd := uTXD                       ' Keep track of most recent detection results
          xrxd := uRXD
          xbaud := uBaud

    ' Progress indicator
      ++ctr
      Display_Progress(ctr, 1, 1)

  if (num == 0)
    pst.Str(@ErrNoDeviceFound)
    uPinsKnown := 0

  UART_Scan_Cleanup(num, xtxd, xrxd, xbaud)

  pst.Str(String(CR, LF, "UART"))
  pst.Str(@MsgScanComplete)


PRI UART_Scan_TXD | i, t, ch, chmask, ctr, ctr_in, num, exit, xtxd, xbaud    ' Identify UART pinout (TXD only, continuous automatic baud rate detection)
  pst.Str(@MsgUARTPinout)

  if (Get_Channels(1) == -1)        ' Get the channel range to use
    return

  if (UART_Get_NonStandard == -1)   ' Ignore non-standard baud rates?
    return

  if (Wait_For_Space(@ErrUARTAborted) == -1)
    return

  pst.Str(String(CR, LF, "Note: This scan will continuously monitor all channels for UART", CR, LF, "activity until aborted."))
  pst.Str(@MsgJTAGulating)

  u.TXSEnable                       ' Enable level shifter outputs
  u.Set_Pins_Input(chStart, chEnd)  ' Set current channel range to input
  u.Pause(25)                       ' Delay for pins to settle

  uRXD := g#PROP_SDA  ' RXD isn't used in this command, so set it to a temporary pin so it doesn't interfere with enumeration

  num := 0   ' Counter of possible pinouts
  xtxd := xbaud := 0
  exit := 0
  repeat
    i := ina[chEnd..chStart]                             ' Read current state of channels
    repeat while (chmask := ina[chEnd..chStart]) == i    ' Wait until there's a change on one or more channels
      ' Progress indicator
      ++ctr
      Display_Progress(ctr, $4000, 1)

      if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
        exit := 1
        quit

    if (exit)
      quit
    else
      chmask ^= i                ' Isolate the bits that changed (will be set to 1)
      chmask &= $00FFFFFF        ' Mask bits representing CH23..0
      chmask <<= chStart         ' Shift bits into the correct position based on channel range

      ' Monitor each channel individually
      ch := 0
      repeat while (ch < g#MAX_CHAN)
        if (chmask & 1)
          i := UART_PULSE_COUNT                ' Number of pulses to measure
          pulse.Start(ch, @i, @vBuf)           ' Start pulse width detection cog (number of detected negative-going pulses returned in i)
          u.Pause(UART_PULSE_DELAY)            ' Delay for cog to capture pulses (if they exist on the current channel)
          pulse.Stop                           ' Stop pulse width detection cog

          if (i == UART_PULSE_COUNT)           ' If we've measured a full array of pulses
            sort.pasmshellsort(@vBuf, i, sort#ASC)    ' Sort the pulses (in clock ticks) from shortest [0] to largest

            i := $7FFFFFFF
            repeat t from UART_PULSE_ARRAY_L to UART_PULSE_ARRAY_H   ' Look for the narrowest pulse within the specified range
              i <#= vBuf[t]      ' Assume this represents the minimum bit width of a UART signal

            if (i > 0)
              t := clkfreq / i                     ' Temporarily store the measured baud rate (result is 0 if i = 0)
              uTXD := ch                           ' Store the current channel
              uBaud := UART_Best_Fit(t)            ' Locate best fit value for measured baud rate (if it exists, 0 otherwise)

              if !(uBaud == 0 and uBaudIgnore == 1)
                Display_UART_Pins(1, t)              ' Display current UART pinout

                num += 1                             ' Increment counter
                uPinsKnown := 1                      ' Enable known pins flag
                xtxd := uTXD                         ' Keep track of most recent detection results
                xbaud := uBaud

                !outa[g#LED_G]                       ' Toggle LED between red and yellow
              else                                   ' If we receive pulses, but are ignoring them
                ' Progress indicator
                ++ctr_in
                Display_Progress(ctr_in, 30, 1)

        ch += 1        ' Increment current channel
        chmask >>= 1   ' Shift to the next bit in the channel mask

    if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
      quit

  if (num == 0)
    uPinsKnown := 0

  UART_Scan_Cleanup(num, xtxd, 0, xbaud)  ' RXD isn't used in this command
  pst.RxFlush

  pst.Str(String(CR, LF, "UART TXD"))
  pst.Str(@MsgScanComplete)


PRI UART_Get_Display_Data : display | i, value, data[MAX_LEN_UART_RX >> 2]   ' Check for a response from the target and display data (UART.Start must be called first)
  i := 0

  repeat while (i < MAX_LEN_UART_RX)    ' Check for a response from the target and grab up to MAX_LEN_UART_RX bytes
    value := UART.RxTime(UART_SCAN_DELAY)   ' Wait up to UART_SCAN_DELAY (in ms) to receive a byte from the target
    if (value < 0)                          ' If there's no data...
      quit                                    ' Exit the loop
    byte[@data][i++] := value               ' Store the byte in our array and try for more

  if (i > 0)                           ' If we've received any data...
    display := 1                         ' Set flag to display all data by default
    if (uPrintable == 1)                 ' If user only wants to see printable characters
      repeat value from 0 to (i-1)         ' For entire buffer
        if (byte[@data][value] < $20 or byte[@data][value] > $7E) and (byte[@data][value] <> CR and byte[@data][value] <> LF) ' If any byte is unprintable (except for CR or LF)
          display := 0                       ' Clear flag to skip the entire result

    if (display == 1)
      Display_UART_Pins(0, 0)              ' Display current UART pinout
      pst.Str(String("Data: "))            ' Display the data in ASCII
      repeat value from 0 to (i-1)         ' For entire buffer
        if (byte[@data][value] < $20) or (byte[@data][value] > $7E) ' If the byte is an unprintable character
          pst.Char(".")                                               ' Print a . instead
        else
          pst.Char(byte[@data][value])

      pst.Str(String(" [ "))
      repeat value from 0 to (i-1)        ' Display the data in hexadecimal
        pst.Hex(byte[@data][value], 2)
        pst.Char(" ")
      pst.Str(String("]", CR, LF))


PRI UART_Best_Fit(actual) : bestfit    ' Locate best fit value for measured baud rate (if it exists, return 0 otherwise)
  case actual                          ' +/- 5% tolerance unless otherwise noted
    2280..2520       : bestfit := 2400
    3420..3780       : bestfit := 3600
    4560..5040       : bestfit := 4800
    6840..7560       : bestfit := 7200
    9120..10080      : bestfit := 9600
    13680..15120     : bestfit := 14400
    18240..20160     : bestfit := 19200
    27360..30240     : bestfit := 28800
    30241..32813     : bestfit := 31250      ' - reduced
    36480..40320     : bestfit := 38400
    54720..60480     : bestfit := 57600
    72960..80640     : bestfit := 76800
    109440..120960   : bestfit := 115200
    145920..161280   : bestfit := 153600
    218880..241920   : bestfit := 230400
    241921..262500   : bestfit := 250000     ' - reduced
    291840..322560   : bestfit := 307200
    328320..362880   : bestfit := 345600
    437760..483840   : bestfit := 460800
    875520..949248   : bestfit := 921600     ' + 3%
    949249..988800   : bestfit := 960000     ' +/- 3%
    988801..1050000  : bestfit := 1000000    ' - reduced
    1140000..1260000 : bestfit := 1200000
    1425000..1575000 : bestfit := 1500000


PRI UART_Passthrough | ch, cog    ' UART/terminal passthrough
  pst.Str(@MsgUARTPinout)

  pst.Str(String(CR, LF, "Enter X to disable either pin, if desired."))
  if (Set_UART(1) == -1)     ' Ask user for the known UART configuration
    return                     ' Abort if error

  ' If the user has selected to disable one of the pins, set it to a temporary pin so it doesn't interfere
  if (uTXD == -2)
    uTXD := g#PROP_SDA
  elseif (uRXD == -2)
    uRXD := g#PROP_SDA

  pst.Str(String(CR, LF, "Enable local echo? ["))
  if (uLocalEcho == 0)
    pst.Str(String("y/N]: "))
  else
    pst.Str(String("Y/n]: "))
  pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
  if (strsize(@vCmd) =< 1)            ' We're only looking for a single character (or NULL, which will have a string size of 0)
    case vCmd[0]                        ' Check the first character of the input string
        0:                                ' The user only entered a CR, so keep the same value and pass through.
        "N", "n":
          uLocalEcho := 0                   ' Disable flag
        "Y", "y":
          uLocalEcho := 1                   ' Enable flag
        other:
          pst.Str(@ErrOutOfRange)
          return
  else
    pst.Str(@ErrOutOfRange)
    return

  pst.Str(String(CR, LF, "Entering UART passthrough! Press Ctrl-X to exit...", CR, LF))

  ' Based on Serial_Pass_Through.spin from Chapter 4 of
  ' https://www.parallax.com/sites/default/files/downloads/122-32450-XBeeTutorial-v1.0.1.pdf
  u.TXSEnable                               ' Enable level shifter outputs
  PT_In.Init(uTXD, uBaud)                   ' Start serial port, receive only from target
  PT_Out.Init(uRXD, uBaud)                  ' Start serial port, transmit only to target
  u.Pause(50)                               ' Delay for cog setup
  cog := cognew(RX_from_Target, @vBuf) + 1  ' Start cog for target -> PC communication

  pst.RxFlush
  PT_Out.flush
  if (uLocalEcho == 0)                       ' If local echo is off...
    repeat                                     ' Stay in passthrough mode until cancel value is received
      if ((ch := pst.CharInNoEcho) <> CAN)       ' If the PC buffer contains data...
        PT_Out.tx(ch)                              ' ...send to the target
    until (ch == CAN)
  else                                       ' If local echo is on...
    repeat                                     ' Stay in passthrough mode until cancel value is received
      if ((ch := pst.CharIn) <> CAN)             ' If the PC buffer contains data...
        PT_Out.tx(ch)                              ' ...send to the target
    until (ch == CAN)

  ' Stop passthrough cogs
  cogstop(cog~ - 1)
  PT_Out.Cleanup
  PT_In.Cleanup

  ' Reset pin if it was disabled
  if (uTXD => g#MAX_CHAN)
    uTXD := 0
  elseif (uRXD => g#MAX_CHAN)
    uRXD := 0

  pst.Str(String(CR, LF, "UART passthrough complete."))


PUB RX_from_Target
  PT_In.flush
  repeat
    pst.Char(PT_In.rx)      ' Get data from target and send to the PC


PRI Set_UART(askBaud) : err | xtxd, xrxd, xbaud            ' Set UART configuration to known values
  ' An "X" or "x" character may be sent by the user to disable the TXD or RXD pin. This will result in Get_Pin returning a -2 value.
  pst.Str(String(CR, LF, "Enter TXD pin ["))
  pst.Dec(uTXD)               ' Display current value
  pst.Str(String("]: "))
  xtxd := Get_Pin             ' Get new value from user
  if (xtxd == -1)             ' If carriage return was pressed...
    xtxd := uTXD                ' Keep current setting
  if (xtxd < -2) or (xtxd > g#MAX_CHAN-1)  ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  pst.Str(String(CR, LF, "Enter RXD pin ["))
  pst.Dec(uRXD)               ' Display current value
  pst.Str(String("]: "))
  xrxd := Get_Pin             ' Get new value from user
  if (xrxd == -1)             ' If carriage return was pressed...
    xrxd := uRXD                ' Keep current setting
  if (xrxd < -2) or (xrxd > g#MAX_CHAN-1)  ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  ' Make sure that the pin numbers are unique
  if (xtxd == xrxd)  ' If we have a collision
    pst.Str(@ErrPinCollision)
    return -1                 ' Then exit

  ' Update the globals with the new values
  uTXD := xtxd
  uRXD := xrxd

  if (askBaud)
    pst.Str(String(CR, LF, "Enter baud rate ["))
    pst.Dec(uBaud)              ' Display current value
    pst.Str(String("]: "))
    xbaud := Get_Decimal_Pin    ' Get new value from user
    if (xbaud == -1)            ' If carriage return was pressed...
      xbaud := uBaud              ' Keep current setting
    if (xbaud < BaudRate[0]) or (xbaud > BaudRate[(constant(BaudRateEnd - BaudRate) >> 2) - 1])  ' If entered value is out of range, abort
      pst.Str(@ErrOutOfRange)
      return -1

    ' Update the global with the new value
    uBaud := xbaud


PRI UART_Scan_Cleanup(num, txd, rxd, baud)
  UART.Stop       ' Disable UART cog (if it was running)

  if (num == 0)   ' If no device(s) were found during the search
    longfill(@uTXD, 0, 3)  ' Clear UART pinout + settings
  else             ' Update globals with the most recent detection results
    uTXD := txd
    uRXD := rxd
    uBaud := baud


PRI UART_Get_Printable : err
  pst.Str(String(CR, LF, LF, "Ignore non-printable characters? ["))
  if (uPrintable == 0)
    pst.Str(String("y/N]: "))
  else
    pst.Str(String("Y/n]: "))
  pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
  if (strsize(@vCmd) =< 1)            ' We're only looking for a single character (or NULL, which will have a string size of 0)
    case vCmd[0]                        ' Check the first character of the input string
        0:                                ' The user only entered a CR, so keep the same value and pass through.
        "N", "n":
          uPrintable := 0                   ' Disable flag
        "Y", "y":
          uPrintable := 1                   ' Enable flag
        other:
          pst.Str(@ErrOutOfRange)
          return -1
  else
    pst.Str(@ErrOutOfRange)
    return -1


PRI UART_Get_NonStandard : err
  pst.Str(String(CR, LF, LF, "Ignore non-standard baud rates? ["))
  if (uBaudIgnore == 0)
    pst.Str(String("y/N]: "))
  else
    pst.Str(String("Y/n]: "))
  pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
  if (strsize(@vCmd) =< 1)            ' We're only looking for a single character (or NULL, which will have a string size of 0)
    case vCmd[0]                        ' Check the first character of the input string
        0:                                ' The user only entered a CR, so keep the same value and pass through.
        "N", "n":
          uBaudIgnore := 0             ' Disable flag
        "Y", "y":
          uBaudIgnore := 1             ' Enable flag
        other:
          pst.Str(@ErrOutOfRange)
          return -1
  else
    pst.Str(@ErrOutOfRange)
    return -1


PRI Display_UART_Pins(txdOnly, mBaud)   ' Display UART pin configuration
{
 txdOnly: 0 from UART_Scan (fixed baud rate), 1 from UART_Scan_TXD (auto baud rate detection)
 mBaud: measured potential baud rate from UART_Scan_TXD (ignored if txdOnly = 0)
}
  pst.Str(String(CR, LF, "TXD: "))
  pst.Dec(uTXD)

  if (txdOnly == 0 and uRXD <> g#PROP_SDA)
    pst.Str(String(CR, LF, "RXD: "))
    pst.Dec(uRXD)

  if (txdOnly == 0)
    pst.Str(String(CR, LF, "Baud: "))
    pst.Dec(uBaud)
  else
    pst.Str(String(CR, LF, "Baud (Measured): "))
    pst.Dec(mBaud)

    pst.Str(String(CR, LF, "Baud (Best Fit): "))
      if (uBaud == 0)
        pst.Str(String("N/A"))
      else
        pst.Dec(uBaud)

  pst.Str(String(CR, LF))


CON {{ GPIO METHODS }}

PRI GPIO_Init
  ' Set default parameters
  ' Write_IO_Pins
  gWriteValue := $FFFFFF


PRI Read_IO_Pins | value            ' Read all channels (input, one shot)
  pst.Char(CR)

  u.TXSEnable                       ' Enable level shifter outputs
  dira[g#MAX_CHAN-1..0]~            ' Set all channels as inputs
  value := ina[g#MAX_CHAN-1..0]     ' Read all channels

  Display_IO_Pins(value)            ' Display value


PRI Monitor_IO_Pins | value, prev   ' Read all channels (input, continuous)
  pst.Str(String(CR, LF, "Reading all channels! Press any key to abort...", CR, LF))

  u.TXSEnable                       ' Enable level shifter outputs
  dira[g#MAX_CHAN-1..0]~            ' Set all channels as inputs
  prev := -1

  repeat until (pst.RxEmpty == 0)   ' Repeat until any key is pressed
    value := ina[g#MAX_CHAN-1..0]     ' Read all channels
    if (value <> prev)                ' If there's a change in state...
      prev := value                   ' Save new value
      Display_IO_Pins(value)          ' Display value
      !outa[g#LED_G]                  ' Toggle LED between red and yellow

  pst.RxFlush


PRI Write_IO_Pins : err | value     ' Write all channels (output)
  pst.Str(String(CR, LF, "Enter value to output (in hex) ["))
  pst.Hex(gWriteValue, g#MAX_CHAN >> 2)  ' Display current value
  pst.Str(String("]: "))

  ' Receive hexadecimal value from the user and perform input sanitization
  ' This has do be done directly in the object since we may need to handle user input up to 32 bits
  pst.StrInMax(@vCmd,  MAX_LEN_CMD)
  if (vCmd[0]==0)   ' If carriage return was pressed...
     value := gWriteValue
  else
    if strsize(@vCmd) > (g#MAX_CHAN >> 2)  ' If value is larger than the our number of channels
      pst.Str(@ErrOutOfRange)
      return -1

    if (str.is_hex(@vCmd) == false)  ' Make sure each character in the string is hexadecimal ("0"-"9","A"-"F","a"-"f")
      pst.Str(@ErrOutOfRange)
      return -1

    value := pst.StrToBase(@vCmd, 16)   ' Convert valid string into actual value

  gWriteValue := value   ' Update global with new value

  u.TXSEnable                       ' Enable level shifter outputs
  dira[g#MAX_CHAN-1..0]~~           ' Set all channels as outputs
  outa[g#MAX_CHAN-1..0] := value    ' Write value to output

  Display_IO_Pins(value)            ' Display value

  pst.Str(String(CR, LF, "Press any key when done..."))
  pst.CharIn       ' Wait for any key to be pressed before finishing routine (and disabling level translators)


PRI Display_IO_Pins(value) | count
  pst.Str(String(CR, LF, "CH"))
  pst.Dec(g#MAX_CHAN-1)
  pst.Str(String("..CH0: "))

  ' ...as binary characters (0/1)
  repeat count from (g#MAX_CHAN-8) to 0 step 8
    pst.Bin(value >> count, 8)
    pst.Char(" ")

  ' ...as hexadecimal
  pst.Str(String(" (0x"))
  pst.Hex(value, g#MAX_CHAN >> 2)
  pst.Str(String(")"))


PRI GPIO_Logic(first_time) | ackbit   ' Logic analyzer (OLS/SUMP)
  pst.Str(@MsgModeWarning)

  if (first_time == 1)
    u.LEDRed

    ackbit := 0       ' Set flags so JTAGulator will start up in logic analyzer mode on next reset
    ackbit += writeLong(eepromAddress + EEPROM_MODE_OFFSET, MODE_SUMP)
    ackbit += writeLong(eepromAddress + EEPROM_VTARGET_OFFSET, vTargetIO)

    if ackbit         ' If there's an error with the EEPROM
      pst.Str(@ErrEEPROMNotResponding)
      return

    pst.Str(String(CR, LF, "Entering logic analyzer mode! Press Ctrl-X to exit..."))
    pst.Str(@MsgSUMPNote)
    u.Pause(100)      ' Delay to finish sending messages
    pst.Stop          ' Stop serial communications (this will be restarted from within the sump object)

  longfill (@vBuf, 0, sump#MAX_SAMPLE_PERIODS)  ' Clear input buffer
  sump.Go(@vBuf)

  ' Exit from logic analyzer mode
  pst.Start(115_200)     ' Re-start serial communications

  ackbit := 0            ' Clear flag so JTAGulator will start up normally on next reset
  ackbit += writeLong(eepromAddress + EEPROM_MODE_OFFSET, MODE_NORMAL)

  if ackbit              ' If there's an error with the EEPROM
    pst.Str(@ErrEEPROMNotResponding)

  if (first_time == 0)   ' If we're returning from being disconnected, revert to default values
    Set_Config_Defaults

  pst.Str(String(CR, LF, "Logic analyzer mode complete."))


CON {{ SWD METHODS }}

PRI SWD_Init
  ' Don't know any SWD pins yet.
  swdPinsKnown := 0
  swdClk := 0
  swdIo := 0
  swdFrequency := swd#SWD_DEFAULT_CLOCK_RATE


PRI SWD_IDCODE_Scan | response, idcode, ctr, num, xclk, xio     ' Identify SWD pinout (IDCODE Scan)
  pst.Str(@MsgSWDWarning)

  if (Get_Channels(2) == -1)   ' Get the channel range to use
    return
  Display_Permutations((chEnd - chStart + 1), 2)  ' SWCLK, SWDIO

  if (Get_Settings == -1)      ' Get configurable scan settings
    return

  if (Wait_For_Space(@ErrIDCODEAborted) == -1)
    return

  pst.Str(@MsgJTAGulating)
  u.TXSEnable   ' Enable level shifter outputs
         
  swd.init      ' Initialize SWD host module
  num := 0      ' Counter of possibly good pinouts
  ctr := 0      ' Counter of total loop iterations
  xclk := xio := 0
  repeat swdClk from chStart to chEnd   ' For every possible pin permutation
    repeat swdIo from chStart to chEnd
      if (swdIo == swdClk)
        next

      if (pst.RxEmpty == 0)  ' Abort scan if any key is pressed
        SWD_Scan_Cleanup(num, xclk, xio)
        pst.Str(@ErrIDCODEAborted)
        pst.RxFlush
        return

      u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH (in case there is a signal on the target that needs to be held HIGH, like TRST# or SRST#)
        
      if (pinsLow == 1)     ' Pulse channels LOW if requested by the user
        u.Set_Pins_Low(chStart, chEnd)      ' Set current channel range to output LOW
        u.Pause(pinsLowDelay)               ' Delay to stay asserted
        u.Set_Pins_High(chStart, chEnd)     ' Set current channel range to output HIGH  
        u.Pause(pinsHighDelay)              ' Delay after deassertion before proceeding 

      ' Use this pin mapping with the SWD module to attempt line resetting the device
      ' and reading out the IDCODE register.
      swd.config(swdClk, swdIo, swdFrequency)
      response := swd.resetSwJtagAndReadIdCode(@idcode)

      ' The IDCODE was most likely read out successfully with this pin mapping if
      ' the response code is OK (%001) and the least significant bit of the returned
      ' IDCODE is 1 (unless all bits of IDCODE are 1 which isn't valid).
      if (response == swd#RESP_OK) and (idcode <> -1) and (idcode & 1)
        Display_SWD_Pins
        ' Track this most recent detection results.
        num++
        xclk := swdClk
        xio := swdIo
        Display_Device_ID(idcode, 1, 0)     ' SWD doesn't support device chaining, so there will only be a single device per pin permutation
        pst.Str(String(CR, LF))
            
      ' Progress indicator
      ++ctr
      if (pinsLow == 0)
        Display_Progress(ctr, 30, 1)
      else
        Display_Progress(ctr, 1, 1) 

  if (num == 0)
    pst.Str(@ErrNoDeviceFound)
      
  SWD_Scan_Cleanup(num, xclk, xio)
  
  pst.Str(String(CR, LF, "IDCODE"))
  pst.Str(@MsgScanComplete)
  

PRI SWD_IDCODE_Known | response, idcode   ' Get SWD Device ID (Pinout already known)
  pst.Str(@MsgSWDWarning)

  if (Set_SWD == -1)  ' Ask user for the known SWD pinout
    return              ' Abort if error

  u.TXSEnable         ' Enable level shifter outputs

  swd.init      ' Initialize SWD host module

  ' SWD doesn't support device chaining, so there will only be a single device per pin permutation
  ' Use this pin mapping with the SWD module to attempt line resetting the device
  ' and reading out the IDCODE register.
  swd.config(swdClk, swdIo, swdFrequency)
  response := swd.resetSwJtagAndReadIdCode(@idcode)

  ' The IDCODE was most likely read out successfully with this pin mapping if
  ' the response code is OK (%001) and the least significant bit of the returned
  ' IDCODE is 1 (unless all bits of IDCODE are 1 which isn't valid).
  if (response == swd#RESP_OK) and (idcode <> -1) and (idcode & 1)
    Display_Device_ID(idcode, 1, 0)   ' Display Device ID (with details)
  else
    pst.Str(@ErrNoDeviceFound)

  swd.uninit    ' Cleanup SWD host module
  pst.Str(@MsgIDCODEDisplayComplete)


PRI SWD_Scan_Cleanup(num, clk, io)
  swd.uninit    ' Cleanup SWD host module
  if (num == 0)    ' If no device(s) were found during the search
    longfill(@swdClk, 0, 2)  ' Clear SWD pinout
    swdPinsKnown := 0
  else             ' Update globals with the most recent detection results
    swdClk := clk
    swdIo := io
    swdPinsKnown := 1


PRI Display_SWD_Pins
  pst.Str(String(CR, LF, "SWDIO: "))
  pst.Dec(swdIo)
  pst.Str(String(CR, LF, "SWCLK: "))
  pst.Dec(swdClk)
  pst.Str(String(CR, LF))


PRI Set_SWD : err | xio, xclk, buf, c     ' Set SWD configuration to known values
  pst.Str(String(CR, LF, "Enter SWDIO pin ["))
  pst.Dec(swdIo)             ' Display current value
  pst.Str(String("]: "))
  xio := Get_Decimal_Pin     ' Get new value from user
  if (xio == -1)             ' If carriage return was pressed...
    xio := swdIo                ' Keep current setting
  if (xio < 0) or (xio > g#MAX_CHAN-1)  ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  pst.Str(String(CR, LF, "Enter SWCLK pin ["))
  pst.Dec(swdClk)               ' Display current value
  pst.Str(String("]: "))
  xclk := Get_Decimal_Pin     ' Get new value from user
  if (xclk == -1)             ' If carriage return was pressed...
    xclk := swdClk                ' Keep current setting
  if (xclk < 0) or (xclk > g#MAX_CHAN-1)  ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  ' Make sure that the pin numbers are unique
  ' Set bit in a long corresponding to each pin number
  buf := 0
  buf |= (1 << xio)
  buf |= (1 << xclk)

  ' Count the number of bits that are set in the long
  c := 0
  repeat 32
    c += (buf & 1)
    buf >>= 1

  if (c <> 2)         ' If there are not exactly 2 bits set (SWDIO, SWCLK), then we have a collision
    pst.Str(@ErrPinCollision)
    return -1
  else                ' If there are no collisions, update the globals with the new values
    swdIo := xio
    swdClk := xclk


CON {{ OTHER METHODS }}

PRI System_Init
  ' Set direction of I/O pins
  ' Output
  dira[g#TXS_OE] := 1
  dira[g#LED_R]  := 1
  dira[g#LED_G]  := 1

  ' Set I/O pins to the proper initialization values
  u.TXSDisable    ' Disable level shifter outputs (high impedance)
  u.LedYellow     ' Yellow = system initialization

  ' Set up PWM channel for DAC output
  ' Based on Andy Lindsay's PropBOE D/A Converter (http://learn.parallax.com/node/107)
  ctra[30..26]  := %00110       ' Set CTRMODE to PWM/duty cycle (single ended) mode
  ctra[5..0]    := g#DAC_OUT    ' Set APIN to desired pin
  dira[g#DAC_OUT] := 1          ' Set pin as output
  DACOutput(0)                  ' DAC output off

  ' Set default values
  pinsLow := 0
  pinsLowDelay := 100
  pinsHighDelay := 100

  idMenu := MENU_MAIN           ' Set default menu

  eeprom.Initialize(eeprom#BootPin)    ' Setup I2C

  pst.Start(115_200)            ' Start serial communications


PRI Set_Config_Defaults    ' Set configuration globals to default values
  vMode := MODE_NORMAL                ' Operating mode
  vTargetIO := -1                     ' Target I/O voltage (undefined)
  jTDI := jTDO := jTCK := jTMS := 0   ' JTAG pins


PRI Set_Target_IO_Voltage | value
  pst.Str(String(CR, LF, "Current target I/O voltage: "))
  Display_Target_IO_Voltage

  pst.Str(String(CR, LF, "Enter new target I/O voltage (1.4 - 3.3, 0 for off): "))
  value := Get_Decimal_Pin  ' Receive decimal value (including 0)

  ' Allow whole numbers (for example, if the user entered "2", assume they meant "2.0")
  if (value == 2)
    value := 20
  if (value == 3)
    value := 30

  if (value == 0)
    vTargetIO := -1
    DACOutput(0)               ' DAC output off
    pst.Str(String(CR, LF, "Target I/O voltage off."))
  elseif (value < VTARGET_IO_MIN) or (value > VTARGET_IO_MAX)
    pst.Str(@ErrOutOfRange)
  else
    vTargetIO := value
    DACOutput(VoltageTable[vTargetIO - VTARGET_IO_MIN])    ' Look up value that corresponds to the actual desired voltage and set DAC output
    pst.Str(String(CR, LF, "New target I/O voltage set: "))
    Display_Target_IO_Voltage  ' Print a confirmation of newly set voltage
    pst.Str(String(CR, LF, "Warning: Ensure VADJ is NOT connected to target!"))


PRI Get_Pins_Known(type) : err
{
  type: 0 if JTAG, 1 if UART
}
  pst.Str(String(CR, LF, "Are any pins already known? ["))
  if (type == 0 and jPinsKnown == 0) or (type == 1 and uPinsKnown == 0)
    pst.Str(String("y/N]: "))
  else
    pst.Str(String("Y/n]: "))
  pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
  if (strsize(@vCmd) =< 1)            ' We're only looking for a single character (or NULL, which will have a string size of 0)
    case vCmd[0]                        ' Check the first character of the input string
      0:                                ' The user only entered a CR, so keep the same value and pass through
      "N", "n":
        if (type == 0)
          jPinsKnown := 0                 ' Disable flag
        else
          uPinsKnown := 0
      "Y", "y":                         ' If the user wants to use a partial pinout
        if (type == 0)
          jPinsKnown := 1                 ' Enable flag
        else
          uPinsKnown := 1
      other:                            ' Any other key causes an error
        pst.Str(@ErrOutOfRange)
        return -1
  else
    pst.Str(@ErrOutOfRange)
    return -1


PRI Get_Settings : err | value     ' Get user-configurable settings
  pst.Str(String(CR, LF, LF, "Bring channels LOW before each permutation? ["))
  if (pinsLow == 0)
    pst.Str(String("y/N]: "))
  else
    pst.Str(String("Y/n]: "))
  pst.StrInMax(@vCmd,  MAX_LEN_CMD) ' Wait here to receive a carriage return terminated string or one of MAX_LEN_CMD bytes (the result is null terminated)
  if (strsize(@vCmd) =< 1)            ' We're only looking for a single character (or NULL, which will have a string size of 0)
    case vCmd[0]                        ' Check the first character of the input string
      0:                                ' The user only entered a CR, so keep the same value and pass through.
      "N", "n":
        pinsLow := 0                     ' Disable flag
      "Y", "y":
        pinsLow := 1                     ' Enable flag
      other:
        pst.Str(@ErrOutOfRange)
        return -1
  else
    pst.Str(@ErrOutOfRange)
    return -1

  if (pinsLow == 1)
    pst.Str(String(CR, LF, "Enter length of time for channels to remain LOW (in ms, 1 - 1000) ["))
    pst.Dec(pinsLowDelay)        ' Display current value
    pst.Str(String("]: "))
    value := Get_Decimal_Pin      ' Get new value from user
    if (value <> -1)              ' If carriage return was not pressed...
      if (value < 1) or (value > 1000)  ' If entered value is out of range, abort
        pst.Str(@ErrOutOfRange)
        return -1
      pinsLowDelay := value

    pst.Str(String(CR, LF, "Enter length of time after channels return HIGH before proceeding (in ms, 1 - 1000) ["))
    pst.Dec(pinsHighDelay)        ' Display current value
    pst.Str(String("]: "))
    value := Get_Decimal_Pin      ' Get new value from user
    if (value <> -1)              ' If carriage return was not pressed...
      if (value < 1) or (value > 1000)  ' If entered value is out of range, abort
        pst.Str(@ErrOutOfRange)
        return -1
      pinsHighDelay := value


PRI Get_Channels(min_chan) : err | xstart, xend
{
  Ask user for the range of JTAGulator channels connected to target

  Parameters: min_chan = Minimum number of pins/channels required (varies with on-chip debug interface)
}
  pst.Str(String(CR, LF, "Enter starting channel ["))
  pst.Dec(chStart)               ' Display current value
  pst.Str(String("]: "))
  xstart := Get_Decimal_Pin      ' Get new value from user
  if (xstart == -1)              ' If carriage return was pressed...
    xstart := chStart              ' Keep current setting
  if (xstart < 0) or (xstart > g#MAX_CHAN-1)  ' If entered value is out of range, abort
    pst.Str(@ErrOutOfRange)
    return -1

  pst.Str(String(CR, LF, "Enter ending channel ["))
  if (chEnd < xstart)            ' If ending channel is less than starting channel...
    pst.Dec(xstart)
  else
    pst.Dec(chEnd)                 ' Display current value
  pst.Str(String("]: "))
  xend := Get_Decimal_Pin        ' Get new value from user
  if (xend == -1)                ' If carriage return was pressed...
    if (chEnd < xstart)
      xend := xstart
    else
      xend := chEnd                  ' Keep current setting
  if (xend < xstart + min_chan - 1) or (xend > g#MAX_CHAN-1)  ' If entered value is out of range, abort (channel must be greater than the minimum required for a scan)
    pst.Str(@ErrOutOfRange)
    return -1

  ' Update the globals with the new values
  chStart := xstart
  chEnd := xend


PRI Get_Pin : value | i       ' Get a number (or single character) from the user (including number 0, which prevents us from using standard Parallax Serial Terminal routines)
  pst.StrInMax(@vCmd,  MAX_LEN_CMD)
  if (vCmd[0] == 0)
    value := -1         ' Empty string, which means a carriage return was pressed
  elseif (vCmd[0] == "X" or vCmd[0] == "x")    ' If X was entered...
    if (strsize(@vCmd) > 1)   ' If the string is longer than a single character...
      value := -3               ' ...then it's invalid
    else
      value := -2
  else
    repeat i from 0 to strsize(@vCmd)-1
      case vCmd[i]
        "0".."9":                       ' If the byte entered is an actual number...
          value *= 10                     ' ...then keep converting into a decimal value
          value += (vCmd[i] - "0")
        ".", ",":                       ' Ignore decimal point
        other:
          value := -3                   ' Invalid character(s)
          quit


PRI Get_Decimal_Pin : value | i       ' Get a decimal number from the user (including number 0, which prevents us from using standard Parallax Serial Terminal routines)
  pst.StrInMax(@vCmd,  MAX_LEN_CMD)
  if (vCmd[0] == 0)
    value := -1         ' Empty string, which means a carriage return was pressed
  else
    repeat i from 0 to strsize(@vCmd)-1
      case vCmd[i]
        "0".."9":                       ' If the byte entered is an actual number...
          value *= 10                     ' ...then keep converting into a decimal value
          value += (vCmd[i] - "0")
        ".", ",":                       ' Ignore decimal point
        other:
          value := -3                   ' Invalid character
          quit


PRI Get_Bit_Field(value, highBit, lowBit) : fieldVal | mask, bitnum    ' Return the bit field within a specified range. Based on a fork by Bob Heinemann (https://github.com/BobHeinemann/jtagulator/blob/master/JTAGulator.spin)
  mask := 0

  repeat bitNum from lowBit to highBit
    mask |= |<bitNum

  fieldVal := (value & mask) >> (highBit - (highBit - lowBit))


PRI Round_Up(n) : r         ' Round up value n to the nearest divisible by 4 in order for pst.Hex to display the correct number of nibbles
  case n
    1..4:    r := 4
    5..8:    r := 8
    9..12:   r := 12
    13..16:  r := 16
    17..20:  r := 20
    21..24:  r := 24
    25..28:  r := 28
    29..32:  r := 32


PRI Bits_to_Value(n) : r    ' r = 2^n - 1, the value when all n bits are set high (for example, n = 8, r = 0b11111111 or 255d)
  r := 1
  repeat (n - 1)
    r <<= 1
    r |= 1


PRI DACOutput(dacval)
  spr[10] := dacval * 16_777_216    ' Set counter A frequency (scale = 2^32 / 256)


PRI Display_Target_IO_Voltage
  if (vTargetIO == -1)
    pst.Str(String("Undefined"))
  else
    pst.Dec(vTargetIO / 10)         ' Display vTargetIO as an x.y value
    pst.Char(".")
    pst.Dec(vTargetIO // 10)


PRI Display_Progress(ctr, mod, char)      ' Display a progress indicator during JTAGulation (every mod counts)
  if ((ctr // mod) == 0)
    !outa[g#LED_G]            ' Toggle LED between red and yellow
    if (char <> 0)
      pst.Str(@CharProgress)    ' Print character


PRI Display_Binary(data, len) | mod, count
  if (len < 8)                        ' Handle any length fewer than 8
    pst.Bin(data, len)
    pst.Char(" ")
  else
    if (mod := len // 8)              ' Handle any bits not divisible by 8
      pst.Bin(data >> 8, mod)
      pst.Char(" ")

    repeat count from (len - mod - 8) to 0 step 8   ' Display remaining bits in groups of 8 for easier reading
      pst.Bin(data >> count, 8)
      pst.Char(" ")


PRI Display_Permutations(n, r) | value, i
{
    http://www.mathsisfun.com/combinatorics/combinations-permutations-calculator.html

    Order important, no repetition
    Total pins (n)
    Number of pins needed (r)
    Number of permutations: n! / (n-r)!
}
  pst.Str(String(CR, LF, "Possible permutations: "))

  ' Thanks to Rednaxela of #tymkrs for the optimized calculation
  value := 1
  if (r <> 0)
    repeat i from (n - r + 1) to n
      value *= i

  pst.Dec(value)


PRI readLong(addrReg, dataPtr) : ackbit
  ackbit := eeprom.ReadPage(eeprom#BootPin, eeprom#EEPROM, addrReg, dataPtr, 4)


PRI writeLong(addrReg, data) : ackbit | startTime
  if eeprom.WritePage(eeprom#BootPin, eeprom#EEPROM, addrReg, @data, 4)
    return true ' an error occured during the write

  startTime := cnt ' prepare to check for a timeout
  repeat while eeprom.WriteWait(eeprom#BootPin, eeprom#EEPROM, addrReg)
     if cnt - startTime > clkfreq / 10
       return true ' waited more than a 1/10 second for the write to finish

  return false ' write completed successfully


PRI Wait_For_Space(errMsg) | ch ' Wait for spacebar to continue, ignore Enter key, any other key return -1
  pst.Str(@MsgPressSpacebarToBegin)

  repeat
    ch := pst.CharInNoEcho
    if (ch == LF) or (ch == CR)
      next
    elseif (ch <> " ")
      pst.Str(errMsg)
      return -1
  until (ch == " ")
  return


DAT
InitHeader    byte CR, LF, LF
              byte "                                    UU  LLL", CR, LF
              byte " JJJ  TTTTTTT AAAAA  GGGGGGGGGGG   UUUU LLL   AAAAA TTTTTTTT OOOOOOO  RRRRRRRRR", CR, LF
              byte " JJJJ TTTTTTT AAAAAA GGGGGGG       UUUU LLL  AAAAAA TTTTTTTT OOOOOOO  RRRRRRRR", CR, LF
              byte " JJJJ  TTTT  AAAAAAA GGG      UUU  UUUU LLL  AAA AAA   TTT  OOOO OOO  RRR RRR", CR, LF
              byte " JJJJ  TTTT  AAA AAA GGG  GGG UUUU UUUU LLL AAA  AAA   TTT  OOO  OOO  RRRRRRR", CR, LF
              byte " JJJJ  TTTT  AAA  AA GGGGGGGGG UUUUUUUU LLLLLLLL AAAA  TTT OOOOOOOOO  RRR RRR", CR, LF
              byte "  JJJ  TTTT AAA   AA GGGGGGGGG UUUUUUUU LLLLLLLLL AAA  TTT OOOOOOOOO  RRR RRR", CR, LF
              byte "  JJJ  TT                  GGG             AAA                         RR RRR", CR, LF
              byte " JJJ                        GG             AA                              RRR", CR, LF
              byte "JJJ                          G             A                                 RR", CR, LF, LF, LF
              byte "           Welcome to JTAGulator. Press 'H' for available commands.", CR, LF
              byte "         Warning: Use of this tool may affect target system behavior!", 0

VersionInfo   byte CR, LF, "JTAGulator FW ID Tracker 1.2", CR, LF
              byte "Designed by Joe Grand, Grand Idea Studio, Inc.", CR, LF
              byte "Modified by Weiao, 2025.6.20", CR, LF 
              byte "Main: jtagulator.com", CR, LF
              byte "Source: github.com/grandideastudio/jtagulator", 0

MenuMain      byte CR, LF, "Target Interfaces:", CR, LF
              byte "J   JTAG", CR, LF
              byte "U   UART", CR, LF
              byte "G   GPIO", CR, LF
              byte "S   SWD", CR, LF
              byte "A   All (GPIO, JTAG, SWD, UART)", CR, LF
              byte LF

              byte "General Commands:", CR, LF
              byte "V   Set target I/O voltage", CR, LF
              byte "I   Display version information", CR, LF
              byte "H   Display available commands", 0

MenuJTAG      byte CR, LF, "JTAG Commands:", CR, LF
              byte "J   Identify JTAG pinout (Combined Scan)", CR, LF
              byte "I   Identify JTAG pinout (IDCODE Scan)", CR, LF
              byte "B   Identify JTAG pinout (BYPASS Scan)", CR, LF
              byte "R   Identify RTCK (adaptive clocking)", CR, LF
              byte "D   Get Device ID(s)", CR, LF
              byte "T   Test BYPASS (TDI to TDO)", CR, LF
              byte "Y   Instruction/Data Register (IR/DR) discovery", CR, LF
              byte "P   Pin mapper (EXTEST Scan)", CR, LF
              byte "O   OpenOCD interface", 0

MenuUART      byte CR, LF, "UART Commands:", CR, LF
              byte "U   Identify UART pinout", CR, LF
              byte "T   Identify UART pinout (TXD only, continuous)", CR, LF
              byte "P   UART passthrough", 0

MenuGPIO      byte CR, LF, "GPIO Commands:", CR, LF
              byte "R   Read all channels (input, one shot)", CR, LF
              byte "C   Read all channels (input, continuous)", CR, LF
              byte "W   Write all channels (output)", CR, LF
              byte "L   Logic analyzer (OLS/SUMP)", 0

MenuSWD       byte CR, LF, "SWD Commands:", CR, LF
              byte "I   Identify SWD pinout (IDCODE Scan)", CR, LF
              byte "D   Get Device ID", 0

MenuShared    byte CR, LF, LF, "General Commands:", CR, LF
              byte "V   Set target I/O voltage", CR, LF
              byte "H   Display available commands", CR, LF
              byte "M   Return to main menu", 0

CharProgress  byte "-", 0   ' Character used for progress indicator

' Any messages repeated more than once are placed here to save space
MsgPressSpacebarToBegin     byte CR, LF, "Press spacebar to begin (any other key besides Enter to abort)...", 0
MsgPressSpacebarToContinue  byte "Press spacebar to continue (any other key to abort)...", 0

MsgJTAGulating              byte CR, LF, "JTAGulating! Press any key to abort...", CR, LF, 0
MsgDevicesDetected          byte "Number of devices detected: ", 0
MsgUnknownPin               byte CR, LF, "Enter X for any unknown pin.", 0

MsgScanComplete             byte " scan complete.", 0
MsgIDCODEDisplayComplete    byte CR, LF, "IDCODE listing complete.", 0
MsgEnterTDIPin              byte CR, LF, "Enter TDI pin [", 0
MsgEnterTDOPin              byte CR, LF, "Enter TDO pin [", 0
MsgEnterTCKPin              byte CR, LF, "Enter TCK pin [", 0
MsgEnterTMSPin              byte CR, LF, "Enter TMS pin [", 0
MsgIRLength                 byte "Instruction Register (IR) length: ", 0

MsgUARTPinout               byte CR, LF, "Note: UART pin naming is from the target's perspective.", 0

MsgSWDWarning               byte CR, LF, "Warning: The JTAGulator's front-end circuitry is incompatible w/"
                            byte CR, LF, "many SWD-based target devices. Detection results may be affected."
                            byte CR, LF, "Visit github.com/grandideastudio/jtagulator/wiki/Hardware-Modifications"
                            byte CR, LF, "for details.", CR, LF, 0

MsgModeWarning              byte CR, LF, "Warning: This mode persists through JTAGulator resets, power cycles,"
                            byte CR, LF, "and firmware updates. It can only be exited manually by the user.", CR, LF, 0

MsgSUMPNote                 byte CR, LF, LF, "Note: Switch to analyzer software and use Openbench Logic Sniffer driver @ 115.2kbps", CR, LF, 0

MsgOCDNote                  byte CR, LF, LF, "Example: openocd -f interface/buspirate.cfg -c ", QUOTE
                            byte "transport select jtag; buspirate port /dev/ttyUSB0", QUOTE, CR, LF, 0

MsgSpacer                   byte CR, LF, LF, "-----", 0
ErrEEPROMNotResponding      byte CR, LF, "EEPROM not responding!", 0
ErrTargetIOVoltage          byte CR, LF, "Target I/O voltage must be defined!", 0
ErrOutOfRange               byte CR, LF, "Value out of range!", 0
ErrPinCollision             byte CR, LF, "Pin numbers must be unique!", 0
ErrNoDeviceFound            byte CR, LF, "No target device(s) found!", 0
ErrTooManyDevices           byte CR, LF, "More than one device detected in the chain!", 0

ErrJTAGAborted              byte CR, LF, "JTAG combined scan aborted!", 0
ErrIDCODEAborted            byte CR, LF, "IDCODE scan aborted!", 0
ErrBYPASSAborted            byte CR, LF, "BYPASS scan aborted!", 0
ErrRTCKAborted              byte CR, LF, "RTCK scan aborted!", 0
ErrUARTAborted              byte CR, LF, "UART scan aborted!", 0
ErrEXTESTAborted            byte CR, LF, "Pin mapper aborted!", 0
ErrDiscoveryAborted         byte CR, LF, "IR/DR discovery aborted!", 0

' Look-up table to correlate actual I/O voltage to DAC value
' Full DAC range is 0 to 3.3V @ 256 steps = 12.89mV/step
' TXS0108E level translator is limited from 1.4V to 3.3V per data sheet table 6.3
'                   1.4  1.5  1.6  1.7  1.8  1.9  2.0  2.1  2.2  2.3  2.4  2.5  2.6  2.7  2.8  2.9  3.0  3.1  3.2  3.3
VoltageTable  byte  109, 116, 124, 132, 140, 147, 155, 163, 171, 179, 186, 194, 202, 210, 217, 225, 233, 241, 248, 255

' Look-up table of accepted values for use with UART_Scan
BaudRate      long  300, 600, 1200, 1800, 2400, 3600, 4800, 7200, 9600, 14400, 19200, 28800, 31250 {MIDI}, 38400, 57600, 76800, 115200, 153600, 230400, 250000 {DMX}, 307200
BaudRateEnd