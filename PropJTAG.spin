{{
+-------------------------------------------------+
| JTAG/IEEE 1149.1                                |
| Interface Object                                |
|                                                 |
| Author: Joe Grand                               |                     
| Copyright (c) 2013-2020 Grand Idea Studio, Inc. |
| Web: http://www.grandideastudio.com             |
|                                                 |
| Distributed under a Creative Commons            |
| Attribution 3.0 United States license           |
| http://creativecommons.org/licenses/by/3.0/us/  |
+-------------------------------------------------+

Program Description:

This object provides the low-level communication interface for JTAG/IEEE 1149.1
(http://en.wikipedia.org/wiki/Joint_Test_Action_Group). 

JTAG routines based on Silicon Labs' Application Note AN105: Programming FLASH
through the JTAG Interface (https://www.silabs.com/documents/public/application-
notes/an105.pdf). 

Usage: Call Config first to properly set the desired JTAG pinout
 
}}


CON
{{ IEEE Std. 1149.1 2001
   TAP Signal Descriptions

   +-----------+----------------------------------------------------------------------------------------+
   |    Name   |                                   Description                                          |
   +-----------+----------------------------------------------------------------------------------------+
   |    TDI    |    Test Data Input: Serial input for instructions and data received by the test logic. |
   |           |    Data is sampled on the rising edge of TCK.                                          |
   +-----------+----------------------------------------------------------------------------------------+ 
   |    TDO    |    Test Data Output: Serial output for instructions and data sent from the test logic. |
   |           |    Data is shifted on the falling edge of TCK.                                         |
   +-----------+----------------------------------------------------------------------------------------+
   |           |    Test Port Clock: Synchronous clock for the test logic that accompanies any data     |
   |    TCK    |    transfer. Data on the TDI is sampled by the target on the rising edge, data on TDO  |
   |           |    is output by the target on the falling edge.                                        |
   +-----------+----------------------------------------------------------------------------------------+
   |    TMS    |    Test Mode Select: Used in conjunction with TCK to navigate through the state        |
   |           |    machine. TMS is sampled on the rising edge of TCK.                                  | 
   +-----------+----------------------------------------------------------------------------------------+
   |           |    Test Port Reset: Optional signal for asynchronous initialization of the test logic. |
   |    TRST#  |    Some targets intentionally hold TRST# low to keep JTAG disabled. If so, the pin     |
   |           |    will need to be located and pulled high. This object assumes TRST# assertion (if    |
   |           |    required) is done in advance by the top object.                                     |
   +-----------+----------------------------------------------------------------------------------------+
 }}

 {{ IEEE Std. 1149.1 2001
    TAP Controller
 
    The movement of data through the TAP is controlled by supplying the proper logic level to the
    TMS pin at the rising edge of consecutive TCK cycles. The TAP controller itself is a finite state
    machine that is capable of 16 states. Each state contains a link in the operation sequence necessary
    to manipulate the data moving through the TAP.

    TAP Notes:
    1. Data is valid on TDO beginning with the falling edge of TCK on entry into the
       Shift_DR or Shift_IR states. TDO goes "push-pull" on this TCK falling edge and remains "push-pull"
       until the TCK rising edge.
    2. Data is not shifted in from TDI on entry into Shift_DR or Shift_IR.    
    3. Data is shifted in from TDI on exit of Shift_IR and Shift_DR.
 }}


CON
  MAX_DEVICES_LEN      =  32       ' Maximum number of devices allowed in a single JTAG chain

  MIN_IR_LEN           =  2        ' Minimum length of instruction register per IEEE Std. 1149.1
  MAX_IR_LEN           =  32       ' Maximum length of instruction register
  MAX_IR_CHAIN_LEN     =  MAX_DEVICES_LEN * MAX_IR_LEN  ' Maximum total length of JTAG chain w/ IR selected
  
  MAX_DR_LEN           =  1024      ' Maximum length of data register

  
VAR
  long TDI, TDO, TCK, TMS           ' JTAG globals (must stay in this order)


OBJ
 

PUB Config(tdi_pin, tdo_pin, tck_pin, tms_pin)
{
  Set JTAG configuration
  Parameters : TDI, TDO, TCK, and TMS channels provided by top object
}
  longmove(@TDI, @tdi_pin, 4)                ' Move passed variables into globals for use in this object
      
  ' Set direction of JTAG pins
  ' Output
  dira[TDI] := 1                          
  dira[TCK] := 1          
  dira[TMS] := 1

  ' Input 
  dira[TDO] := 0

  ' Ensure TCK starts low for pulsing
  outa[TCK] := 0               

 
