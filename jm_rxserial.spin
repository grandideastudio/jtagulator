'' =================================================================================================
''
''   File....... jm_rxserial.spin
''   Purpose.... True mode serial receive driver -- with buffer
''   Author..... Jon "JonnyMac" McPhalen (aka Jon Williams)
''               Copyright (c) 2009 Jon McPhalen
''               -- see below for terms of use
''   E-mail..... jon@jonmcphalen.com
''   Started.... 
''   Updated.... 06 JUL 2009
''
'' =================================================================================================

'' Modified by Lawson from https://forums.parallax.com/discussion/114492/prop-baudrates
'' Modified by Joe Grand 3/9/18, changed receiver delay to waitpeq (wait for rising edge) instead of waitcnt for final bit in byte

  
con
  buff_mask = $1ff              'must be all ones
  buff_size = buff_mask+1


var

  long  cog

  long  rxPin                                                   ' receive pin
  long  rxBitTix                                                ' counter ticks per bit
  long  rxHead                                                  ' head pointer (0..511)
  long  rxTail                                                  ' tail pointer (0..511)
  long  rxPntr                                                  ' address of rxBuf[0]    

  byte  rxBuf[buff_size]                                        ' receive buffer 


pub init(rxd, baud) : okay

'' Creates true mode receive UART on pin rxd at baud rate

  cleanup

  rxPin     := rxd
  rxBitTix  := clkfreq / baud
  rxHead    := 0
  rxTail    := 0
  rxPntr    := @rxBuf
       
  bytefill(@rxBuf, 0, buff_size)                     ' clear buffer
  okay := cog := cognew(@rxserial, @rxPin) + 1     


pub cleanup

'' Stops serial RX driver; frees a cog 

  if cog
    cogstop(cog~ - 1)


pub rx | c

'' Pulls c from receive buffer if available
'' -- will wait if buffer is empty

  repeat while rxTail == rxHead
  c := rxBuf[rxTail]
  rxTail := (rxTail + 1) & buff_mask

  return c


pub flush

'' Flushes rx buffer

  rxHead := 0
  rxTail := 0
  bytefill(@rxBuf, 0, buff_size)                     ' clear buffer  
  

dat

                        org     0

rxserial                mov     tmp1, par                       ' start of structure
                        rdlong  tmp2, tmp1                      ' read rx pin
                        mov     rxmask, #1                      ' create rx pin mask
                        shl     rxmask, tmp2
                        andn    dira, rxmask                    ' make rx pin an input
                        
                        add     tmp1, #4
                        rdlong  rxbit1x0, tmp1                  ' get bit timing

                        mov     rxbit1x5, rxbit1x0              ' set timing for 1.5 bits
                        shr     rxbit1x5, #1
                        add     rxbit1x5, rxbit1x0
                        
                        add     tmp1, #4
                        mov     rxheadpntr, tmp1                ' save pointer addresses
                        
                        add     tmp1, #4
                        mov     rxtailpntr, tmp1
                        
                        add     tmp1, #4
                        rdlong  rxbufpntr, tmp1                 ' get buffer address

rxbyte                  call    #receive

putbuf                  rdlong  tmp1, rxheadpntr                ' tmp1 := rxhead
                        add     tmp1, rxbufpntr                 ' tmp1 := rxbuf[rxhead]
                        wrbyte  rxwork, tmp1                    ' rxbuf[rxhead] := rxwork
                        sub     tmp1, rxbufpntr                 ' tmp1 := rxhead 
                        add     tmp1, #1                        ' inc tmp1
                        and     tmp1, #buff_mask                ' keep 0..511
                        wrlong  tmp1, rxheadpntr                ' rxhead := tmp1

                        jmp     #rxbyte


' -----------------
' True Mode RX UART
' -----------------
'
receive                 mov     rxwork, #0                      ' clear work var
                        mov     rxcount, #8                     ' rx eight data bits
                        mov     rxtimer, rxbit1x5               ' set timer to 1.5 bits
                        
waitstart               waitpne rxmask, rxmask                  ' wait for falling edge
                        add     rxtimer, cnt                    ' sync with system counter

rxbit                   waitcnt rxtimer, rxbit1x0               ' hold for middle of bit
                        test    rxmask, ina             wc      ' receive bit, rx --> c
                        shr     rxwork, #1                      ' prep for new bit
                        muxc    rxwork, #%1000_0000             ' c --> rxwork.7
                        djnz    rxcount, #rxbit                 ' update bit count
                        waitpeq rxmask, rxmask                  ' let last bit finish (wait for rising edge)
                        
receive_ret             ret  

' -------------------------------------------------------------------------------------------------

tmp1                    res     1
tmp2                    res     1

rxmask                  res     1                               ' mask for rx pin
rxbit1x0                res     1                               ' ticks per bit
rxbit1x5                res     1                               ' ticks per 1.5 bits
rxheadpntr              res     1                               ' pointer to head position
rxtailpntr              res     1                               ' pointer to tail position
rxbufpntr               res     1                               ' pointer to rxbuf[0]

rxwork                  res     1                               ' rx byte input
rxcount                 res     1                               ' bits to receive
rxtimer                 res     1                               ' timer for bit sampling 
                                 
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