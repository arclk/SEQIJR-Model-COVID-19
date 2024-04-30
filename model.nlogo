;; Alberico Arcangelo (mat. 0000949525)
;; arcangelo.alberico@studio.unibo.it

extensions [matrix]

globals
[
  contact_matrix       ;; Matrix of infection contacts
  city_area_patches    ;; Patches inside regions
  line_area_patches    ;; Patches of the region divisor
  patch_area_x         ;; x lenght of a region
  patch_area_y         ;; y lenght of a region
  angle                ;; Heading for individuals
]

turtles-own
[
  susceptible?                   ;; If true, the person can be infected.
  exposed?                       ;; If true, the person has been exposed.
  quarantined?                   ;; If true, the person is quarantined.
  infected?                      ;; If true, the person is infected.
  hospitalized?                  ;; If true, the person is hospitalized.
  recovered?                     ;; If true, the person is healed or dead.
  exposed-length                 ;; How long the person has been exposed.
  exposed-time                   ;; Time (in hours) it takes before the person become infected after an exposure
  exposed-detection-time         ;; Time before the detection of the exposure
  infection-length               ;; How long the person has been infected.
  infected-detection-time        ;; Time before the detection of the infection
  recovery-time                  ;; Time (in hours) it takes before the person has a chance to recover from the infection
  hospitalized-recovery-time     ;; Time (in hours) it takes before the person has a chance to recover from the infection
  mask-tendency                  ;; If the person tends to put on the mask
  x_patch                        ;; Horizontal patch in which the person is
  y_patch                        ;; Vertical patch in which the person is
  contacts                       ;; Contact list for each individual
]


;;;
;;; SETUP PROCEDURES
;;;
to setup
  clear-all
  resize-world 0 (size-of-world - 1) 0 (size-of-world - 1)
  set-patch-size (500 / max-pxcor)
  setup-globals
  setup-people

  reset-ticks
end

to create_city_map
  ;; Draw rows
  let curr_row 1
  repeat rows - 1 [
      ask patches with [pycor = (curr_row * patch_area_y) and abs (pxcor) >= 0 ][set pcolor yellow]
      set curr_row curr_row + 1
  ]

  ;; Draw columns
  let curr_col 1
  repeat cols - 1 [
      ask patches with [pxcor = (curr_col * patch_area_x) and abs (pycor) >= 0 ][set pcolor yellow]
      set curr_col curr_col + 1
  ]

  ;; Set the center of each region to be the hospital
  set curr_row 1
  repeat rows [
      set curr_col 1
      repeat cols [
          ask patches with [pxcor = ((curr_col * patch_area_x) - round(patch_area_x / 2)) and pycor = ((curr_row * patch_area_y) - round(patch_area_y / 2)) ][set pcolor gray]
          set curr_col curr_col + 1
      ]
      set curr_row curr_row + 1
  ]
end

to setup-globals
  ;; Setting the horizontal and vertical area of each patch
  set patch_area_x round(max-pxcor / cols)
  set patch_area_y round(max-pycor / rows)
  create_city_map

  set city_area_patches patches with [ pcolor = black ]
  set line_area_patches patches with [ pcolor = yellow ]

  ;; Initialize the contact matrix
  set contact_matrix matrix:make-constant initial-people initial-people 0
end

;; Create initial-people number of people.
;; Those that live on the left are squares; those on the right, circles.
to setup-people
  create-turtles initial-people
  [
      ;; Choose a random position
      let random_x 0
      let random_y 0
      ask one-of city_area_patches [ set random_x pxcor set random_y pycor ]
      setxy random_x random_y
      set x_patch floor(random_x / patch_area_x)
      set y_patch floor(random_y / patch_area_y)
      if(random_x > (size-of-world - cols)) [ set x_patch cols - 1 ]
      if(random_x < cols) [ set x_patch 0 ]
      if(random_y > (size-of-world - rows)) [ set y_patch rows - 1 ]
      if(random_y < rows) [ set y_patch 0 ]

      ;; Initialize each person as susceptible
      set susceptible? true
      set exposed? false
      set quarantined? false
      set infected? false
      set hospitalized? false
      set recovered? false

      set mask-tendency false
      assign-tendency

      set shape "circle"
      set size round(3 / 400 * size-of-world)

      ;; Each individual has a 5% chance of starting out infected
      if (random-float 100 < initial-infected)
      [
          set infected? true
          set susceptible? false
      ]

      set contacts (list)
      assign-color
  ]
