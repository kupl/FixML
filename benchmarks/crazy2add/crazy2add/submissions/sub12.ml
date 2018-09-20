
 
type crazy2 = NIL
						| ZERO of crazy2
						| ONE of crazy2
						| MONE of crazy2


let rec crazy2add (left, right) = 
	match (left, right) with
	| (NIL, _) -> right
	| (_, NIL) -> left
  | (ZERO(left'), ZERO(right')) -> ZERO(crazy2add(left', right'))
  | (ONE(left'), ZERO(right')) -> ONE(crazy2add(left', right'))
	| (ZERO(left'), ONE(right')) -> ONE(crazy2add(left', right'))
  | (ONE(left'), ONE(right')) -> ZERO(ONE(crazy2add(left', right')))
  |	(MONE(left'), ZERO(right')) -> MONE(crazy2add(left', right'))
	| (ZERO(left'), MONE(right')) -> MONE(crazy2add(left', right'))
	| (MONE(left'), MONE(right')) -> ZERO(MONE(crazy2add(left', right')))
  | (ONE(left'), MONE(right')) -> ZERO(crazy2add(left', right'))
	| (MONE(left'), ONE(right')) -> ZERO(crazy2add(left', right'))


