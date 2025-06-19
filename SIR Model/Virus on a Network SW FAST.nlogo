globals
[
 maximum-infection ;; maximum number of infected
 duration-maximum  ;; when the maximum occured

    infinity         ; used to represent the distance between two turtles with no path between them
  highlight-string ; message that appears on the node properties monitor

  average-path-length-of-lattice       ; average path length of the initial lattice
  average-path-length                  ; average path length in the current network

  clustering-coefficient-of-lattice    ; the clustering coefficient of the initial lattice
  clustering-coefficient               ; the clustering coefficient of the current network (avg. across nodes)

  number-rewired                       ; number of edges that have been rewired
  rewire-one?                          ; these two variables record which button was last pushed
  rewire-all?
]

turtles-own
[
  infected?           ;; if true, the turtle is infectious
  resistant?          ;; if true, the turtle can't be infected
  virus-check-timer   ;; number of ticks since this turtle's last virus-check
  distance-from-other-turtles ; list of distances of this node from other turtles
  my-clustering-coefficient   ; the current clustering coefficient of this node
]

links-own [
  rewired? ; keeps track of whether the link has been rewired or not
]

to setup

  clear-all
  ; set the global variables
  set infinity 99999      ; this is an arbitrary choice for a large number
  set number-rewired 0    ; initial count of rewired edges
  set highlight-string "" ; clear the highlight monitor

  ; make the nodes and arrange them in a circle in order by who number
  set-default-shape turtles "circle"
  create-turtles number-of-nodes [ set color green ]
  layout-circle (sort turtles) max-pxcor - 1

  ; Create the initial lattice
  wire-lattice

  ; Fix the color scheme
  ask links [ set color black ]
  ask patches [ set pcolor white ]
  ask turtles [ set shape "person" ]
  ask turtles [ set size 1.5 ]

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  set maximum-infection 0
  set duration-maximum 0

  ;;setup-links
  ask turtles [
   set size 1
    set shape "person"
   become-susceptible
   set virus-check-timer random virus-check-frequency
  ]
  ask links [ set color black ]
  rewire-all


  ;;setup-nodes

  ask n-of initial-outbreak-size turtles
    [ become-infected ]
  reset-ticks
end

to wire-lattice
  ; iterate over the turtles
  let n 0
  while [ n < count turtles ] [
    ; make edges with the next two neighbors
    ; this makes a lattice with average degree of 4
    make-edge turtle n
              turtle ((n + 1) mod count turtles)
              "default"
    ; Make the neighbor's neighbor links curved
    make-edge turtle n
              turtle ((n + 2) mod count turtles)
              "curve"
    set n n + 1
  ]

  ; Because of the way NetLogo draws curved links between turtles of ascending
  ; `who` number, two of the links near the top of the network will appear
  ; flipped by default. To avoid this, we used an inverse curved link shape
  ; ("curve-a") which makes all of the curves face the same direction.
  ask link 0 (count turtles - 2) [ set shape "curve-a" ]
  ask link 1 (count turtles - 1) [ set shape "curve-a" ]
end

to rewire-me ; turtle procedure
  ; node-A remains the same
  let node-A end1
  ; as long as A is not connected to everybody
  if [ count link-neighbors ] of end1 < (count turtles - 1) [
    ; find a node distinct from A and not already a neighbor of "A"
    let node-B one-of turtles with [ (self != node-A) and (not link-neighbor? node-A) ]
    ; wire the new edge
    ask node-A [ create-link-with node-B [ set color black set rewired? true ] ]

    set number-rewired number-rewired + 1
    die ; remove the old edge
  ]
end