end

;; Assign to each individual their tendency
to assign-tendency ;; Turtle procedure
  set exposed-time random-normal average-exposed-time (average-exposed-time / 4)
  set exposed-detection-time random-normal average-exposed-detection-time (average-exposed-detection-time / 4)
  set infected-detection-time random-normal average-infected-detection-time (average-infected-detection-time / 4)
  set recovery-time random-normal average-recovery-time (average-recovery-time / 4)
  set hospitalized-recovery-time random-normal average-hospitalized-recovery-time (average-hospitalized-recovery-time / 4)

  ;; Make sure time values lies between 0 and 2x their average
  if exposed-time > average-exposed-time * 2 [ set exposed-time average-exposed-time * 2 ]
  if exposed-time < 0 [ set exposed-time 0 ]

  if exposed-detection-time > average-exposed-detection-time * 2 [ set exposed-detection-time average-exposed-detection-time * 2 ]
  if exposed-detection-time < 0 [ set exposed-detection-time 0 ]

  if infected-detection-time > average-infected-detection-time * 2 [ set infected-detection-time average-infected-detection-time * 2 ]
  if infected-detection-time < 0 [ set infected-detection-time 0 ]

  if recovery-time > average-recovery-time * 2 [ set recovery-time average-recovery-time * 2 ]
  if recovery-time < 0 [ set recovery-time 0 ]

  if hospitalized-recovery-time > average-hospitalized-recovery-time * 2 [ set hospitalized-recovery-time average-hospitalized-recovery-time * 2 ]
  if hospitalized-recovery-time < 0 [ set hospitalized-recovery-time 0 ]

  ;; Set the tendency of each person to wear masks
  if random 100 < mask-tendency-percentage [ set mask-tendency true ]
end


;; Different people are displayed in 3 different colors depending on health
;; green is a recovered of the infection
;; red is an infected person
;; white is a susceptible person
to assign-color ;; turtle procedure
  ifelse recovered?
    [ set color green ]
      [ ifelse infected?
        [set color red ]
        [set color white]]
end


;;;
;;; GO PROCEDURES
;;;
to go
  if all? turtles [ not infected? and not exposed? ]
    [ stop ]
  ask turtles
  [
      if not quarantined? and not hospitalized? [ move ]

      if exposed? [ maybe-become-infected ]

      if (infected? or exposed?) and not quarantined? and not hospitalized? [ expose
                                                                              add-contacts ]

      if not quarantined? and not hospitalized? and exposed? and exposed-length > exposed-detection-time [ quarantine ]

      if not hospitalized? and infected? and infection-length > infected-detection-time [ hospitalize ]

      if quarantined? and infected? and not hospitalized? [ hospitalize ]

      if infected? [ maybe-recover ]

      if (quarantined? or hospitalized?) and recovered? [ unisolate ]

      assign-color
  ]

  if not total-lockdown and not region-lockdown and random-float 100 < events-probability [ gather_in_public ]

  tick
end

;; Add the contacts to the turtle contact list for the tracing
to add-contacts ;; turtle procedure
  let current-turtle who

  let contact-p (turtles-on neighbors)
  if contact-p != nobody
  [
    let contact-list (list)
    ask contact-p [
      set contact-list lput who contact-list
      matrix:set contact_matrix who current-turtle 1
    ]

    foreach contact-list [ id ->
      set contacts filter [ s -> s != id ] contacts
      set contacts lput id contacts
      matrix:set contact_matrix current-turtle id 1
    ]
  ]
end

;; Write the contact matrix on a file for analysis
to write-matrix
  if file-exists? "matrix.txt" [ file-delete "matrix.txt" ]
  file-open "matrix.txt"
  let matlist matrix:to-row-list contact_matrix
  foreach matlist [ row ->
      foreach but-last row [ x ->
          file-type x
          file-type " "
      ]
      file-type last row
      file-type "\n"
  ]
  file-close
