{
    MIT License
    
    Copyright (C) 2019  Adam Green (https://github.com/adamgreen)
    
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
' SWDTarget - Module which emulates a debug target which speaks ARM's
'             Serial Wire Debug protocol.
'             Currently just used to unit test the SWDHost module.
' NOTE: At this point it only has the ability to simulate reading of
'       the IDCODE Debug Port register since this is the only 
'       functionality needed for JTAGulating.

CON
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

    ' States of data transfer.
    #0, STATE_REQUEST, STATE_ACK, STATE_DATA, STATE_TURNAROUND
    
VAR
    ' Pin configuration.
    BYTE m_swclkPin
    BYTE m_swdioPin
    
    ' IDCODE response value.
    LONG m_idcode
    
    ' Whether a parity error should be introduced.
    LONG m_introduceParityError
    
    ' Error, if any, to return as ACK response.
    LONG m_response
    
    ' Number of rising edges detected on SWCLK pin.
    LONG m_clockCount
    
    ' Number of consecutive rising edges with SWDIO held high.
    ' Used to detect line reset.
    LONG m_highCount
    
    ' Minimum time between rising edges.
    long m_minTime
    
    ' Stack to be used by cog acting as SWD target.
    ' UNDONE: Later check how much of this stack has actually been used.
    LONG m_stack[128]
    
    ' Id of cog acting as SWD target.
    LONG m_cogId


PUB init
    m_swclkPin~~
    m_swdioPin~~
    m_clockCount~
    m_highCount~
    m_idcode~
    m_introduceParityError~
    m_response := RESP_OK
    m_minTime := POSX
    m_cogId~~
    
PUB start(swclkPin, swdioPin)
    IF m_cogId <> -1
        ' It is an error to call start twice without an intervening stop call.
        RETURN -1  
    m_swclkPin := swclkPin
    m_swdioPin := swdioPin
    m_clockCount~
    m_highCount~
    m_idcode~
    m_introduceParityError~
    m_response := RESP_OK
    m_minTime := POSX
    RESULT := m_cogId := COGNEW(cogCode, @m_stack)
    ' Wait for a bit to make sure that cog is fully started before continuing.
    WAITCNT(CLKFREQ / 10 + CNT)

PUB stop
    IF m_cogId == -1
        ' Not running on cog so no need to cleanup
        RETURN
    COGSTOP(m_cogId)
    m_cogId~~
    
PRI cogCode | clkMask, bit, state, request, tst, isRead, ack, payload, count, parity, switch2Input, skipData, lastCnt, currCnt
    ' Make SWDCLK pin act as input
    DIRA[m_swclkPin]~

    lastCnt := CNT - CLKFREQ
    clkMask := |< m_swclkPin
    state := STATE_REQUEST
    request~
    switch2Input~~
    REPEAT
        ' Wait for SWCLK falling edge.
        WAITPEQ(0, clkMask, 0)
        currCnt := CNT
        m_minTime <#= (currCnt - lastCnt)
        lastCnt := currCnt
        IF switch2Input
            DIRA[m_swdioPin]~
            switch2Input~
    
        ' Wait for SWCLK rising edge.
        WAITPEQ(clkMask, clkMask, 0)
        bit := INA[m_swdioPin]
        m_clockCount++
        
        ' Check for a line reset (50 consecutive rising clock edges with 
        ' SWDIO set high.)
        IF bit
            m_highCount :=  m_highCount + 1 <# 50
            IF m_highCount == 50
                state := STATE_REQUEST
                request~
                NEXT
        ELSE
            m_highCount~

        CASE state
            STATE_REQUEST:
                ' Shift in this bit.
                request >>= 1
                request |= bit << 31
                
                ' See if we have a valid packet request yet.
                ' Start bit (bit 0) == 1
                ' Stop bit (bit 6) == 0
                ' Valid parity of bits 1-5
                tst := request >> CONSTANT(32-8)
                IF (tst & 1) AND NOT(tst & CONSTANT(|<6)) AND NOT calcParity(tst, 1, 5)
                    processRequest(tst, @isRead, @ack, @payload)
                    ' Prepare to start sending back the 3-bit ack.
                    state := STATE_ACK
                    count := 3
                    skipData := ack <> RESP_OK
            STATE_ACK:
                ' Shift out the next ack bit.
                DIRA[m_swdioPin]~~
                OUTA[m_swdioPin] := ack & 1
                ack >>= 1
                IF NOT --count
                    IF skipData
                        state := STATE_REQUEST
                        request~
                        switch2Input~~
                    ELSE
                        state := STATE_DATA
                        count := 32
                        parity~
            STATE_DATA:
                ' UNDONE: Only supports read at this point.
                ' UNDONE: Don't need to do this state if FAULT or WAIT is returned and not using overrun detection.
                IF count
                    ' Shift out the next payload bit.
                    bit := payload & 1
                    parity ^= bit
                    OUTA[m_swdioPin] := bit
                    payload >>= 1
                    count--
                ELSE
                    ' Finish off with the parity bit.
                    OUTA[m_swdioPin] := parity ^ m_introduceParityError
                    state := STATE_TURNAROUND
                    switch2Input := TRUE
            STATE_TURNAROUND:
                state := STATE_REQUEST
                request~

PRI calcParity(value, skipBits, bitCount) : parity
    value >>= skipBits
    parity~
    REPEAT WHILE bitCount--
        parity ^= (value & 1)
        value >>= 1
        
PRI processRequest(tst, pIsRead, pAck, pPayload) | isRead, isApRequest, address
    isRead := tst & CONSTANT(|<2)
    isApRequest := tst & CONSTANT(|<1)
    address := ((tst >> 3) & 3) << 2
    IF isRead AND NOT isApRequest AND address == DP_IDCODE
        LONG[pAck] := RESP_OK
        LONG[pPayload] := m_idcode
    ELSE
        LONG[pAck] := RESP_FAULT
        LONG[pPayload] := 0
    LONG[pIsRead] := isRead
    IF m_response <> RESP_OK
        LONG[pAck] := m_response

PUB clockCounts
    RETURN m_clockCount
    
PUB inLineResetState : wasReset | count
    RETURN m_highCount == 50

PUB setIDCODE(idcode)
    m_idcode := idcode

PUB introduceParityError(enable)
    IF enable
        m_introduceParityError := 1
    ELSE
        m_introduceParityError~ 
        
PUB introduceResponseError(response)
    m_response := response

PUB frequency
    RETURN CLKFREQ / m_minTime