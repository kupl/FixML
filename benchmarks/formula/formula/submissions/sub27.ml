type formula = TRUE
  |FALSE
  |NOT of formula
  |ANDALSO of formula * formula
  |ORELSE of formula * formula
  |IMPLY of formula * formula
  |LESS of expr * expr
and expr = NUM of int
  |PLUS of expr * expr
  |MINUS of expr * expr

let rec plusminus x = match x with
  |PLUS (a,b) -> (plusminus a) + (plusminus b)
  |MINUS (a, b) -> (plusminus a)-(plusminus b)
  |NUM a -> a


let rec eval f = match f with
  |FALSE -> false
  |TRUE -> true
  |NOT value -> not (eval value)
  |ANDALSO (value,value1)->
      (match value with
        |TRUE ->
          (match value1 with
            |TRUE -> true
            |FALSE -> false
            |_ -> eval value1)
        |FALSE -> false
        |_ -> eval value)
  |ORELSE (value, value1) ->
      (match value with
        |TRUE -> true
        |FALSE ->
          (match value1 with
            |TRUE -> true
            |FALSE -> false
            |_ -> eval value1)
        |_ -> eval value)
  |IMPLY (value, value1) ->
      (match value with
        |TRUE ->
          (match value1 with
            |FALSE -> false
            |TRUE -> true
            |_ -> eval value1)
        |FALSE -> true
        |_ -> eval value)
  |LESS (value, value1) ->
    (match value, value1 with
      |a, b -> if (plusminus a)<(plusminus b) then true else false )