end

;; Move freely in the whole world
to move_no_restriction ;; turtle procedure
  set angle random-float 90
  if random 100 < 30 [ lt angle ] ;; change angle with a 0.3 probability
  let target-patch patch-ahead intra-mobility
  if target-patch != nobody
  [   ;; update region of the turtle
      set x_patch floor([pxcor] of target-patch / patch_area_x)
      set y_patch floor([pycor] of target-patch / patch_area_y)
      if([pxcor] of target-patch > (size-of-world - cols)) [ set x_patch cols - 1 ]
      if([pxcor] of target-patch < cols) [ set x_patch 0 ]
      if([pycor] of target-patch > (size-of-world - rows)) [ set y_patch rows - 1 ]
      if([pycor] of target-patch < rows) [ set y_patch 0 ]
  ]
  fd intra-mobility
end

;; Move only inside the area you are currently in
to move_inside_region ;; turtle procedure
  set angle random-float 90
  if random 100 < 30 [ lt angle ] ;; change angle with a 0.3 probability
  let target-patch patch-ahead intra-mobility
  if target-patch != nobody
  [
      let x_new [pxcor] of target-patch
      if x_new > x_patch * patch_area_x and x_new < (x_patch + 1) * patch_area_x
      [   ;; check if it is in the right column
          let y_new [pycor] of target-patch
          if y_new > y_patch * patch_area_y and y_new < (y_patch + 1) * patch_area_y
          [   ;; check if it is in the right row
              fd intra-mobility
          ]
      ]
  ]
end

to move  ;; turtle procedure
  ifelse total-lockdown
  [   ;; only exceptional moves are allowed
      if random 100 < (necessity-move)
      [   ;; probabilty of movement drastically reduced
          move_no_restriction
      ]
  ]
  [
      ifelse region-lockdown
      [
          move_inside_region
      ]
      [   ;; no restriction in movement
          move_no_restriction
      ]
  ]
end

;; To simulate public events pepole gather with some probability
to gather_in_public
  let gatherings_size events-capacity ; People in events
  let place_x 0
  let place_y 0
  ask one-of city_area_patches [ set place_x pxcor set place_y pycor]
  ask up-to-n-of gatherings_size turtles with [ not hospitalized? and not quarantined? ]
  [
      let x_target place_x - 4 + random(8)
      let y_target place_y - 4 + random(8)
      if(x_target < cols) [set x_target cols]
      if(y_target < rows) [set y_target rows]
      if(x_target > (size-of-world - cols)) [set x_target (size-of-world - cols)]
      if(y_target > (size-of-world - rows)) [set y_target (size-of-world - rows)]

      set xcor x_target
      set ycor y_target
      set x_patch floor(xcor / patch_area_x)
      set y_patch floor(ycor / patch_area_y)
      if(xcor > (size-of-world - cols)) [ set x_patch cols - 1 ]
      if(xcor < cols) [ set x_patch 0 ]
      if(ycor > (size-of-world - rows)) [ set y_patch rows - 1 ]
      if(ycor < rows) [ set y_patch 0 ]
  ]
end

;; After having been exposed, people become infected after some time
to maybe-become-infected ;; turtle procedure
  set exposed-length exposed-length + 1
  ;; If people have been exposed for more than the exposed-time then become infected
  if exposed-length > exposed-time
  [
      set exposed? false
      set infected? true
  ]
end

;; Apply contact tracing method to detected infections
to contact-tracing
  foreach contacts [ id ->
    if random 100 < contact-tracing-efficiency
    [
      ask turtle id [ if exposed? and not quarantined? [ quarantine ]
                      if infected? and not hospitalized? [ hospitalize ]
                      ]
    ]
  ]
end

;; After infected, people recover in some time
to maybe-recover ;; turtle procedure
  set infection-length infection-length + 1
  ;; If people have been infected for more than the recovery-time they recover
  let time recovery-time
  ;if hospitalized? [ set time (recovery-time - (hospitalized-reduction * recovery-time)) ]
  if hospitalized? [ set time hospitalized-recovery-time ]
  if infection-length > time
  [
      set infected? false
      set recovered? true
  ]
