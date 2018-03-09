'' =================================================================================================
''
''   File....... jm_rxserial.spin
''   Purpose.... True mode serial receive driver -- with buffer
''   Author..... Jon "JonnyMac" McPhalen (aka Jon Williams)
''               Copyright (c) 2009 Jon McPhalen
''               -- see below for terms of use
''   E-mail..... jon@jonmcphalen.com
''   Started.... 
''   Updated.... 16 JUL 2009
''
'' =================================================================================================
     

var

  long  cog

  word  rxHead                                                  ' head pointer (0..255)
  word  rxTail                                                  ' tail pointer (0..255)
  byte  rxBuf[256]                                              ' receive buffer 


pub init(rxd, baud) : okay

'' Creates true mode receive UART on pin rxd at baud rate

  cleanup                                                       ' stop cog if running
  flush                                                         ' clear buffer

  rxmask     := 1 << rxd                                        ' set tx cog vars  
  rxbit1x0   := clkfreq / baud    
  rxbit1x5   := rxbit1x0 * 3 / 2   
  rxheadpntr := @rxHead
  rxtailpntr := @rxTail
  rxbufpntr  := @rxBuf

  okay := cog := cognew(@rxserial, 0) + 1     


pub cleanup

'' Stops serial RX driver; frees a cog 

  if cog
    cogstop(cog~ - 1)


pub rx | c

'' Pulls c from receive buffer if available
'' -- will wait if buffer is empty

  repeat while rxTail == rxHead
  c := rxBuf[rxTail]
  rxTail := (rxTail + 1) & $FF

  return c

  
pub rxcheck | c

'' Pulls c from receive buffer if available
'' -- returns < 0 if no byte received                                     

  if (rxTail == rxHead)
    c := -1
  else  
    c := rxBuf[rxTail]
    rxTail := (rxTail + 1) & $FF

  return c

  
pub wait(b) | check

'' Waits for specific byte in RX input stream

  repeat
    check := rx                                                 ' get byte from stream
  until (check == b)


pub waitstr(pntr) | count, cpntr, check

'' Waits for specific string in input stream
'' -- pntr is a pointer to the string to wait for

  count := strsize(pntr)
  cpntr := pntr

  repeat while count
    check := rx                                                 ' get byte from stream
    if (check == byte[cpntr])                                   ' compare to string
      --count                                                   ' if match, update count
      ++cpntr                                                   '  and character pointer      
    else
      count := strsize(pntr)                                    ' else reset count
      cpntr := pntr                                             '  and character pointer 


pub flush

'' Flushes RX buffer

  longfill(@rxHead, 0, 65)                                      ' clear pointers (1) and buffer (64) 
  rxTail := rxHead                                              ' reset buffer pointers
  

dat

                        org     0

rxserial                andn    dira, rxmask                    ' make rx pin an input

receive                 mov     rxwork, #0                      ' clear work var
                        mov     rxcount, #8                     ' rx eight bits
                        mov     rxtimer, rxbit1x5               ' set timer to 1.5 bits
                        
waitstart               waitpne rxmask, rxmask                  ' wait for falling edge
                        add     rxtimer, cnt                    ' sync with system counter

rxbit                   waitcnt rxtimer, rxbit1x0               ' hold for middle of bit
                        test    rxmask, ina             wc      ' rx --> c
                        shr     rxwork, #1                      ' prep for new bit
                        muxc    rxwork, #%1000_0000             ' c --> rxwork.7
                        djnz    rxcount, #rxbit                 ' update bit count
                        waitcnt rxtimer, #0                     ' let last bit finish  

putbuf                  rdword  tmp1, rxheadpntr                ' tmp1 := rxhead
                        add     tmp1, rxbufpntr                 ' tmp1 := rxbuf[rxhead]
                        wrbyte  rxwork, tmp1                    ' rxbuf[rxhead] := rxwork
                        sub     tmp1, rxbufpntr                 ' tmp1 := rxhead 
                        add     tmp1, #1                        ' inc tmp1
                        and     tmp1, #$FF                      ' keep 0..63
                        wrword  tmp1, rxheadpntr                ' rxhead := tmp1

                        jmp     #receive 

' -------------------------------------------------------------------------------------------------

rxmask                  long    0-0                             ' mask for rx pin
rxbit1x0                long    0-0                             ' ticks per bit
rxbit1x5                long    0-0                             ' ticks per 1.5 bits
rxheadpntr              long    0-0                             ' pointer to head position
rxtailpntr              long    0-0                             ' pointer to tail position
rxbufpntr               long    0-0                             ' pointer to rxbuf[0]

rxwork                  res     1                               ' rx byte input
rxcount                 res     1                               ' bits to receive
rxtimer                 res     1                               ' timer for bit sampling

tmp1                    res     1
tmp2                    res     1 
                                 
                        fit     492
                        

dat

{{

  Copyright (c) 2009 Jon McPhalen (aka Jon Williams)

  Permission is hereby granted, free of charge, to any person obtaining a copy of this
  software and associated documentation files (the "Software"), to deal in the Software
  without restriction, including without limitation the rights to use, copy, modify,
  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to the following
  conditions:

  The above copyright notice and this permission notice shall be included in all copies
  or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

}}                    