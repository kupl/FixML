

type metro = STATION of name
		|	AREA of name * metro
		|	CONNECT of metro * metro
and name = string;;

let checkMetro mat =
	let rec checkStringInList(li, st) =
		match li with
		|	[] -> false
		|	a :: remain -> if (st= a) then true
						else checkStringInList(remain, st)
	in
	let rec checkStationInArea(listOfArea, subMat) =	
		match subMat with
		|	STATION s -> checkStringInList(listOfArea, s)
		|	CONNECT (m1, m2) -> (checkStationInArea(listOfArea, m1)
								&& checkStationInArea(listOfArea, m2))
		|	AREA(a, m) -> let newlist = a :: listOfArea in
						checkStationInArea(newlist, m)
	in
	match mat with
	|	STATION s -> false
	|	CONNECT (m1, m2) -> false
	|	AREA (a, m) -> checkStationInArea([a], m)
	;;


