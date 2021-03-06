open Lang
open Util
open Label_lang
open Print
open Labeling

(* set of execution traces *)
type trace_set = int BatSet.t

let empty_set = BatSet.empty
let extend_set = BatSet.add

(* set of execution traces *)
let trace_set = ref empty_set
let init_set () = (trace_set := empty_set)

let start_time = ref 0.0

(* Find counter exampels *)
let rec is_counter_example : prog -> example -> bool
= fun pgm (input, output) ->
  let res_var = "__res__" in
  let pgm = pgm@(External.grading_prog) in
  let pgm' = pgm @ [(DLet (BindOne res_var,false,[],fresh_tvar(),(Lang.appify (EVar !Options.opt_entry_func) input)))] in
  try
    let env = Eval.run pgm' in
    let result = Lang.lookup_env res_var env in
    not (Eval.value_equality result output)
  with _ -> true

let rec find_counter_examples : prog -> examples -> examples * examples
= fun pgm examples -> List.partition (is_counter_example pgm) examples

(*****************************************************************)
(* labeled exp evaluation -> should merge it with non-labeld ver *)
(*****************************************************************)
(* Block task *)
let rec is_fun : labeled_value -> bool
= fun v ->
  match v with
  | VList vs -> List.exists is_fun vs 
  | VTuple vs -> List.exists is_fun vs
  | VCtor (x, vs) -> List.exists is_fun vs
  | VFun (x, e, closure) -> true
  | VFunRec (f, x, e, closure) -> true
  | VBlock (f, vs) -> true
  | _ -> false

let rec update_closure : labeled_env -> labeled_value -> labeled_value
= fun env v ->
  match v with
  | VList vs -> VList (List.map (update_closure env) vs)
  | VTuple vs -> VTuple (List.map (update_closure env) vs)
  | VCtor (x, vs) -> VCtor (x, List.map (update_closure env) vs)
  | VFun (x, e, closure) -> VFun (x, e, env)
  | VFunRec (f, x, e, closure) -> VFunRec (f, x, e, env)
  | VBlock (f, vs) -> 
    let (xs, vs) = List.split vs in
    let vs = List.map (update_closure env) vs in
    VBlock (f, List.combine xs vs)
  | _ -> v

let rec find_callee : id -> (id * labeled_value) list -> labeled_value
= fun x vs ->
  match vs with
  | [] -> raise (Failure "not found")
  | (y, v)::tl -> if x = y then v else find_callee x tl

let bind_block : labeled_env -> (id * labeled_value) list -> labeled_env
= fun env vs ->
  let (xs, _) = List.split vs in
  List.fold_left (fun env x -> update_env x (VBlock (x, vs)) env) env xs

(* Argument binding *)
let rec arg_binding : labeled_env -> arg -> labeled_value -> labeled_env
= fun env arg v ->
  match (arg, v) with
  | ArgUnder t, _ -> env
  | ArgOne (x, t), _ -> update_env x v env 
  | ArgTuple xs, VTuple vs ->
    (
      try List.fold_left2 arg_binding env xs vs 
      with 
      | Invalid_argument _ -> raise (Failure "argument binding failure - tuples are not compatible")
      | _ -> raise (StackOverflow "Stack overflow during evaluation (looping recursion?)")
    )
  | _ -> raise (Failure "argument binding failure")

let rec let_binding : labeled_env -> let_bind -> labeled_value -> labeled_env
= fun env x v ->
  match (x, v) with
  | BindUnder, _ -> env
  | BindOne x, _ -> update_env x v env
  | BindTuple xs, VTuple vs -> 
    (
      try List.fold_left2 let_binding env xs vs 
      with 
      | Invalid_argument _ -> raise (Failure "argument binding failure - tuples are not compatible")
      | _ -> raise (StackOverflow "Stack overflow during evaluation (looping recursion?)")
    )
  | _ -> raise (Failure "let binding failure")

(* Pattern Matching *)
let rec find_first_branch : labeled_value -> labeled_branch list -> (pat * labeled_exp)
= fun v bs -> 
  match bs with 
  | [] -> raise (Failure "Pattern matching failure")
  | (p, e)::tl -> if (pattern_match v p) then (p, e) else find_first_branch v tl

