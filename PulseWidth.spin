{{
+-------------------------------------------------+
| JTAGulator                                      |
| Pulse Width Detection Object                    |  
|                                                 |
| Author: Joe Grand                               |                     
| Copyright (c) 2020 Grand Idea Studio, Inc.      |
| Web: http://www.grandideastudio.com             |
|                                                 |
| Distributed under a Creative Commons            |
| Attribution 3.0 United States license           |
| http://creativecommons.org/licenses/by/3.0/us/  |
+-------------------------------------------------+

Program Description:

This object measures and stores the negative-going
pulse widths (high-low-high) of a signal on the
specified input pin.
 
}}


CON 'offsets of the structure below
  RXPIN_OFF              =  0
  RCVCNT_OFF             =  4
  SAMPLEBUFFER_OFF       =  8

  
VAR
  long cog                   ' Used to store ID of newly started cog
     
  long rxPin                 ' Parameters used by cog
  long rcvCnt                
  long sampleBuffer          

  
PUB Start(pin, count, bufptr): okay    'Start a new cog with the assembly routine   
  Stop
                             
  rxPin := pin                  ' Pin to measure
  rcvCnt := count               ' Number of samples to receive/have received
  sampleBuffer := bufptr        ' Address of global buffer from top object

  okay := cog := cognew(@Init, @rxPin) + 1

  
PUB Stop     'Stop the currently running cog, if any 
  if cog
    cogstop(cog~ - 1)


dat                     ' assembly program 
                        org      0
Init
                        mov      rx_pin, par                   ' start of the structure
                        add      rx_pin, #RXPIN_OFF
                        rdlong   rx_pin, rx_pin                ' point to the variable passed into the cog

                        mov      rx_mask, #1
                        shl      rx_mask, rx_pin               ' create bit mask for desired pin
                        andn     dira, rx_mask                 ' make rx pin an input

                        mov      rcv_cnt, par
                        add      rcv_cnt, #RCVCNT_OFF
                        rdlong   rcv_cnt, rcv_cnt              ' point to the variable passed into the cog
                           
                        mov      buf_ptr, par                     
                        add      buf_ptr, #SAMPLEBUFFER_OFF  
                        rdlong   buf_ptr, buf_ptr              ' point to the variable passed into the cog

                        rdlong   t1, rcv_cnt                   ' number of samples to receive
                        mov      t2, #0                        ' clear count
                        wrlong   t2, rcv_cnt                   ' number of samples received

                        movi     ctra, #%01100_000             ' NEG detector
                        movs     ctra, rx_pin                  ' pin to measure
                        mov      frqa, #1                      ' phsa increments by 1 when apin = LOW
Measure
                        cmp      t1, t2   wz                   ' if we've reached the desired sample count
                 if_e   jmp      #Done                         ' then finish
                 
                        waitpne  rx_mask, rx_mask              ' wait for pin low
                        mov      phsa, #0
                        waitpeq  rx_mask, rx_mask              ' wait for pin high
                        mov      phsa, phsa
                        wrlong   phsa, buf_ptr                 ' store pulse width into the buffer
                        add      buf_ptr, #4                   ' increment buffer index
                        add      t2, #1                        ' increment sample counter
                        wrlong   t2, rcv_cnt
                        
                        jmp      #Measure
Done                                                           ' infinite loop until the cog is stopped by top object
                        jmp      #Done                          
                 

' VARIABLES stored in cog RAM (uninitialized)
rx_pin                  res      1         ' rx pin          
rx_mask                 res      1         ' mask for rx pin
rcv_cnt                 res      1         ' sample counter                 
buf_ptr                 res      1         ' pointer for result

t1                      res      1
t2                      res      1

                        fit      ' make sure all instructions/data fit within the cog's RAM 

         