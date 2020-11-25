{{
*****************************************
*  A collection of sorting algorithms.  *
*    For Decimals                       *
*  Version 1.02                         * 
*  Author: Brandon Nimon                *
*  Created: 7 February, 2011            *
*  Copyright (c) 2011 Parallax, Inc.    *
*  See end of file for terms of use.    *
***************************************** 

This started out when I needed to sort some strings. I started with the bubble sort
(suggested by some people on the forum), but quickly found much faster algorithms.
I kept working my way up to faster and faster methods. Now I have an assortment of
algorithms to suit every need.

Though only the top three (insertion, shell, and quick) should even be considered
for use, the other two are included for educational purposes. For decimal sorting
(like what is displayed here) shell and quick should be the only two sorting
algorithms used, as insertion sort quickly becomes slow as the array size increases.

Each of the methods are called the same way (except quick sort) with the address of
the array, followed by the length of the array. All methods also have ascending and
descending order option.
Quick sort is called with the address of the array, 0 (the first index of the array),
and the length of the array minus one (the last index of the array).

All of the methods are "assumed to succeed", so no return value is given. The only
exception being the PASM Shell Sort, which returns 0 if no cog was available, or -1
on completion.

UPDATES:
  v1.01 (15 February, 2011):
    Added order option to quick and shell sorting. Now all methods have the option.
    Optimizations implemented in all sorting algorithms (big one in quick sort).
  v1.02 (25 July, 2011):
    Added PASM version of Shell Sort which is up to 66 times faster than the SPIN
      variety, though it does temperarily need an extra cog to function.  
}}

'' Modified by Joe Grand for JTAGulator, commented out unused methods to save space