PUB Detect_Devices : num
{
  Performs a blind interrogation to determine how many devices are connected in the JTAG chain.

  In BYPASS mode, data shifted into TDI is received on TDO delayed by one clock cycle. We can
  force all devices into BYPASS mode, shift known data into TDI, and count how many clock
  cycles it takes for us to see it on TDO.

  Leaves the TAP in the Run-Test-Idle state.

  Based on http://www.fpga4fun.com/JTAG3.html

  Returns    : Number of JTAG/IEEE 1149.1 devices in the chain (if any)
}
  Restore_Idle                ' Reset TAP to Run-Test-Idle
  Enter_Shift_IR              ' Enter Shift IR state

  ' Force all devices in the chain (if they exist) into BYPASS mode using opcode of all 1s
  TDI_High             
  repeat MAX_IR_CHAIN_LEN - 1 ' Send lots of 1s to account for multiple devices in the chain and varying IR lengths
    TCK_Pulse

  TMS_High       
  TCK_Pulse        ' Go to Exit1 IR

  TMS_High       
  TCK_Pulse        ' Go to Update IR, new instruction in effect

  TMS_High       
  TCK_Pulse        ' Go to Select DR Scan

  TMS_Low        
  TCK_Pulse        ' Go to Capture DR Scan

  TMS_Low        
  TCK_Pulse        ' Go to Shift DR Scan
                          
  repeat MAX_DEVICES_LEN      ' Send 1s to fill DRs of all devices in the chain (In BYPASS mode, DR length = 1 bit)
    TCK_Pulse 

  ' We are now in BYPASS mode with all DR set
  ' Send in a 0 on TDI and count until we see it on TDO
  TDI_Low           
  repeat num from 0 to MAX_DEVICES_LEN - 1 
    if (TDO_Read == 0)          ' If we have received our 0, it has propagated through the entire chain (one clock cycle per device in the chain)
      quit                        '  Exit loop (num gets returned)

  if (num > MAX_DEVICES_LEN - 1)  ' If no 0 is received, then no devices are in the chain
    num := 0

  TMS_High
  TCK_Pulse        ' Go to Exit1 DR

  TMS_High
  TCK_Pulse        ' Go to Update DR, new data in effect

  TMS_Low
  TCK_Pulse        ' Go to Run-Test-Idle


PUB Detect_IR_Length : num 
{
  Performs an interrogation to determine the instruction register length of the target device.
  Limited in length to MAX_IR_LEN.
  Assumes a single device in the JTAG chain.
  Leaves the TAP in the Run-Test-Idle state.

  Returns    : Length of the instruction register
}
  Restore_Idle                ' Reset TAP to Run-Test-Idle
  Enter_Shift_IR              ' Go to Shift IR

  ' Flush the IR
  TDI_Low                    
  repeat MAX_IR_LEN - 1       ' Since the length is unknown, send lots of 0s
    TCK_Pulse

  ' Once we are sure that the IR is filled with 0s
  ' Send in a 1 on TDI and count until we see it on TDO
  TDI_High       
  repeat num from 0 to MAX_IR_LEN - 1 
    if (TDO_Read == 1)          ' If we have received our 1, it has propagated through the entire instruction register
      quit                        '  Exit loop (num gets returned)

  if (num > MAX_IR_LEN - 1) or (num < MIN_IR_LEN)  ' If no 1 is received, then we are unable to determine IR length
    num := 0
    
  TMS_High
  TCK_Pulse        ' Go to Exit1 IR

  TMS_High
  TCK_Pulse        ' Go to Update IR, new instruction in effect

  TMS_Low
  TCK_Pulse        ' Go to Run-Test-Idle


PUB Detect_DR_Length(value) : num | len
{
  Performs an interrogation to determine the data register length of the target device.
  The selected data register will vary depending on the the instruction.
  Limited in length to MAX_DR_LEN.
  Assumes a single device in the JTAG chain.
  Leaves the TAP in the Run-Test-Idle state.

  Parameters : value = Opcode/instruction to be sent to TAP
  Returns    : Length of the data register
}
  len := Detect_IR_Length          ' Determine length of TAP IR
  Send_Instruction(value, len)     ' Send instruction/opcode
  Enter_Shift_DR                   ' Go to Shift DR

  ' At this point, a specific DR will be selected, so we can now determine its length.
  ' Flush the DR
  TDI_Low              
  repeat MAX_DR_LEN - 1       ' Since the length is unknown, send lots of 0s
    TCK_Pulse

  ' Once we are sure that the DR is filled with 0s
  ' Send in a 1 on TDI and count until we see it on TDO
  TDI_High             
  repeat num from 0 to MAX_DR_LEN - 1 
    if (TDO_Read == 1)          ' If we have received our 1, it has propagated through the entire data register
      quit                        '  Exit loop (num gets returned)
      
  if (num > MAX_DR_LEN - 1)   ' If no 1 is received, then we are unable to determine DR length
    num := 0
    
  TMS_High
  TCK_Pulse        ' Go to Exit1 DR

  TMS_High
  TCK_Pulse        ' Go to Update DR, new data in effect

  TMS_Low
  TCK_Pulse        ' Go to Run-Test-Idle

  
