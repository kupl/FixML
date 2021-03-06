

type ae = CONST of int
		| VAR of string
		| POWER of string * int
		| TIMES of ae list
		| SUM of ae list
exception InvalidArgument

let rec cal (form, var) =				
	match form with
		| CONST n -> CONST 0
		| VAR x -> if x=var then CONST 1 else CONST 0
		| POWER (x, n) ->
			if x=var then
				if n=0 then CONST 0
				else if n=1 then CONST 1
				else TIMES [CONST n; POWER(x, n-1)]
			else CONST 0
		| TIMES lst ->
			(
			if (List.mem (CONST 0) lst) then CONST 0
			else
				match lst with
				| [] -> raise InvalidArgument
				| l::[] -> (cal (l, var))
				| l::r ->
					match l with
						| CONST 1 -> (cal ((TIMES r), var))
						| CONST n -> TIMES[l;(cal ((TIMES r), var))]
						| VAR x -> if x=var then TIMES ((cal (l, var))::r)
									else TIMES[l;(cal ((TIMES r), var))]
						| _ -> TIMES ((cal (l, var))::r)
			)
		| SUM lst ->
			match lst with
			| [] -> raise InvalidArgument
			| l::[] -> (cal (l, var))
			| l::r -> SUM[(cal (l, var));(cal ((SUM r), var))]

let notone x =						
	if (x = CONST 1) then false else true
let notzero x =						
	if (x = CONST 0) then false else true


let rec arrange form =				
	match form with
	| TIMES lst ->
		 if ((List.filter notone lst)=[]) then CONST 1 else TIMES (CONST 1::List.filter notone lst)
	| SUM lst ->
		 if ((List.filter notzero lst)=[]) then CONST 0 else SUM (CONST 0::List.filter notzero lst)
	| _ -> form

let diff (form, var) =               
	arrange (cal (form, var))
