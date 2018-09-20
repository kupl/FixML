





type crazy2 = NIL 
            | ZERO of crazy2 
            | ONE of crazy2 
            | MONE of crazy2






   let rec crazy2len (c: crazy2) : int = 
   match c with
   | NIL -> 0
   | ZERO a -> 1 + (crazy2len a)
   | ONE a -> 1 + (crazy2len a)
   | MONE a -> 1 + (crazy2len a)


   let _ = crazy2len (ZERO(ONE(MONE NIL)))

   let rec crazy2power (p: int) : int = 
   match p with
   | 0 -> 1
   | _ -> 2 * crazy2power (p - 1)

   let _ = crazy2power 3




   let rec crazy2val_aux (c: crazy2) (p: int) : int = 
   match c with
   | NIL -> 0
   | ZERO c_sub -> (crazy2val_aux c_sub (p+1))
   | ONE c_sub -> (crazy2val_aux c_sub (p+1)) + (crazy2power p)
   | MONE c_sub -> (crazy2val_aux c_sub (p+1)) - (crazy2power p) 


   let crazy2val (c: crazy2) : int =
   crazy2val_aux c 0


   let _ = crazy2val (ZERO(ONE(MONE NIL)))

   let _ = crazy2val (ZERO(ONE(ONE(ONE NIL))))






exception CarryBound





let rec carry_oneside (c: crazy2) (carry: int) : crazy2 = 
  match c, carry with
    | NIL, 0 -> (ZERO NIL)
    | NIL, 1 -> (ONE NIL)
    | NIL, -1 -> (MONE NIL)
    | ZERO sub_c, 0 -> (ZERO (carry_oneside sub_c 0))
    | ZERO sub_c, 1 -> (ONE (carry_oneside sub_c 0))
    | ZERO sub_c, -1 -> (MONE (carry_oneside sub_c 0))
    | ONE sub_c, 0 -> (ONE (carry_oneside sub_c 0))
    | ONE sub_c, 1 -> (ZERO (carry_oneside sub_c 1))
    | ONE sub_c, -1 -> (ZERO (carry_oneside sub_c 0))
    | MONE sub_c, 0 -> (MONE (carry_oneside sub_c 0))
    | MONE sub_c, 1 -> (ZERO (carry_oneside sub_c 0))
    | MONE sub_c, -1 -> (ZERO (carry_oneside sub_c (-1)))
    | _, _ -> raise CarryBound



let rec crazy2add_aux (c1: crazy2) (c2: crazy2) (carry: int) : crazy2 = 
  match c1, c2, carry with
    | NIL, NIL, 0 -> (ZERO NIL)
    | NIL, NIL, 1 -> (ONE NIL)
    | NIL, NIL, -1 -> (MONE NIL)
    | NIL, _, _ -> carry_oneside c2 carry
    | _, NIL, _ -> carry_oneside c1 carry
    | ZERO sub1, ZERO sub2, 0 
    | ZERO sub1, ONE sub2, -1
    | ZERO sub1, MONE sub2, 1
    | MONE sub1, ZERO sub2, 1
    | ONE sub1, ZERO sub2, -1 
    | MONE sub1, ONE sub2, 0 -> (ZERO (crazy2add_aux sub1 sub2 0))
    | ZERO sub1, ZERO sub2, 1
    | ZERO sub1, ONE sub2, 0 
    | ONE sub1, ZERO sub2, 0 
    | ONE sub1, MONE sub2, 1 
    | ONE sub1, ONE sub2, -1
    | MONE sub1, ONE sub2, 1 -> (ONE (crazy2add_aux sub1 sub2 0))
    | ONE sub1, MONE sub2, -1
    | ZERO sub1, ZERO sub2, -1
    | ONE sub1, MONE sub2, 0 
    | ZERO sub1, MONE sub2, 0 
    | MONE sub1, ZERO sub2, 0 
    | MONE sub1, ONE sub2, -1 
    | MONE sub1, MONE sub2, 1 -> (MONE (crazy2add_aux sub1 sub2 0))
    | ZERO sub1, ONE sub2, 1 
    | ONE sub1, ZERO sub2, 1
    | ONE sub1, ONE sub2, 0 -> (ZERO (crazy2add_aux sub1 sub2 1))
    | ONE sub1, ONE sub2, 1 -> (ONE (crazy2add_aux sub1 sub2 1))
    | ZERO sub1, MONE sub2, -1 
    | MONE sub1, ZERO sub2, -1
    | MONE sub1, MONE sub2, 0 -> (ZERO (crazy2add_aux sub1 sub2 (-1)))
    | MONE sub1, MONE sub2, -1 -> (MONE (crazy2add_aux sub1 sub2 (-1)))
    | _,_,_ -> raise CarryBound


let crazy2add (c1,c2) : crazy2 = 
  crazy2add_aux c1 c2 0



