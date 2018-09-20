type formula = TRUE
             | FALSE
             | NOT of formula
             | ANDALSO of formula * formula
             | ORELSE of formula * formula
             | IMPLY of formula * formula
             | LESS of expr * expr
and expr = NUM of int
         | PLUS of expr * expr
         | MINUS of expr * expr

let rec calc:expr->int = fun expr ->
    match expr with
    |NUM a -> a
    |PLUS (a, b) -> (match (a,b) with
                    |(NUM a, NUM b) -> a + b
                    |(_, _) -> 0)
    |MINUS (a, b) -> (match (a,b) with
                     |(NUM a, NUM b) -> a - b
                     |(_, _) -> 0)
    
let rec eval:formula->bool = fun formula ->
    match formula with
    |TRUE -> true
    |FALSE -> false
    |NOT a -> (match a with
              |TRUE -> false
              |FALSE -> true
              |_ -> false)
    |ANDALSO (a,b) -> (match (a,b) with
                      |(TRUE,TRUE) -> true
                      |(TRUE,FALSE) -> false
                      |(FALSE,TRUE) -> false
                      |(FALSE,FALSE) -> false
                      |(_,_) -> false)

    |ORELSE (a,b) -> (match (a,b) with
                      |(TRUE,TRUE) -> true
                      |(TRUE,FALSE) -> true
                      |(FALSE,TRUE) -> true
                      |(FALSE,FALSE) -> false
                      |(_,_) -> false)

    |IMPLY (a,b) -> (match (a,b) with
                      |(TRUE,TRUE) -> true
                      |(TRUE,FALSE) -> false
                      |(FALSE,TRUE) -> true
                      |(FALSE,FALSE) -> true
                      |(_,_) -> false)

    |LESS (a, b) -> if calc a < calc b then true
                    else false

