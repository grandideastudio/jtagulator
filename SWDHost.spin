{
    MIT License
    
    Copyright (C) 2020  Adam Green (https://github.com/adamgreen)
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
}
' SWDHost - Module which can talk to debug targets using ARM's
'           Serial Wire Debug protocol.
' NOTE: At this point it only has the ability to read Debug Port
'       registers and has only been tested reading the IDCODE DP
'       register since this is the only functionality needed for
'       JTAGulating.

CON
    ' Number of times to pulse SWCLK with SWDIO pulled high for line reset.
    LINE_RESET_CLK_PULSES = 51
    
    ' Number of times to pulse SWCLK with SWDIO pulled low after line reset.
    IDLE_PULSES = 8
    
    ' ARM document mentions a lower rate of 1kHz.
    ' https://developer.arm.com/docs/dui0499/latest/arm-dstream-target-interface-connections/signal-descriptions/serial-wire-debug
    SWD_SLOW_CLOCK_RATE = 1000

    ' The fastest I have been able to run my SWD code without hanging in WAITCNT = 385kHz
    ' Reduce to 300kHz for production use (reliability >> speed)
    SWD_FASTEST_CLOCK_RATE = 300_000

    SWD_DEFAULT_CLOCK_RATE = 100_000 ' Default to a midrange value 
    
    ' SWD DP Register Addresses.
    DP_IDCODE = $0      ' Read-only
    DP_ABORT = $0       ' Write-only
    DP_CTRL_STAT = $4   ' Read/Write w/ CTRLSEL = 0
    DP_WCR = $4         ' Read/Write w/ CTRLSEL = 1
    DP_RESEND = $8      ' Read-only
    DP_SELECT = $8      ' Write-only
    DP_RDBUFF = $C      ' Read-only

    ' SWD Response Codes.
    RESP_OK = %001
    RESP_WAIT = %010
    RESP_FAULT = %100
    RESP_PARITY = %1000 ' Special code to indicate we got data parity error.
    
    ' Read/Write bit.
    READ = 1
    WRITE = 0
    
    ' AP/DP bit.    
    AP = 1
    DP = 0
    
    ' Supported SWD operations.
    #0, OP_CONFIG, OP_RESET, OP_RESET_JTAG2SWD, OP_READ


VAR
    ' ID of the cog on which the SWD PASM code is running.
    LONG m_cogId
    
    ' NOTE: Maintain the order of the following variables as they are accessed from
    '       PASM via PAR pointer.
    ' Pin configuration.
    LONG m_swclkPin
    LONG m_swdioPin
    ' Number of Propeller clock cycles per half pulse.
    LONG m_delay
    ' Each command is given a unique id. It is updated after other command fields are
    ' set to let SWD cog know that there is a new command to process.
    LONG m_cmdIndex
    ' What command should be executed next by the SWD cog. One of the OP_* enumeration.
    LONG m_cmdOp
    ' Operand for current command, if any.
    LONG m_cmdOperand
    ' The SWD cog sets this id to match the m_cmdIndex of the command that it has just
    ' finished processing. It updates it after all other response fields are filled in
    ' to let the main cog know that it is done.
    LONG m_respIndex
    ' 3-bit ACK response from target for read/writes.
    LONG m_respAck
    ' 32-bit data response from target for reads.
    LONG m_respData


PUB init
{
  Initialize the SWD host module.
    Starts the SWD code running on its own cog. You need to call config()
    to setup the pins and frequency to be used when processing future SWD
    calls.
  Returns
    The index of the cog on which the SWD code was started or -1 if there
    was no free cog.
}
    ' Clear members that will be filled in later at config time.
    m_swclkPin~~
    m_swdioPin~~
    m_delay~
    ' Zero out the command & response fields.
    m_cmdIndex~
    m_respIndex~
    ' Start up the SWD PASM code on its own cog.
    RESULT := m_cogId := COGNEW(@SwdRoutine, @m_swclkPin)


PUB uninit
{
  Cleans up the SWD module.
    Call this once the SWD module is no longer needed so that the cog
    running the SWD code can be freed for other uses.
}
    IF m_cogId <> -1
        COGSTOP(m_cogId)
        m_cogId~~
    m_swclkPin~~
    m_swdioPin~~


PUB config(swclkPin, swdioPin, frequency)
{
  Configure the SWD module to use specified pins and frequency.
    Call this function after init() to tell the SWD cog which pins
    (SWCLK & SWDIO) and frequency it should use for future method
    calls. It can be called multiple times, allowing the user to
    change which pins and/or frequency are used for SWD communication.
  Parameters
    swclkPin indicates which of the Propeller pins is connected to SWCLK.
    swdioPin indicates which of the Propeller pins is connected to SWDIO.
    frequency indicates how fast the SWCLK should pulse, in Hz. It can
      be set between SWD_SLOW_CLOCK_RATE and SWD_FASTEST_CLOCK_RATE.
}
    ' Store away pins to be used for SWD operations.
    m_swclkPin := swclkPin
    m_swdioPin := swdioPin
    ' Calculate CNT cycles to delay for each phase of SWCLK output.
    m_delay := CLKFREQ / (frequency * 2)
    ' Make sure that the current cog isn't holding either of these pins high so that
    ' the SWD cog can't manipulate them properly.
    DIRA[m_swdioPin]~
    DIRA[m_swclkPin]~
    ' Tell the SWD cog to pickup these new pin and frequency setings.
    m_cmdOp := OP_CONFIG
    m_cmdIndex++
    REPEAT UNTIL m_respIndex == m_cmdIndex
        ' Waiting for SWD cog to complete command.


PUB resetSwJtagAndReadIdCode(pValue)
{        
  Reset SerialWire-Jtag debug access port into SWD mode and read out its IDCODE.
    Reading the IDCODE is one of the few things that a SWD target will allow after
    a mode switch so this function does both at once.
  Parameters
    pValue is a pointer to a 32-bit value to be filled in with the IDCODE.
  Returns
    The 3-bit RESP_* ack value sent back from the target or RESP_PARITY if the
    data portion failed parity checking.
    NOTE: If the response isn't RESP_OK then the IDCODE isn't read into pValue.
} 
    m_cmdOp := OP_RESET_JTAG2SWD
    RESULT := setupReadDP(DP_IDCODE, pValue)

PUB resetAndReadIdCode(pValue)
{
  Reset the target and read out its IDCODE.
    Reading the IDCODE is one of the few things that a SWD target will allow after
    a line reset so this function does both at once. It is more common to use the
    resetSwJtagAndReadIrCode() method instead of this one since most ARM Cortex-M
    processors support JTAG on the same pins used for SWD.
  Parameters
    pValue is a pointer to a 32-bit value to be filled in with the IDCODE.
  Returns
    The 3-bit RESP_* ack value sent back from the target or RESP_PARITY if the
    data portion failed parity checking.
    NOTE: If the response isn't RESP_OK then the IDCODE isn't read into pValue.
}
    m_cmdOp := OP_RESET
    RESULT := setupReadDP(DP_IDCODE, pValue)

PUB readDP(address, pValue) : response | data
{
  Reads the specified Debug Port register.
  Parameters
    address is the 4-bit address of the register to be read.
    pValue is a pointer to a 32-bit value to be filled in with the register contents.
  Returns
    The 3-bit RESP_* ack value sent back from the target or RESP_PARITY if the
    data portion failed parity checking.
    NOTE: If the response isn't RESP_OK then the register contents aren't read 
          into pValue.
}
    m_cmdOp := OP_READ
    response := setupReadDP(address, pValue)

PRI setupReadDP(address, pValue) : response | data
{
  Setup to perform a read DP command. 
  Used to send a read DP command but also at the end of reset commands too to read IDCODE.
  Parameters
    address is the 4-bit address of the register to be read.
    pValue is a pointer to a 32-bit value to be filled in with the register contents.
  Returns
    The 3-bit RESP_* ack value sent back from the target or RESP_PARITY if the
    data portion failed parity checking.
    NOTE: If the response isn't RESP_OK then the register contents aren't read 
          into pValue.
}
    m_cmdOperand := buildPacketRequest(DP, READ, address)
    m_cmdIndex++
    REPEAT UNTIL m_respIndex == m_cmdIndex
        ' Waiting for SWD cog to complete command.
    IF m_respAck == RESP_OK
        LONG[pValue] := m_respData  
    response := m_respAck  

PRI buildPacketRequest(APnDP, RnW, address) : packet
    ' Only send upper 2-bits of the 4-bit address.
    address := (address >> 2) & $3
    ' Build up 8-bit packet request [start(1), APnDP, RnW, 2-bit address, parity, stop(0), park(1)]
    ' The bits are in reverse order where start is lsb and stop in msb.
    packet := %10000001 | (APnDP << 1) | (RnW << 2) | (address << 3)
    ' Parity is over 4-bits, starting at second bit (ignores start and stop bits).
    packet |= calcParity(packet, 1, 4) << 5
    
    
PRI calcParity(value, skipBits, _bitCount) : parity
    value >>= skipBits
    parity~
    REPEAT WHILE _bitCount--
        parity ^= (value & 1)
        value >>= 1


DAT
                ORG 0
                
                ' This is the SWD PASM code which does the bulk of the SWD
                ' communication in its own cog.
SwdRoutine
                MOV TempAddr, PAR
                ' Store away addresses of command and response fields.
                ' Skip m_swclkPin, m_swdioPin, and m_delay LONGS.
                ADD TempAddr, #4*3 
                MOV CmdIndexAddr, TempAddr
                ADD TempAddr, #4
                MOV CmdOpAddr, TempAddr
                ADD TempAddr, #4
                MOV CmdOperandAddr, TempAddr
                ADD TempAddr, #4
                MOV RespIndexAddr, TempAddr
                ADD TempAddr, #4
                MOV RespAckAddr, TempAddr
                ADD TempAddr, #4
                MOV RespDataAddr, TempAddr
                ' Initialize command index.
                RDLONG LastIndex, RespIndexAddr

:NextCmd        ' Setup for next command.
:WaitCmd        ' Wait for next command.
                ' See if the command index has been incremented to indicate a new command.
                RDLONG CurrIndex, CmdIndexAddr
                CMP CurrIndex, LastIndex WZ
                IF_E JMP #:WaitCmd
                
                ' Initialize timer variables.
                MOV Time, CNT
                ADD Time, Delay
                
                ' Jump to the handler for the requested command.
                RDLONG TempVal, CmdOpAddr
                CMP TempVal, #OP_RESET_JTAG2SWD WZ
                IF_E JMP #:ResetJTAG2SWD
                CMP TempVal, #OP_RESET WZ
                IF_E JMP #:ResetCmd
                CMP TempVal, #OP_READ WZ
                IF_E JMP #:ReadRegister
                ' Get here if the command was OP_CONFIG.

:ConfigPinsFreq ' Configure this code to use caller specified pins and frequency.
                MOV TempAddr, PAR
                ' SWCLK Pin mask from m_swclkPin.
                RDLONG TempVal, TempAddr
                MOV SwclkPinMask, #1
                SHL SwclkPinMask, TempVal
                ' SWDIO Pin mask from m_sdwioPin.
                ADD TempAddr, #4
                RDLONG TempVal, TempAddr
                MOV SwdioPinMask, #1
                SHL SwdioPinMask, TempVal
                ' Fetch delay from main memory.
                ADD TempAddr, #4
                RDLONG Delay, TempAddr
                ' Start out with SWCLK and SWDIO pins both set high.
                MOV TempVal, SwdioPinMask
                OR TempVal, SwclkPinMask
                MOV OUTA, TempVal
                ' Configure SWCLK and SWDIO pins as output.
                MOV DIRA, TempVal
                JMP #:CmdDone
                
:ResetJTAG2SWD  ' Clock out 51 SWCLK pulses with SWDIO held high.
                CALL #SendReset
                ' Send the $E79E JTAG to SWD bit sequence out over TMS/SWDIO.
                MOV DataOut, Jtag2SwdSeq
                MOV BitCount, #16
                CALL #ClockInOut
                ' NOTE: Fall-through to ResetCmd to finish JTAG2SWD reset.
                
:ResetCmd       ' Clock out 51 SWCLK pulses with SWDIO held high.
                CALL #SendReset
                ' Send 8 SWCLK pulses with SWDIO held low for idle.
                MOV DataOut, #0
                MOV BitCount, #IDLE_PULSES
                call #ClockInOut
                ' NOTE: Fall-through to ReadRegister to read the ID code out.

:ReadRegister   ' Read a DP or AP register.
                ' Packet request is already filled out in m_cmdOperand by Spin code.
                RDLONG DataOut, CmdOperandAddr
                MOV BitCount, #8
                CALL #ClockInOut
                ' Switch SWDIO to input and issue turn-around cycle.
                '   SWCLK falling edge.
                WAITCNT Time, Delay
                MOV DIRA, SwclkPinMask ' Only setting SWCLK pin as output.
                MOV OUTA, #0
                '   SWCLK rising edge.
                WAITCNT Time, Delay
                MOV OUTA, SwclkPinMask
                ' Read in the 3-bit ACK response.
                MOV BitCount, #3
                CALL #ClockInOut
                WRLONG DataIn, RespAckAddr
                ' Nothing more to do if ACK response wasn't RESP_OK.
                CMP DataIn, #RESP_OK WZ
                IF_NE JMP #:TurnAroundDone
                ' Read in the 32-bit register value.
                MOV DataInParity, #0
                MOV BitCount, #32
                CALL #ClockInOut
                WRLONG DataIn, RespDataAddr
                ' Read in the parity bit.
                MOV BitCount, #1
                CALL #ClockInOut
                ' Final parity should be even.
                TEST DataInParity, HighBit WZ
                IF_E JMP #:TurnAroundDone
                ' Parity wasn't even so flag parity error.
                MOV TempVal, #RESP_PARITY
                WRLONG TempVal, RespAckAddr
                ' Fall through to :TurnAroundDone

:TurnAroundDone ' Issue final turn around cycle and make SWDIO output again.
                ' UNDONE: Should really switch to output on next clock cycle.
                '   SWCLK falling edge.
                WAITCNT Time, Delay
                MOV OUTA, #0
                '   SWCLK rising edge.
                WAITCNT Time, Delay
                MOV TempVal, SwclkPinMask
                OR TempVal, SwdioPinMask
                MOV DIRA, TempVal
                MOV OUTA, SwclkPinMask
                ' Fall through to :CmdDone
                 
:CmdDone        ' Update m_respIndex to let calling cog know we are done with 
                ' the current command.             
                MOV LastIndex, CurrIndex
                WRLONG LastIndex, RespIndexAddr
                ' Jump back to wait for next command.
                JMP #:NextCmd


{
  Routine to send reset by holding SWDIO high during 51 clock cycles.
}
SendReset       ' Clock out 51 SWCLK pulses with SWDIO held high.
                '  Do 32 bits first...
                ABSNEG DataOut, #1
                MOV BitCount, #32
                CALL #ClockInOut
                '  Do the remaining 19-bits.
                ABSNEG DataOut, #1
                MOV BitCount, #(LINE_RESET_CLK_PULSES-32)
                CALL #ClockInOut
                ' Return to caller.
SendReset_ret   RET


{
  Routine to clock data out/in over SWDIO.
  Call with:
    BitCount = number of bits to shift in/out (maximum of 32).
    DataOut = bits to be shifted out least significant bit first.
  Returns:
    DataIn = bits shifted in, least significant bit is first bit received.
    DataInParity = the parity of DataIn bits are accumulated in MSB of this
                   variable. It must be manually cleared by caller.
}
ClockInOut      MOV LoopCount, BitCount
                MOV TempVal, INA
                MOV DataIn, #0
:Loop           ' Set SWDIO output to lsb of DataOut before next SWCLK falling edge.
                WAITCNT Time, Delay
                TEST DataOut, #1 WZ
                MUXNZ TempVal, SwdioPinMask
                SHR DataOut, #1
                ' SWCLK falling edge.
                ANDN TempVal, SwclkPinMask
                MOV OUTA, TempVal
                ' Shift in the next bit from SWDIO into DataIn before SWCLK rising edge.
                WAITCNT Time, Delay
                SHR DataIn, #1
                TEST SwdioPinMask, INA WZ
                MUXNZ DataIn, HighBit
                XOR DataInParity, DataIn
                ' SWCLK rising edge.
                OR TempVal, SwclkPinMask
                MOV OUTA, TempVal
                ' Loop around until all desired bits have been clocked in/out.
                DJNZ LoopCount, #:Loop
                ' Right justify the bits in DataIn.
                MOV TempVal, #32
                SUB TempVal, BitCount
                SHR DataIn, TempVal
                ' Return to caller.
ClockInOut_ret  RET


HighBit         LONG 1 << 31
Jtag2SwdSeq     LONG $E79E

TempAddr        RES 1
TempVal         RES 1
SwclkPinMask    RES 1
SwdioPinMask    RES 1
Delay           RES 1
Time            RES 1
LoopCount       RES 1
CmdIndexAddr    RES 1
CmdOpAddr       RES 1
CmdOperandAddr  RES 1
RespIndexAddr   RES 1
RespAckAddr     RES 1
RespDataAddr    RES 1
LastIndex       RES 1
CurrIndex       RES 1
BitCount        RES 1
DataOut         RES 1
DataIn          RES 1
DataInParity    RES 1
SavedParity     RES 1
                
                FIT