CON
{
  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000                                          ' use 5MHz crystal

   #1, HOME, GOTOXY, #8, BKSP, TAB, LF, CLREOL, CLRDN, CR       ' PST formmatting control
  #14, GOTOX, GOTOY, CLS
}
  #0,ASC,DESC
{
  array_length = 32            ' adjust the number of elements in the array (sort function perform differently with more or less elements)
  loops = 10                    ' more will give a better sample set
}
{{
OBJ
  '' NEITHER OBJ NEEDED FOR SORTING ALGORITHMS, ONLY NEEDED FOR THE DEMO
  DEBUG  : "FullDuplexSerial" 
  RND    : "RealRandom" 

VAR
  '' NO VARs NEEDED FOR SORTING ALGORITHMS, ONLY NEEDED FOR THE DEMO
  LONG values[array_length]

PUB demo | start, avg, i
'' NOT NEEDED FOR SORTING ALGORITHMS, THERE ARE OTHER METHODS AT THE BOTTOM THAT ARE NOT NEEDED FOR THE ALGORITHMS

  DEBUG.start(31, 30, 0, 57600)
  waitcnt(clkfreq + cnt)  
  DEBUG.tx($D)

  RND.start                  

  DEBUG.str(string(CLS, "Decimal Sort Test", CR))
  DEBUG.str(string("Be patient while the algorithms run...", CR, CR))
   
  
' ===={ Shell Sort }====
  avg := 0
  REPEAT loops
    fillarray(@values)
     
    start := cnt
    shellsort(@values, array_length, ASC) 
    avg +=  cnt - start - 368 
  DEBUG.str(string("Average Speed of Shell Sort (in cycles):      "))
  DEBUG.dec(avg / loops)
  DEBUG.tx(CR)

  {REPEAT i FROM 0 TO array_length - 1
    DEBUG.dec(values[i])
    DEBUG.tx($D)}

' ===={ Shell Sort }====
  avg := 0
  REPEAT loops
    fillarray(@values)
     
    start := cnt
    pasmshellsort(@values, array_length, ASC) 
    avg +=  cnt - start - 368 
  DEBUG.str(string("Average Speed of PASM Shell Sort (in cycles): "))
  DEBUG.dec(avg / loops)
  DEBUG.tx(CR)

  {REPEAT i FROM 0 TO array_length - 1
    DEBUG.dec(values[i])
    DEBUG.tx($D)} 

' ===={ Quick Sort }====
  avg := 0
  REPEAT loops
    fillarray(@values)
     
    start := cnt
    quicksort(@values, 0, constant(array_length - 1), ASC) 
    avg += cnt - start - 368
  DEBUG.str(string("Average Speed of Quick Sort (in cycles):      "))
  DEBUG.dec(avg / loops)
  DEBUG.tx(CR)
       
  {REPEAT i FROM 0 TO array_length - 1
    DEBUG.dec(values[i])
    DEBUG.tx($D)}

' ===={ Insertion Sort }====
  avg := 0
  REPEAT loops
    fillarray(@values)
     
    start := cnt
    insertionsort(@values, array_length, ASC) 
    avg += cnt - start - 368
  DEBUG.str(string("Average Speed of Insertion Sort (in cycles):  "))
  DEBUG.dec(avg / loops)
  DEBUG.tx(CR)

  {REPEAT i FROM 0 TO array_length - 1
    DEBUG.dec(values[i])
    DEBUG.tx($D)}
  

' ===={ Cocktail Sort }====
  avg := 0
  REPEAT loops
    fillarray(@values)
     
    start := cnt
    cocktailsort(@values, array_length, ASC) 
    avg += cnt - start - 368
  DEBUG.str(string("Average Speed of Cocktail Sort (in cycles):   "))
  DEBUG.dec(avg / loops)
  DEBUG.tx(CR)

  {REPEAT i FROM 0 TO array_length - 1
    DEBUG.dec(values[i])
    DEBUG.tx($D)}

' ===={ Bubble Sort }====
  avg := 0
  REPEAT loops
    fillarray(@values)
     
    start := cnt
    bubblesort(@values, array_length, ASC) 
    avg += cnt - start - 368
  DEBUG.str(string("Average Speed of Bubble Sort (in cycles):     "))
  DEBUG.dec(avg / loops)
  DEBUG.tx(CR)
        
  {REPEAT i FROM 0 TO array_length - 1
    DEBUG.dec(values[i])
    DEBUG.tx($D)}

  DEBUG.str(string(CR, "Done.", CR))

  repeat
    waitcnt(0)

PUB quicksort(arrayAddr, left, right, asc_desc) | pivot, leftIdx, rightIdx, tmp
'' as long as the array is larger than 17, it's almost always the fastest algorithm here
'' but it uses a lot more stack space than any other sort here (due to the recursive nature of this method)
'' left is the low index of the array to sort (normally 0) and right is the high index to sort (usually size-of-array minus 1)
'' this optimized version sees if 15 elements or less are being sorted, if so, it uses insertion sort instead of continuing the recursion.
''   This means it's faster, and uses less stack space.
   
  IF ((tmp := right - left) > 0)                                                ' make sure there are things to sort
    IF (++tmp =< 15)
      insertionsort(@long[arrayAddr][left], tmp, asc_desc)                      ' speed things up when array is short (especially after recursion)
    ELSE

      leftIdx := left                                                             ' keep for recurse
      rightIdx := right                                                           ' keep for recurse
       
      pivot := (left + right) >> 1                                                ' choose pivot point in middle of array 
      REPEAT WHILE (leftIdx =< pivot AND rightIdx => pivot)                       ' continue while not at pivot point
        REPEAT WHILE (leftIdx =< pivot AND ((asc_desc == ASC AND long[arrayAddr][leftIdx] < long[arrayAddr][pivot]) OR (asc_desc == DESC AND long[arrayAddr][leftIdx] > long[arrayAddr][pivot]))) ' compare values
          leftIdx++
        REPEAT WHILE (rightIdx => pivot AND ((asc_desc == ASC AND long[arrayAddr][rightIdx] > long[arrayAddr][pivot]) OR (asc_desc == DESC AND long[arrayAddr][rightIdx] < long[arrayAddr][pivot]))) ' compare values
          rightIdx--
        tmp := long[arrayAddr][leftIdx]                                           ' swap the two values
        long[arrayAddr][leftIdx++] := long[arrayAddr][rightIdx]                   ' swap the two values
        long[arrayAddr][rightIdx--] := tmp                                        ' swap the two values
         
        IF (leftIdx - 1 == pivot)
          pivot := ++rightIdx
        ELSEIF (rightIdx + 1 == pivot)
          pivot := --leftIdx
      quicksort(arrayAddr, left, pivot - 1, asc_desc)                             ' recurse (left)
      quicksort(arrayAddr, pivot + 1, right, asc_desc)                            ' recurse (right)

PUB insertionsort (arrayAddr, arraylength, asc_desc) | j, i, val
'' for smaller arrays, faster than shell sort

  arraylength--                                                                 ' reduce this so it doesn't re-evaluate each loop
  REPEAT i FROM 1 TO arraylength
    val := long[arrayAddr][i]                                                   ' store value for later
    j := i - 1

    REPEAT WHILE (asc_desc == ASC AND long[arrayAddr][j] > val) OR (asc_desc == DESC AND long[arrayAddr][j] < val) ' compare values
      long[arrayAddr][j + 1] :=  long[arrayAddr][j]                           ' insert value
       
      IF (--j < 0)
        QUIT

    long[arrayAddr][j + 1] := val                                               ' place value (from earlier)
}}
PUB pasmshellsort (arrayAddr, arraylength, asc_desc) : done
'' up to 66 times faster than SPIN version of Shell Sort
'' temperarily starts a cog to sort the array (cog shuts down when task is complete)

  parAddr := arrayAddr
  parlen := arraylength
  ascdesc := asc_desc 
  done := 0

  IF (cognew(@shellsrt, @done) => 0)
    REPEAT UNTIL (done)

