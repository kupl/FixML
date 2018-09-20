type metro = STATION of name
           | AREA of name * metro
           | CONNECT of metro * metro
and name = string

let rec checkMetro: metro -> bool = fun metro ->
    match metro with
    |STATION s -> false
    |AREA (n, m) -> (match m with
                    |STATION s -> if n = s then true
                                  else false
                    |AREA (n, m) -> checkMetro(AREA(n,m))
                    |CONNECT (m1, m2) -> checkMetro(AREA(n, m1))||checkMetro(AREA(n,m2)))
    |CONNECT (m1, m2) -> false


















