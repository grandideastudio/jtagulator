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
' SWDCapture - Module to capture SWDIO output on SWCLK rising edges.

CON
    ' Maximum number of longs to capture in m_buffer.
    MAX_CAPTURE_LONGS = 4
    MAX_CAPTURE_BITS = MAX_CAPTURE_LONGS * 32
    
    
VAR
    ' Pin configuration.
    BYTE m_swclkPin
    BYTE m_swdioPin

    ' Buffer to contain captured SWDIO output.
    LONG m_buffer[MAX_CAPTURE_LONGS]
    
    ' Number of rising edges detected on SWCLK pin.
    LONG m_clockCount
    
    ' Stack to be used by cog capturing data.
    ' UNDONE: Later check how much of this stack has actually been used.
    LONG m_stack[128]
    
    ' Id of cog capturing data.
    LONG m_cogId


PUB init
    m_swclkPin~~
    m_swdioPin~~
    m_clockCount~
    m_cogId~~
    
PUB start(swclkPin, swdioPin)
    IF m_cogId <> -1
        ' It is an error to call start twice without an intervening stop call.
        RETURN -1  
    m_swclkPin := swclkPin
    m_swdioPin := swdioPin
    m_clockCount~
    LONGFILL(@m_buffer, 0, MAX_CAPTURE_LONGS)
    RESULT := m_cogId := COGNEW(cogCode, @m_stack)
    ' Wait for a bit to make sure that cog is fully started before continuing.
    WAITCNT(CLKFREQ / 10 + CNT)

PUB stop
    IF m_cogId == -1
        ' Not running on cog so no need to cleanup
        RETURN
    COGSTOP(m_cogId)
    m_cogId~~
    
PRI cogCode | clkMask, bit
    ' Make SWCLK & SWDIO pins act as input.
    DIRA[m_swclkPin]~
    DIRA[m_swdioPin]~

    clkMask := |< m_swclkPin
    REPEAT
        ' Wait for SWCLK falling edge.
        WAITPEQ(0, clkMask, 0)
    
        ' Wait for SWCLK rising edge.
        WAITPEQ(clkMask, clkMask, 0)
        bit := INA[m_swdioPin]
        
        ' Store the bit just received if buffer not already full.
        IF m_clockCount < MAX_CAPTURE_BITS
            m_buffer[m_clockCount >> 5] |= bit << (m_clockCount & $1F)
        m_clockCount++
                
PUB getCapturedBits(pBuffer)
    ' Wait a bit for the last bit to be captured.
    WAITCNT(CLKFREQ / 10 + CNT)
    LONGMOVE(pBuffer, @m_buffer, MAX_CAPTURE_LONGS)
    RESULT := m_clockCount
    