{{
PUB shellsort (arrayAddr, arraylength, asc_desc) | inc, val, i, j
'' consistantly the fastest with less than 70 elements and more than 20

  inc := arraylength-- >> 1                                                     ' get middle point (reduce arraylength so it's not re-evaluated each loop)
  REPEAT WHILE (inc > 0)                                                        ' while still things to sort
    REPEAT i FROM inc TO arraylength
      val := long[arrayAddr][i]                                                 ' store value for later
      j := i
      REPEAT WHILE (j => inc AND ((asc_desc == ASC AND long[arrayAddr][j - inc] > val) OR (asc_desc == DESC AND long[arrayAddr][j - inc] < val))) ' compare value
        long[arrayAddr][j] := long[arrayAddr][j - inc]                          ' insert value
        j -= inc                                                                ' increment
      long[arrayAddr][j] := val                                                 ' place value (from earlier)
    inc >>= 1                                                                   ' divide by 2. optimal would be 2.2 (due to geometric stuff)

PUB cocktailSort (arrayAddr, arraylength, asc_desc) | i, begin, swapped, tmp
'' approaching twice as fast as bubble sort

  begin := -1
  arraylength -= 2                                                              ' end of array minus 1
  REPEAT
    swapped := false                                                            ' assume no changes
    
    begin++
    REPEAT i FROM begin TO arraylength                                          ' loop through array  
      IF (asc_desc == ASC AND long[arrayAddr][i] > long[arrayAddr][i + 1]) OR (asc_desc == DESC AND long[arrayAddr][i] < long[arrayAddr][i + 1]) ' compare values
        tmp := long[arrayAddr][i]                                               ' swap values
        long[arrayAddr][i] := long[arrayAddr][i + 1]                            ' swap values
        long[arrayAddr][i + 1] := tmp                                           ' swap values
        swapped := true
    
    IF NOT(swapped)
      QUIT
    
    swapped := false                                                            ' assume no changes
    
    arraylength--
    REPEAT i FROM arraylength TO begin                                          ' loop through array  
      IF (asc_desc == ASC AND long[arrayAddr][i] > long[arrayAddr][i + 1]) OR (asc_desc == DESC AND long[arrayAddr][i] < long[arrayAddr][i + 1]) ' compare values
        tmp := long[arrayAddr][i]                                               ' swap values
        long[arrayAddr][i] := long[arrayAddr][i + 1]                            ' swap values
        long[arrayAddr][i + 1] := tmp                                           ' swap values
        swapped := true

  WHILE swapped

PUB bubblesort(arrayAddr, arraylength, asc_desc) | swapped, i, tmp
'' thanks Jon "JonnyMac" McPhalen (aka Jon Williams) (jon@jonmcphalen.com) for the majority of this code
'' slowest, but simplest sorting system

  arraylength -= 2                                                              ' reduce this so it doesn't re-evaluate each loop
  REPEAT
    swapped := false                                                            ' assume no changes
    REPEAT i FROM 0 TO arraylength                                              ' loop through array
      IF (asc_desc == ASC AND long[arrayAddr][i] > long[arrayAddr][i + 1]) OR (asc_desc == DESC AND long[arrayAddr][i] < long[arrayAddr][i + 1]) ' compare values
        tmp := long[arrayAddr][i]                                               ' swap values
        long[arrayAddr][i] := long[arrayAddr][i + 1]                            ' swap values
        long[arrayAddr][i + 1] := tmp                                           ' swap values
        swapped := true 

  WHILE swapped

PUB fillarray(arrayAddr) | i
'' fill the array with random values
'' sorting algorithms can be greatly affected by the existing order of the array, so putting the array in random
''   order, then testing multiple times will give the most accurate results.                                                               

  REPEAT i FROM 0 TO constant(array_length - 1)
    long[arrayAddr][i] := RND.random
}}
DAT

                        ORG
