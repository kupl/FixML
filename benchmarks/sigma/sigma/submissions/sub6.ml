

let rec sigma (a,b,f) =
 if a > b then 0       
 else if b = a then a              
 else (f b) + (sigma (a,(b-1),f))  