and pattern_match : labeled_value -> pat -> bool
= fun v p ->
  match (v, p) with
  | VInt n1, PInt n2 -> n1 = n2
  | VBool b1, PBool b2 -> b1 = b2
  | VList l1, PList l2 -> pattern_match_list l1 l2
  | VTuple l1, PTuple l2 -> pattern_match_list l1 l2
  | VCtor (x1, l1), PCtor (x2, l2) -> (x1 = x2) && pattern_match_list l1 l2
  | VList [], PCons (phd::ptl) -> if ptl = [] then (pattern_match v phd) else false
  | VList (vhd::vtl), PCons (phd::ptl) -> if ptl = [] then (pattern_match v phd) else (pattern_match vhd phd) && (pattern_match (VList vtl) (PCons ptl))
  | _, PVar x -> true
  | _, PUnder -> true
  | _, Pats pl -> (try List.exists (pattern_match v) pl with _ -> false)
  | _ -> false

and pattern_match_list : labeled_value list -> pat list -> bool
= fun vs ps -> try List.for_all2 pattern_match vs ps with _ -> false

let rec check_patterns : pat list -> bool
= fun ps ->
  let var_set_list = List.map (gather_vars BatSet.empty) ps in
  let base = List.hd var_set_list in
  List.for_all (fun set -> BatSet.equal set base) var_set_list

and gather_vars : id BatSet.t -> pat -> id BatSet.t
= fun set p ->
  match p with
  | PVar x -> BatSet.add x set
  | PList ps | PTuple ps | PCtor (_, ps) | PCons ps | Pats ps -> List.fold_left gather_vars set ps
  | _ -> set

let rec bind_pat : labeled_env -> labeled_value -> pat -> labeled_env
= fun env v p ->
  match (v, p) with
  | _, PInt n2 -> env
  | _, PBool b2 -> env
  | _, PUnder -> env
  | _, PVar x -> update_env x v env
  | _, Pats ps -> if check_patterns ps then bind_pat env v (List.find (pattern_match v) ps) else raise (Failure "Invalid pattern list")
  | VList l1, PList l2 -> bind_pat_list env l1 l2 
  | VTuple l1, PTuple l2 -> bind_pat_list env l1 l2
  | VCtor (x1, l1), PCtor (x2, l2) -> bind_pat_list env l1 l2
  | VList [], PCons (phd::ptl) ->  if ptl = [] then (bind_pat env v phd) else raise (Failure "Pattern binding failure")
  | VList (vhd::vtl), PCons (phd::ptl) -> if ptl = [] then bind_pat env v phd else bind_pat (bind_pat env vhd phd) (VList vtl) (PCons ptl)
  | _ -> raise (Failure "Pattern binding failure")

and bind_pat_list : labeled_env -> labeled_value list -> pat list -> labeled_env
= fun env vs ps -> List.fold_left2 bind_pat env vs ps

let rec value_equality : labeled_value -> labeled_value -> bool
= fun v1 v2 ->
  match v1,v2 with
  | VBool b1,VBool b2 -> b1=b2
  | VInt n1,VInt n2 -> n1=n2
  | VString id1,VString id2 -> id1=id2
  | VList l1, VList l2
  | VTuple l1, VTuple l2 -> (try List.for_all2 value_equality l1 l2 with _ -> false)
  | VCtor (x1,l1), VCtor(x2,l2) -> (try ((x1=x2) && List.for_all2 value_equality l1 l2) with _ -> false)
  | _ -> false