PUB Bypass_Test(num, bPattern) : value
{
  Run a Bypass through every device in the chain. 
  Leaves the TAP in the Run-Test-Idle state.

  Parameters : num = Number of devices in JTAG chain
               bPattern = 32-bit value to shift into TDI
  Returns    : 32-bit value received from TDO
}
  Restore_Idle                ' Reset TAP to Run-Test-Idle
  Enter_Shift_IR              ' Enter Shift IR state

  ' Force all devices in the chain (if they exist) into BYPASS mode using opcode of all 1s
  TDI_High              
  repeat (num * MAX_IR_LEN)   ' Send in 1s
    TCK_Pulse

  TMS_High         
  TCK_Pulse        ' Go to Exit1 IR

  TMS_High         
  TCK_Pulse        ' Go to Update IR, new instruction in effect

  TMS_Low
  TCK_Pulse        ' Go to Run-Test-Idle

  ' Shift in the 32-bit pattern
  ' Each device in the chain delays the data propagation by one clock cycle
  value := Send_Data(bPattern, 32 + num)
  value ><= 32     ' Bitwise reverse since LSB came in first (we want MSB to be first)


PUB Get_Device_IDs(num, idptr) | data, i, bits
{
  Retrieves the JTAG device ID from each device in the chain. 
  Leaves the TAP in the Run-Test-Idle state.

  The Device Identification register (if it exists) should be immediately available
  in the DR after power-up of the target device or after TAP reset.

  Parameters : num = Number of devices in JTAG chain
               idptr = Pointer to memory in which to store the received 32-bit device IDs (must be large enough for all IDs) 
}
{{ IEEE Std. 1149.1 2001
   Device Identification Register

   MSB                                                                          LSB
   +-----------+----------------------+---------------------------+--------------+
   |  Version  |      Part Number     |   Manufacturer Identity   |   Fixed (1)  |
   +-----------+----------------------+---------------------------+--------------+
      31...28          27...12                  11...1                   0
}}
  Restore_Idle                      ' Reset TAP to Run-Test-Idle
  Enter_Shift_DR                    ' Go to Shift DR

  TDI_High         ' TDI is ignored when shifting IDCODE, but we need to set a default state
  TMS_Low          ' Ensure we remain in Shift DR
  
  repeat i from 0 to (num - 1)      ' For each device in the chain...
    data := 0
    repeat bits from 0 to 31          ' For each bit in the 32-bit IDCODE
      data <<= 1
      data |= TDO_Read                  ' Receive data from DR (should be IDCODE if exists)
      
    data ><= 32                       ' Bitwise reverse since LSB came in first (we want MSB to be first)
    long[idptr][i] := data            ' Store it in hub memory
  
  Restore_Idle                      ' Reset TAP to Run-Test-Idle