to rewire-all
  ; confirm we have the right amount of turtles, otherwise reinitialize
  if count turtles != number-of-nodes [ setup ]

  ; record which button was pushed
  set rewire-one? false
  set rewire-all? true

  ; we keep generating networks until we get a connected one since apl doesn't mean anything
  ; in a non-connected network
  let connected? false
  while [ not connected? ] [
    ; kill the old lattice and create new one
    ask links [ die ]
    wire-lattice
    set number-rewired 0

    ; ask each link to maybe rewire, according to the rewiring-probability slider
    ask links [
      if (random-float 1) < rewiring-probability [ rewire-me ]
      set color black
    ]

    ; if the apl is infinity, it means our new network is not connected. Reset the lattice.
    ; ifelse find-average-path-length = infinity [ set connected? false ] [ set connected? true ]
    set connected? true
  ]

  ; calculate the statistics and visualize the data
  ;;set clustering-coefficient find-clustering-coefficient
  set average-path-length 0 ; find-average-path-length
  ;;update-plots
end

to make-edge [ node-A node-B the-shape ]
  ask node-A [
    create-link-with node-B  [
      set shape the-shape
      set rewired? false
    ]
  ]
end

to-report find-average-path-length

  let apl 0

  ; calculate all the path-lengths for each node
  find-path-lengths

  let num-connected-pairs sum [length remove infinity (remove 0 distance-from-other-turtles)] of turtles

  ; In a connected network on N nodes, we should have N(N-1) measurements of distances between pairs.
  ; If there were any "infinity" length paths between nodes, then the network is disconnected.
  ifelse num-connected-pairs != (count turtles * (count turtles - 1)) [
    ; This means the network is not connected, so we report infinity
    set apl infinity
  ][
    set apl (sum [sum distance-from-other-turtles] of turtles) / (num-connected-pairs)
  ]

  report apl
end

to find-path-lengths
  ; reset the distance list
  ask turtles [
    set distance-from-other-turtles []
  ]

  let i 0
  let j 0
  let k 0
  let node1 one-of turtles
  let node2 one-of turtles
  let node-count count turtles
  ; initialize the distance lists
  while [i < node-count] [
    set j 0
    while [ j < node-count ] [
      set node1 turtle i
      set node2 turtle j
      ; zero from a node to itself
      ifelse i = j [
        ask node1 [
          set distance-from-other-turtles lput 0 distance-from-other-turtles
        ]
      ][
        ; 1 from a node to it's neighbor
        ifelse [ link-neighbor? node1 ] of node2 [
          ask node1 [
            set distance-from-other-turtles lput 1 distance-from-other-turtles
          ]
        ][ ; infinite to everyone else
          ask node1 [
            set distance-from-other-turtles lput infinity distance-from-other-turtles
          ]
        ]
      ]
      set j j + 1
    ]
    set i i + 1
  ]
  set i 0
  set j 0
  let dummy 0
  while [k < node-count] [
    set i 0
    while [i < node-count] [
      set j 0
      while [j < node-count] [
        ; alternate path length through kth node
        set dummy ( (item k [distance-from-other-turtles] of turtle i) +
                    (item j [distance-from-other-turtles] of turtle k))
        ; is the alternate path shorter?
        if dummy < (item j [distance-from-other-turtles] of turtle i) [
          ask turtle i [
            set distance-from-other-turtles replace-item j distance-from-other-turtles dummy
          ]
        ]
        set j j + 1
      ]
      set i i + 1
    ]
    set k k + 1
  ]

end

to setup-links
  ask turtles
  [
    ask turtles-on neighbors4
   [
      if not link-neighbor? myself
      [
      create-link-with myself
      ]
    ]
  ]
end

to setup-nodes
  set-default-shape turtles "circle"
  create-turtles number-of-nodes
  [
    ; for visual reasons, we don't put any nodes *too* close to the edges
    setxy (random-xcor * 0.95) (random-ycor * 0.95)
    become-susceptible
    set virus-check-timer random virus-check-frequency
  ]
end