end

to quarantine ;; turtle procedure
  set quarantined? true
  move-to patch-here ;; move to center of patch
  if not empty? contacts [ contact-tracing ]
end

;; After unisolating, patch turns back to normal color
to unisolate  ;; turtle procedure
  set hospitalized? false
end

;; To hospitalize, move to hospital patch in the center of the current area
to hospitalize ;; turtle procedure
  set hospitalized? true
  if quarantined? [ set quarantined? false ]
  move-to patch (x_patch * patch_area_x + round(patch_area_x / 2)) (y_patch * patch_area_y + round(patch_area_y / 2))
  if not empty? contacts [ contact-tracing ]
end

;; Infected individuals who are not isolated or hospitalized have a chance of transmitting their disease to their susceptible neighbors.
to expose  ;; turtle procedure
    let chance infection-chance
    let dist social-distance
    let caller self
    let nearby-uninfected (turtles-on neighbors)
    with [ not exposed? and not infected? and not recovered? ]
    if nearby-uninfected != nobody
    [
        ;; If the person is only exposed there's a reduction of the infection chance
        if exposed? [ set chance (chance - (chance * exposed-reduction)) ]
        if masks-on [ if mask-tendency [ set chance (chance - (chance * mask-reduction)) ] ]
        ask nearby-uninfected
        [
            set dist random-normal social-distance (social-distance / 4)
            if (random 100 < chance) and (dist < maximum-contagion-distance)
            [
                set exposed? true
                set susceptible? false
            ]
        ]
    ]
end
@#$#@#$#@
GRAPHICS-WINDOW
670
55
1180
566
-1
-1
2.512562814070352
1
10
1
1
1
0
0
0
1
0
199
0
199
1
1
1
hours
30.0

BUTTON
375
110
458
143
setup
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
479
110
562
143
go
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

SLIDER
20
30
285
63
initial-people
initial-people
50
1000
350.0
10
1
NIL
HORIZONTAL

SLIDER
345
175
610
208
average-exposed-detection-time
average-exposed-detection-time
0
200
140.0
1
1
hours
HORIZONTAL

PLOT
345
365
625
565
Populations
hours
# people
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Infected" 1.0 0 -2674135 true "" "plot count turtles with [ infected? ]"
"Recovered" 1.0 0 -10899396 true "" "plot count turtles with [ recovered? ]"
"Exposed" 1.0 0 -955883 true "" "plot count turtles with [ exposed? ]"
"Susceptible" 1.0 0 -7500403 true "" "plot count turtles with [ susceptible? ]"

SLIDER
345
215
610
248
average-infected-detection-time
average-infected-detection-time
0
100
65.0
1
1
hours
HORIZONTAL

SLIDER
20
215
285
248
infection-chance
infection-chance
0
100
50.0
5
1
%
HORIZONTAL

SLIDER
20
110
285
143
intra-mobility
intra-mobility
0
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
1220
250
1440
283
necessity-move
necessity-move
0
10
5.0
1
1
%
HORIZONTAL

SLIDER
345
255
610
288
average-recovery-time
average-recovery-time
0
1000
700.0
10
1
hours
HORIZONTAL

PLOT
15
365
330
565
Cumulative Infected and Recovered
hours
% total pop.
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"% infected" 1.0 0 -2674135 true "" "plot (((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)"
"% recovered" 1.0 0 -10899396 true "" "plot ((count turtles with [ recovered? ] / initial-people) * 100)"

SWITCH
1220
170
1440
203
region-lockdown
region-lockdown
1
1
-1000

SWITCH
1220
210
1440
243
total-lockdown
total-lockdown
1
1
-1000

CHOOSER
330
55
422
100
size-of-world
size-of-world
100 200 300 400
1

CHOOSER
431
55
523
100
rows
rows
2 3 4
1

CHOOSER
530
55
622
100
cols
cols
2 3 4
1

BUTTON
1220
530
1440
563
NIL
write-matrix
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
295
285
328
average-exposed-time
average-exposed-time
0
500
190.0
10
1
hours
HORIZONTAL