PUB Send_Instruction(instruction, num_bits) : ret_value
{
    This method loads the supplied instruction of num_bits length into the target's Instruction Register (IR).
    The return value is the num_bits length value read from the IR (limited to 32 bits).
    TAP must be in Run-Test-Idle state before being called.
    Leaves the TAP in the Run-Test-Idle state.
}
{{ IEEE Std. 1149.1 2001
   Instructions
   
   Instruction Register/Opcode length vary per device family
   IR length must >= 2

   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |    Name   |  Required?  |  Opcode  |                          Description                                  |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |   BYPASS  |      Y      |  All 1s  |   Bypass on-chip system logic. Allows serial data to be transferred   |
   |           |             |          |   from TDI to TDO without affecting operation of the IC.              |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |   SAMPRE  |      Y      |  Varies  |   Used for controlling (preload) or observing (sample) the signals at |
   |           |             |          |   device pins. Enables the boundary scan register.                    |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |   EXTEST  |      Y      |  All 0s  |   Places the IC in external boundary test mode. Used to test device   |
   |           |             |          |   interconnections. Enables the boundary scan register.               |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |   INTEST  |      N      |  Varies  |   Used for static testing of internal device logic in a single-step   |
   |           |             |          |   mode. Enables the boundary scan register.                           |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |   RUNBIST |      N      |  Varies  |   Places the IC in a self-test mode and selects a user-specified data |
   |           |             |          |   register to be enabled.                                             |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |   CLAMP   |      N      |  Varies  |   Sets the IC outputs to logic levels as defined in the boundary scan |
   |           |             |          |   register. Enables the bypass register.                              |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |   HIGHZ   |      N      |  Varies  |   Sets all IC outputs to a disabled (high impedance) state. Enables   |
   |           |             |          |   the bypass register.                                                |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |   IDCODE  |      N      |  Varies  |   Enables the 32-bit device identification register. Does not affect  |
   |           |             |          |   operation of the IC.                                                |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
   |  USERCODE |      N      |  Varies  |   Places user-defined information into the 32-bit device              |
   |           |             |          |   identification register. Does not affect operation of the IC.       |
   +-----------+-------------+----------+-----------------------------------------------------------------------+
}}    
  Enter_Shift_IR

  ret_value := Shift_Array(instruction, num_bits)

  TMS_High
  TCK_Pulse        ' Go to Update IR, new instruction in effect

  TMS_Low
  TCK_Pulse        ' Go to Run-Test-Idle


PUB Send_Data(data, num_bits) : ret_value
{
    This method shifts num_bits of data into the target's Data Register (DR). 
    The return value is the num_bits length value read from the DR (limited to 32 bits).
    TAP must be in Run-Test-Idle state before being called.
    Leaves the TAP in the Run-Test-Idle state.
}   
  Enter_Shift_DR

  ret_value := Shift_Array(data, num_bits)

  TMS_High
  TCK_Pulse        ' Go to Update DR, new data in effect

  TMS_Low
  TCK_Pulse        ' Go to Run-Test-Idle


PRI Shift_Array(array, num_bits) : ret_value | i 
{
    Shifts an array of bits into the TAP while reading data back out.
    This method is called when the TAP state machine is in the Shift_DR or Shift_IR state.
}
  ret_value := 0
  
  repeat i from 1 to num_bits
    if (i == num_bits)        ' If at final bit...
      TMS_High     ' Go to Exit1

    if (array & 1)            ' Output data to target, LSB first
      TDI_High
    else
      TDI_Low
   
    array >>= 1 

    ret_value <<= 1     
    ret_value |= TDO_Read     ' Receive data, shift order depends on target

       
PRI Enter_Shift_DR      ' 
{
    Move TAP to the Shift-DR state.
    TAP must be in Run-Test-Idle state before being called.
}
  TMS_High
  TCK_Pulse        ' Go to Select DR Scan

  TMS_Low
  TCK_Pulse        ' Go to Capture DR

  TMS_Low
  TCK_Pulse        ' Go to Shift DR
  

PRI Enter_Shift_IR  
{
    Move TAP to the Shift-IR state.
    TAP must be in Run-Test-Idle state before being called.
}
  TMS_High
  TCK_Pulse        ' Go to Select DR Scan

  TMS_High
  TCK_Pulse        ' Go to Select IR Scan

  TMS_Low
  TCK_Pulse        ' Go to Capture IR

  TMS_Low
  TCK_Pulse        ' Go to Shift IR
    
  
PUB Restore_Idle
{
    Resets the TAP to the Test-Logic-Reset state from any unknown state by transitioning through the state machine.
    TMS is held high for five consecutive TCK clock periods.
    Leaves the TAP in the Run-Test-Idle state.
}
  TMS_High           
  repeat 5
    TCK_Pulse

  TMS_Low             
  TCK_Pulse        ' Go to Run-Test-Idle

  
PUB TCK_Pulse
{
    Generate one TCK pulse.
    Expects TCK to be low upon being called.
}
  TDO_Read         ' Ignore the return value

    
PUB TDO_Read : value
{
    Generate one TCK pulse. Read TDO inside the pulse.
    Expects TCK to be low upon being called.
}
  outa[TCK] := 1              ' TCK high (target samples TMS and TDI, presents valid TDO, TAP state may change) 
  value := ina[TDO]  
  outa[TCK] := 0              ' TCK low 
  

PUB TDI_High
  outa[TDI] := 1


PUB TDI_Low
  outa[TDI] := 0


PUB TMS_High
  outa[TMS] := 1


PUB TMS_Low
  outa[TMS] := 0

  