to go
  if all? turtles [not infected?]
    [ stop ]
  ask turtles
  [
     set virus-check-timer virus-check-timer + 1
     if virus-check-timer >= virus-check-frequency
       [ set virus-check-timer 0 ]
  ]
  spread-virus
  do-virus-checks
  if count turtles with [ infected? = true ] > maximum-infection
  [
    set maximum-infection count turtles with [ infected? = true ]
    set duration-maximum ticks
  ]
  tick
end

to become-infected  ;; turtle procedure
  set infected? true
  set resistant? false
  set color red
end

to become-susceptible  ;; turtle procedure
  set infected? false
  set resistant? false
  set color blue
end

to become-resistant  ;; turtle procedure
  set infected? false
  set resistant? true
  set color gray
  ask my-links [ set color gray - 2 ]
end

to spread-virus
  ask turtles with [infected?]
    [ ask link-neighbors with [not resistant?]
        [ if random-float 100 < virus-spread-chance
            [ become-infected ] ] ]
end

to do-virus-checks
  ask turtles with [infected? and virus-check-timer = 0]
  [
    if random 100 < recovery-chance
    [
      ifelse random 100 < gain-resistance-chance
        [ become-resistant ]
        [ become-susceptible ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
265
10
693
439
-1
-1
20.0
1
10
1
1
1
0
0
0
1
-10
10
-10
10
1
1
1
ticks
30.0

SLIDER
25
280
230
313
gain-resistance-chance
gain-resistance-chance
0.0
100
100.0
1
1
%
HORIZONTAL

SLIDER
25
245
230
278
recovery-chance
recovery-chance
0.0
10.0
10.0
0.1
1
%
HORIZONTAL

SLIDER
25
175
230
208
virus-spread-chance
virus-spread-chance
0.0
100.0
50.0
5
1
%
HORIZONTAL

BUTTON
25
125
91
165
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
161
125
230
165
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
5
325
260
489
Network Status
time
% of nodes
0.0
52.0
0.0
100.0
true
true
"" ""
PENS
"susceptible" 1.0 0 -13345367 true "" "plot (count turtles with [not infected? and not resistant?]) / (count turtles) * 100"
"infected" 1.0 0 -2674135 true "" "plot (count turtles with [infected?]) / (count turtles) * 100"
"resistant" 1.0 0 -7500403 true "" "plot (count turtles with [resistant?]) / (count turtles) * 100"

SLIDER
25
15
230
48
number-of-nodes
number-of-nodes
10
400
100.0
5
1
NIL
HORIZONTAL

SLIDER
25
210
230
243
virus-check-frequency
virus-check-frequency
1
20
1.0
1
1
ticks
HORIZONTAL

SLIDER
25
51
230
84
initial-outbreak-size
initial-outbreak-size
1
number-of-nodes
1.0
1
1
NIL
HORIZONTAL

BUTTON
95
125
159
165
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
265
444
364
489
maximum infection
maximum-infection
17
1
11

MONITOR
367
444
468
489
time of maximum
duration-maximum
17
1
11

MONITOR
471
444
566
489
total
count turtles
17
1
11

SLIDER
25
86
231
119
rewiring-probability
rewiring-probability
0
1
0.35
0.01
1
%
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This is a modified version of the NetLogo Network SIR model:

* Stonedahl, F. and Wilensky, U. (2008).  NetLogo Virus on a Network model.  http://ccl.northwestern.edu/netlogo/models/VirusonaNetwork.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

The network used here has been modified to a lattice network.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="10000" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="50" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="100" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="300" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="400" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="500" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="600" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="700" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="800" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="200" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="400 (1)" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="2000" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="1000" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="5000" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="10000 (1)" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>maximum-infection</metric>
    <metric>duration-maximum</metric>
    <metric>count turtles</metric>
    <metric>average-path-length</metric>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gain-resistance-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-check-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="virus-spread-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

curve
3.0
-0.2 0 0.0 1.0
0.0 0 0.0 1.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

curve-a
-3.0
-0.2 0 0.0 1.0
0.0 0 0.0 1.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
