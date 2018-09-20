
type metro = STATION of name
		   | AREA of name * metro
		   | CONNECT of metro * metro
and name = string
let checkMetro m =
	let rec areaList m1 =
		match m1 with
		 AREA(a, b) -> a::areaList b
		|_ -> [] in
	let rec stationList m2 =
		match m2 with
		 STATION a -> [a]
		|AREA(a, b) -> stationList b
		|CONNECT(a, b) -> stationList a @ stationList b in
	let rec searchArea al st =
		match al with
		 [] -> false
		|hd::tl ->
			(if hd = st then true
			 else searchArea tl st) in
	let rec matching al sl =
		match sl with
		 [] -> true
		|hd::tl ->
			(if searchArea al hd = false then false
			 else matching al tl) in
	let _ = areaList m in
	let _ = stationList m in
	matching (areaList m) (stationList m)

	
