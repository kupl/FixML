
type formula = TRUE
	| FALSE
	| NOT of formula
	| ANDALSO of formula * formula
	| ORELSE of formula * formula
	| IMPLY of formula * formula
	| LESS of expr * expr
and expr = NUM of int
	| PLUS of expr * expr
	| MINUS of expr * expr;;

let rec eval f =
	let rec eval_expr e =
		match e with
		| NUM n -> n
		| PLUS(a, b) -> (eval_expr a + eval_expr b)
		| MINUS(a, b) -> (eval_expr a - eval_expr b)
	in
	match f with
	| TRUE -> true
	| FALSE -> false
	| NOT a -> eval a
	| ANDALSO(a, b) -> (eval a) && (eval b)
	| ORELSE(a, b) -> (eval a) || (eval b)
	| IMPLY(a, b) -> not  ((eval a) && not (eval b))
	| LESS(a, b) -> (eval_expr a) < (eval_expr b)
;;