(* exp evaluation *)
let rec eval : labeled_env -> labeled_exp -> labeled_value
= fun env (label, e) -> 
  (trace_set := extend_set label !trace_set);  (* gather execution traces *)
  if (Unix.gettimeofday() -. !start_time >0.2) then raise (Failure "Timeout")
  else
  match e with
  | EUnit -> VUnit
  | Const n -> VInt n
  | TRUE -> VBool true
  | FALSE -> VBool false
  | String id -> VString id
  | EVar x -> lookup_env x env
  | EList es -> VList (List.map (eval env) es)
  | ETuple es -> VTuple (List.map (eval env) es)
  | ECtor (c, es) ->  VCtor (c, List.map (eval env) es)
  (* aop *)
  | ADD (e1, e2) -> (eval_abop env e1 e2 (+))
  | SUB (e1, e2) -> (eval_abop env e1 e2 (-))
  | MUL (e1, e2) -> (eval_abop env e1 e2 ( * ))
  | DIV (e1, e2) -> (eval_abop env e1 e2 (/))
  | MOD (e1, e2) -> (eval_abop env e1 e2 (mod))
  | MINUS e ->
    begin match (eval env e) with
    | VInt n -> VInt (-n)
    | _ -> raise (Failure "arithmetic_operation error")
    end
  (*bexp*)
  | NOT e -> 
    begin match (eval env e) with
    | VBool b -> VBool (not b)
    | _ -> raise (Failure "boolean_operation error")
    end
  | OR (e1, e2) -> (eval_bbop env e1 e2 (||))
  | AND (e1, e2) -> (eval_bbop env e1 e2 (&&))
  | LESS (e1, e2) -> (eval_abbop env e1 e2 (<))
  | LARGER (e1, e2) -> (eval_abbop env e1 e2 (>))
  | LESSEQ (e1, e2) -> (eval_abbop env e1 e2 (<=))
  | LARGEREQ (e1, e2) -> (eval_abbop env e1 e2 (>=))
  | EQUAL (e1, e2) -> VBool (eval_equality env e1 e2)
  | NOTEQ (e1, e2) -> VBool (not (eval_equality env e1 e2))
  (* lop *)
  | AT (e1, e2) ->
    begin match (eval env e1, eval env e2) with
    | VList vs1, VList vs2 -> VList (vs1 @ vs2)
    | _ -> raise (Failure "list_operation error")
    end
  | DOUBLECOLON (e1, e2) ->
    begin match (eval env e2) with
    | VList vs -> VList ((eval env e1)::vs) 
    | _ -> raise (Failure "list_operation error")
    end
  | STRCON (e1,e2) ->
    let (v1,v2) = (eval env e1,eval env e2) in
    begin match v1,v2 with
    | VString str1,VString str2 -> VString (str1 ^ str2)
    | _ -> raise (Failure "string_operation error")
    end
  (* else *)
  | IF (e1, e2, e3) ->
    begin match (eval env e1) with
    | VBool true -> eval env e2
    | VBool false -> eval env e3
    | _ -> raise (Failure "if_type error")
    end
  | ELet (f, is_rec, args, typ, e1, e2) -> 
    begin match args with
    | [] ->
      (* Value binding *)
      if is_rec then 
        let v1 = eval env e1 in
        begin match v1 with
        | VFun (x, e, closure) -> 
          begin match f with
          | BindOne f -> eval (update_env f (VFunRec (f, x, e, closure)) env) e2
          | _ -> raise (Failure "Only variables are allowed as left-hand side of `let rec'")
          end
        | _ -> eval (let_binding env f v1) e2
        end
      else eval (let_binding env f (eval env e1)) e2
    | _ ->
      (* Function binding *)
      let rec binding : arg list -> labeled_exp -> labeled_exp 
      = fun xs e -> 
        begin match xs with
        | [] -> e
        | hd::tl -> (dummy_label, EFun (hd, binding tl e))
        end 
      in
      let x = List.hd args in
      let vf = 
        if is_rec then
          begin match f with
          | BindOne f -> VFunRec (f, x, (binding (List.tl args) e1), env)
          | _ -> raise (Failure "Only variables are allowed as left-hand side of `let rec'")
          end
        else 
          VFun (x, (binding (List.tl args) e1), env)
      in
      eval (let_binding env f vf) e2
    end
  | EBlock (is_rec, bindings, e2) -> 
    let env = 
      begin match is_rec with
      | true ->
        let (func_map, const_map) = List.fold_left (
          fun (func_map, const_map) (f, is_rec, args, typ, exp) ->
          begin match f with 
          | BindOne x ->
            let v = eval env (dummy_label, ELet (BindOne x, is_rec, args, typ, exp, let_to_lexp f)) in
            if is_fun v then ((x, v)::func_map, const_map) else (func_map, (x, v)::const_map)
          | _ -> raise (Failure "l-value cannot be a tupple")
          end
        ) ([], []) bindings
        in
        (* constant mapping *)
        let init_env = List.fold_left (fun env (x, c) -> update_env x c env) env const_map in
        (* update each function's closure *)
        let func_map = List.map (fun (x, v) -> (x, update_closure init_env v)) func_map in
        (* block mapping *)
        List.fold_left (fun env (x, v) -> update_env x (VBlock (x, func_map)) env) init_env func_map
      | false ->
        let vs = List.map (fun (f, is_rec, args, typ, e) -> eval env (dummy_label, ELet (f, is_rec, args, typ, e, let_to_lexp f))) bindings in
        List.fold_left2 (fun env (f, is_rec, args, typ, e) v -> let_binding env f v) env bindings vs
      end
    in eval env e2
  | EMatch (e, bs) ->
    let v = eval env e in
    let (p, ex) = find_first_branch v bs in
    eval (bind_pat env v p) ex
  | EFun (arg, e) -> VFun (arg, e, env)
  | EApp (e1, e2) ->
    let (v1, v2) = (eval env e1, eval env e2) in
    begin match v1 with
    | VFun (x, e, closure) -> eval (arg_binding closure x v2) e
    | VFunRec (f, x, e, closure) -> eval (update_env f v1 (arg_binding closure x v2)) e
    | VBlock (f, vs) ->
      let v = find_callee f vs in
      begin match v with
      | VFunRec (f, x, e, closure) -> 
        let block_env = bind_block closure vs in
        eval (arg_binding block_env x v2) e
      | _ -> raise (Failure "mutually recursive function call error")
      end
    | _ -> raise (Failure "function_call error")
    end
  | Hole n -> VHole n
  | Raise e -> 
    let e = eval env e in
    raise (LExcept e)

and eval_abop : labeled_env -> labeled_exp -> labeled_exp -> (int -> int -> int) -> labeled_value
= fun env e1 e2 op ->
  match (eval env e1, eval env e2) with
  | VInt n1, VInt n2 -> VInt (op n1 n2)
  | _ -> raise (Failure "arithmetic_operation error")

and eval_abbop : labeled_env -> labeled_exp -> labeled_exp -> (int -> int -> bool) -> labeled_value
= fun env e1 e2 op ->
  match (eval env e1, eval env e2) with
  | VInt n1, VInt n2 -> VBool (op n1 n2)
  | _ -> raise (Failure "int_relation error")

and eval_bbop : labeled_env -> labeled_exp -> labeled_exp -> (bool -> bool -> bool) -> labeled_value
= fun env e1 e2 op ->
  match (eval env e1, eval env e2) with
  | VBool b1, VBool b2 -> VBool (op b1 b2)
  | _ -> raise (Failure "boolean_operation error")

and eval_equality : labeled_env -> labeled_exp -> labeled_exp -> bool
= fun env e1 e2->
  let (x,y) = (eval env e1, eval env e2) in
  (value_equality x y)

let check_entry f entry_func =
  match f with
  |BindOne x -> (x=entry_func)
  |_ -> false

let rec eval_decl : labeled_env -> labeled_decl -> labeled_env
= fun env decl -> 
  match decl with
  | DLet (f, is_rec, args, typ, e) -> 
    let e = (dummy_label, ELet (f, is_rec, args, typ, e, (let_to_lexp f))) in
    let_binding env f (eval env e)
  | DBlock (is_rec, bindings) ->
    begin match is_rec with
    | true ->
      let (func_map, const_map) = List.fold_left (
        fun (func_map, const_map) (f, is_rec, args, typ, exp) ->
        begin match f with 
        | BindOne x ->
          let v = eval env (dummy_label, ELet (BindOne x, is_rec, args, typ, exp, let_to_lexp f)) in
          if is_fun v then ((x, v)::func_map, const_map) else (func_map, (x, v)::const_map)
        | _ -> raise (Failure "l-value cannot be a tupple")
        end
      ) ([], []) bindings
      in
      (* constant mapping *)
      let init_env = List.fold_left (fun env (x, c) -> update_env x c env) env const_map in
      (* update each function's closure *)
      let func_map = List.map (fun (x, v) -> (x, update_closure init_env v)) func_map in
      (* block mapping *)
      List.fold_left (fun env (x, v) -> update_env x (VBlock (x, func_map)) env) init_env func_map
    | false ->
      let envs = List.map (fun binding -> eval_decl env (DLet binding)) bindings in
      List.fold_left (fun env new_env -> BatMap.union env new_env) env envs
    end
  | _ -> env

let run : labeled_prog -> labeled_env
= fun decls ->
  start_time:=Unix.gettimeofday();
  let init_env = List.fold_left eval_decl empty_env (Labeling.labeling_prog (External.init_prog)) in
  init_set ();
  start_time := Unix.gettimeofday();
  let decls = decls@(Labeling.labeling_prog (External.grading_prog)) in
  List.fold_left eval_decl init_env decls

let rec collect_execution_trace : labeled_prog -> example -> trace_set
= fun pgm (input, output) ->
  let pgm = pgm @ labeling_prog (External.grading_prog) in
  let res_var = "__res__" in
  let pgm' = pgm @ labeling_prog [(DLet (BindOne res_var, false, [], fresh_tvar(), (Lang.appify (EVar !Options.opt_entry_func) input)))] in
  try
    let _  = run pgm' in
    !trace_set
  with _ -> !trace_set

let gen_label_map (ex : examples) (pgm : labeled_prog) : (int, int) BatMap.t =
	List.fold_left (fun map example ->
		let label_set = collect_execution_trace pgm example in
		BatSet.fold (fun label m ->
			if BatMap.mem label m then BatMap.add label ((BatMap.find label m)+1) m
			else BatMap.add label 1 m
		) label_set map
	) BatMap.empty ex

let weight : labeled_prog -> examples -> examples -> (int, float) BatMap.t
= fun l_pgm pos neg ->
	let counter_map = gen_label_map neg l_pgm in
	let pass_map = gen_label_map pos l_pgm in
	let counter_num = List.length neg in
	let pass_num = List.length pos in
	let weight_function = BatMap.foldi (fun label n result ->
		if(BatMap.mem label pass_map) then 
			let w = (float_of_int (BatMap.find label pass_map)) /. float_of_int(counter_num+pass_num) in
			BatMap.add label w result
		else BatMap.add label 0.0 result
	) counter_map BatMap.empty in
	weight_function

let cost_avg : (int, float) BatMap.t -> labeled_prog -> float
= fun w l_pgm->
	let pgm_set = BatMap.foldi (fun l _ acc ->
		let hole_pgm = gen_hole_pgm l l_pgm in
		BatSet.add (unlabeling_prog hole_pgm) acc
	) w BatSet.empty in
	let sum = BatSet.fold (fun pgm acc->
		let rank = (cost (unlabeling_prog l_pgm)) - (cost pgm) in
		acc +. (float_of_int rank)
	) pgm_set 0.0 in
	sum /. (float_of_int (BatSet.cardinal pgm_set))

let rec naive_exp :labeled_exp -> int BatSet.t -> int BatSet.t
= fun (label,e) env ->
   let env = BatSet.add label env in
   match e with
  | EUnit | Const _ | TRUE | FALSE | String _ | EVar _ | Hole _ -> env
  | EList es | ETuple es | ECtor (_,es)-> list_fold (fun e r -> naive_exp e r) es env
  (* aop *)
  | ADD (e1, e2) | SUB (e1,e2) | MUL (e1,e2) | DIV (e1,e2) | MOD (e1,e2) |STRCON (e1,e2) |OR (e1,e2) | AND (e1,e2) | LESS (e1,e2)
   | LARGER (e1,e2) | LESSEQ (e1,e2) | LARGEREQ (e1,e2) | EQUAL (e1,e2) | NOTEQ (e1,e2) | AT (e1,e2) | DOUBLECOLON (e1,e2) | EApp (e1,e2)
   | ELet (_,_,_,_,e1,e2)-> 
      let env = naive_exp e1 env in
      naive_exp e2 env
  | MINUS e | NOT e | EFun (_,e) | Raise e-> naive_exp e env
  (* else *)
  | IF (e1, e2, e3) ->
      let env = naive_exp e1 env in
      let env = naive_exp e2 env in
      naive_exp e3 env
  | EBlock (is_rec, bindings, e2) -> 
      let env = naive_exp e2 env in
      list_fold (fun (_,_,_,_,e) env -> naive_exp e env) bindings env
  | EMatch (e, bs) ->
    let env = naive_exp e env in
      list_fold (fun (_,e) env -> naive_exp e env) bs env 

let rec naive_decl : labeled_decl -> int BatSet.t -> int BatSet.t
= fun decl env ->
   match decl with
  | DLet (f, is_rec, args, typ, e) ->
      naive_exp e env
  | DBlock (is_rec, bindings) ->
      list_fold (fun (_,_,_,_,e) env -> naive_exp e env) bindings env
  | _ -> env

let rec naive : labeled_prog -> int BatSet.t
= fun l_pgm -> list_fold naive_decl l_pgm BatSet.empty
   

(* Find inital candidates *)
let localization : prog -> examples -> (int * prog) BatSet.t
= fun pgm examples ->
  let (counter_examples,pass_examples) = find_counter_examples pgm examples in
  let l_pgm = Labeling.labeling_prog pgm in
  let weight_function = weight l_pgm pass_examples counter_examples in
  let avg = cost_avg weight_function l_pgm in
  let candidate_set = BatMap.foldi (fun label weight set ->
    let hole_pgm = gen_hole_pgm label l_pgm in
    let candidate_pgm = unlabeling_prog hole_pgm in
    let rank = ((cost pgm) - (cost candidate_pgm)) in
    let rank = int_of_float ((float_of_int rank) +. (weight *. avg)) in
    if (Synthesize.is_closed candidate_pgm) then  set else extend_set (rank, candidate_pgm) set
  ) weight_function empty_set in
  candidate_set