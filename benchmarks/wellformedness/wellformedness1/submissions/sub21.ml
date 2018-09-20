

type metro = STATION of name
	   | AREA of name * metro
           | CONNECT of metro * metro
and name = string





let rec list_station ipt =
  match ipt with
   STATION(a) -> a::[]
  |AREA(a,m) -> list_station(m)
  |CONNECT(m1,m2) -> list_station(m1) @ list_station(m2) ;;

let rec list_area ipt =
  match ipt with
   STATION(a) -> []
  |AREA(a,m) -> a::list_area(m)
  |CONNECT(m1,m2) -> list_area(m1) @ list_area(m2);;

let rec list_matching (ipt1,ipt2) = 
  match ipt1 with
   [] -> true
  | _ -> if (List.mem (List.hd(ipt1)) ipt2) then list_matching (List.tl(ipt1),ipt2)
         else false;;



let checkMetro ipt =
  if list_matching(list_station(ipt), list_area(ipt)) && list_matching(list_area(ipt), list_station(ipt)) then true
  else false;;