shellsrt
                        MOV     parAddr2, parAddr

                        MOV     pinc, parlen                                    ' inc := arraylength
                        SHR     pinc, #1                                        ' arraylength >> 1 

bigloop                 TJZ     pinc, #end                                      ' REPEAT WHILE (inc > 0)
                        MOV     idx, pinc                                       ' REPEAT i FROM inc
frompinc                CMP     idx, parlen     WZ, WC                          ' TO arraylength
              IF_AE     JMP     #lfrompinc
                                    
                        MOV     parAddr, parAddr2                               ' arrayAddr
                        MOV     addrAdd, idx                                    ' i
                        SHL     addrAdd, #2                                     ' [i]
                        ADD     parAddr, addrAdd                                ' long[arrayAddr][i]
                        RDLONG  pval, parAddr                                   ' val := long[arrayAddr][i]

                        MOV     jdx, idx                                        ' j := i

innerloop               CMP     jdx, pinc       WZ, WC                          ' REPEAT WHILE (j => inc
              IF_B      JMP     #linnerloop

                        MOV     addr, parAddr2                                  ' arrayAddr
                        MOV     addrAdd, jdx                                    ' j
                        SUB     addrAdd, pinc                                   ' j - inc                 
                        SHL     addrAdd, #2                                     ' [j - inc]
                        ADD     addr, addrAdd                                   ' long[arrayAddr][j - inc]
                        RDLONG  p1, addr                                        ' long[arrayAddr][j - inc]

                        CMPS    p1, pval        WZ, WC
              IF_Z      JMP     #linnerloop          
                        CMP     ascdesc, #0     WZ                          
             IF_Z_AND_C JMP     #linnerloop                                     ' long[arrayAddr][j - inc] > val
              IF_A      JMP     #linnerloop                                     ' long[arrayAddr][j - inc] < val   (IF_A == IF_NZ_AND_NC)

                        MOV     parAddr, parAddr2                               ' arrayAddr
                        MOV     addrAdd, jdx                                    ' j
                        SHL     addrAdd, #2                                     ' [j]
                        ADD     parAddr, addrAdd                                ' long[arrayAddr][j]
                        WRLONG  p1, parAddr                                     ' long[arrayAddr][j] := long[arrayAddr][j - inc]
                        SUBS    jdx, pinc                                       ' j -= inc
                        JMP     #innerloop

linnerloop              MOV     parAddr, parAddr2                               ' arrayAddr
                        MOV     addrAdd, jdx                                    ' j
                        SHL     addrAdd, #2                                     ' [j]
                        ADD     parAddr, addrAdd                                ' long[arrayAddr][j]
                        WRLONG  pval, parAddr                                   ' long[arrayAddr][j] := val
                        ADD     idx, #1                                         ' STEP 1
                        JMP     #frompinc

lfrompinc               SHR     pinc, #1                                        ' inc >>= 1
                        JMP     #bigloop

end                     WRLONG  negone, PAR
                        COGID   p1                                              ' get cog id
                        COGSTOP p1                                              ' kill this cog


negone                  LONG    -1

parAddr                 LONG    0
parlen                  LONG    0
ascdesc                 LONG    0

parAddr2                RES
addrAdd                 RES
addr                    RES
pinc                    RES
idx                     RES
jdx                     RES
pval                    RES

p1                      RES 

                        FIT

DAT
{{
+------------------------------------------------------------------------------------------------------------------------------+
|                                                   TERMS OF USE: MIT License                                                  |                                                            
+------------------------------------------------------------------------------------------------------------------------------+
|Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    | 
|files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    |
|modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software|
|is furnished to do so, subject to the following conditions:                                                                   |
|                                                                                                                              |
|The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.|
|                                                                                                                              |
|THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          |
|WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         |
|COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   |
|ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         |
+------------------------------------------------------------------------------------------------------------------------------+
}}