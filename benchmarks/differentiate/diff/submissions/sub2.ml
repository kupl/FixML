
type ae = CONST of int
	| VAR of string
	| POWER of string * int
	| TIMES of ae list
	| SUM of ae list


let rec diff(ae, x) =
	match ae with
	| CONST n -> CONST 0
	| VAR v ->
		if v = x then CONST 1
		else CONST 0
	| POWER(v, n) ->
		if v = x then TIMES [CONST n;POWER(v, n-1)] 
		else CONST 0

	| SUM l ->
		let rec lstRec2 l =
			match l with
			| [] -> CONST 0
			| h::t -> SUM[diff(h, x);(lstRec2 t)] in
		lstRec2 l