SLIDER
20
255
285
288
exposed-reduction
exposed-reduction
0
1
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
345
295
610
328
average-hospitalized-recovery-time
average-hospitalized-recovery-time
0
1000
350.0
10
1
hours
HORIZONTAL

SWITCH
1220
290
1440
323
masks-on
masks-on
0
1
-1000

SLIDER
1220
370
1440
403
mask-reduction
mask-reduction
0
1
0.7
.1
1
NIL
HORIZONTAL

SLIDER
1220
330
1440
363
mask-tendency-percentage
mask-tendency-percentage
0
100
70.0
5
1
%
HORIZONTAL

SLIDER
1220
450
1440
483
social-distance
social-distance
0
10
1.0
0.5
1
meters
HORIZONTAL

SLIDER
1220
410
1440
443
maximum-contagion-distance
maximum-contagion-distance
0
3
2.0
0.5
1
meters
HORIZONTAL

SLIDER
1220
55
1440
88
events-capacity
events-capacity
0
100
0.0
1
1
people
HORIZONTAL

SLIDER
1220
95
1440
128
events-probability
events-probability
0
1
0.0
0.01
1
%
HORIZONTAL

SLIDER
20
70
285
103
initial-infected
initial-infected
0
100
5.0
1
1
%
HORIZONTAL

TEXTBOX
30
185
180
203
Model parameters
11
0.0
1

TEXTBOX
415
30
550
48
World setup parameters
11
0.0
1

TEXTBOX
1225
30
1375
48
Public events handling
11
0.0
1

TEXTBOX
1225
145
1375
163
Countermeasures
11
0.0
1

SLIDER
1220
490
1440
523
contact-tracing-efficiency
contact-tracing-efficiency
0
100
40.0
1
1
%
HORIZONTAL

@#$#@#$#@
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

person lefty
false
0
Circle -7500403 true true 170 5 80
Polygon -7500403 true true 165 90 180 195 150 285 165 300 195 300 210 225 225 300 255 300 270 285 240 195 255 90
Rectangle -7500403 true true 187 79 232 94
Polygon -7500403 true true 255 90 300 150 285 180 225 105
Polygon -7500403 true true 165 90 120 150 135 180 195 105

person righty
false
0
Circle -7500403 true true 50 5 80
Polygon -7500403 true true 45 90 60 195 30 285 45 300 75 300 90 225 105 300 135 300 150 285 120 195 135 90
Rectangle -7500403 true true 67 79 112 94
Polygon -7500403 true true 135 90 180 150 165 180 105 105
Polygon -7500403 true true 45 90 0 150 15 180 75 105

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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="exp1" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles with [ susceptible? ]</metric>
    <metric>count turtles with [ exposed? ]</metric>
    <metric>count turtles with [ infected? ]</metric>
    <metric>count turtles with [ recovered? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp2_infchance" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
      <value value="50"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp2_expdet" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="72"/>
      <value value="96"/>
      <value value="120"/>
      <value value="140"/>
      <value value="168"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp2_infdet" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="32"/>
      <value value="43"/>
      <value value="54"/>
      <value value="65"/>
      <value value="76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp3_lockdown" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp4_maskred" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.5"/>
      <value value="0.7"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp4_maskperc" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="20"/>
      <value value="50"/>
      <value value="70"/>
      <value value="80"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp4_socialdist" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp3_lockdown_ininf50" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp5_contrac" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="contact-tracing-efficiency">
      <value value="0"/>
      <value value="20"/>
      <value value="50"/>
      <value value="80"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp6_mix" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(((count turtles with [ recovered? ] + count turtles with [ infected? ]) / initial-people) * 100)</metric>
    <metric>count turtles with [ infected? ]</metric>
    <enumeratedValueSet variable="initial-infected">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-contagion-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="necessity-move">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="masks-on">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-detection-time">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="size-of-world">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rows">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="region-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cols">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exposed-reduction">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-infected-detection-time">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="contact-tracing-efficiency">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-tendency-percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-hospitalized-recovery-time">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-recovery-time">
      <value value="700"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="events-capacity">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intra-mobility">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mask-reduction">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="total-lockdown">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-exposed-time">
      <value value="190"/>
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
@#$#@#$#@
1
@#$#@#$#@
