(*
  To call:
    dune exec ./generate_raml_tests.exe
*)

let host = "localhost"
let port = "8080"
let prefix = "api/v1"
let raml = "../../docs/nitrohsm-api.raml"
let allowed_methods = ["get" ; "put" ; "post"]
let allowed_request_types = [ "application/json" ; "application/x-pem-file" ; "application/octet-stream" ]

let escape s =
  let s' = Str.global_replace (Str.regexp_string "\"") "\\\"" s in
  let l = String.length s' in
  (* second part triggers Fatal error: exception (Invalid_argument "String.sub / Bytes.sub") *)
  if l > 4 && String.sub s' 0 2 = "\\\"" (*&& String.sub s' (l-4) l = "\\\""*)
  (* if its a string, remove escapes *)
  then begin
    let s' = String.sub s' 2 (l-4) in
    "\"" ^ s' ^ "\""
  end
  else
    "\"" ^ s' ^ "\""
  ;;

let get_endpoints meta = 
  Ezjsonm.get_dict meta |> List.partition (fun (key, _v) -> CCString.prefix ~pre:"/" key)

let get_meth meth meta = (* e.g. met is "get", "put", "post" *)
  Ezjsonm.get_dict meta |> List.partition (fun (key, _v) -> key = meth)


let write file content =
  let oc = open_out file in
  Printf.fprintf oc "%s\n" content;
  close_out oc;
  ()

let make_post_data req = 
  let mediatypes = Ezjsonm.get_dict @@ Ezjsonm.find req ["body"] in
  let f (mediatype, req') =
    if not @@ List.mem mediatype allowed_request_types
    then Printf.printf "Request type %s found but not supported, raml malformed?" mediatype;
    let header = "-H \"Content-Type: " ^ mediatype ^ "\" " in
    header ^ "--data " ^ escape @@ Ezjsonm.(value_to_string @@ find req' ["example"])
  in
  List.map f mediatypes
 
let make_req_data req = function
  | "get" -> [""]
  | "post" 
  | "put" -> make_post_data req
  | m -> Printf.printf "method %s not allowed" m; [""]

let print_method path (meth, req) =
  if List.mem meth allowed_methods (* skips descriptions *)
  then begin 
    let reqs = make_req_data req meth in
    let cmd = Printf.sprintf "curl http://%s:%s/%s%s -X %s" host port prefix path (String.uppercase_ascii meth) in
    let p req =
      Printf.printf "%s %s \n\n" cmd req(*;
      let outfile = Printf.sprintf "generated%s_%s" path meth in
      write outfile cmd*)
    in
    List.iter p reqs;
  end

let print_methods (path, methods) =
  List.iter (print_method path) methods

let rec subpaths (path, meta) =
  let (endpoints, _) = get_endpoints meta in
  if endpoints = [] 
  then [ (path, Ezjsonm.get_dict meta) ]
  else List.concat_map (fun (subpath, m) -> subpaths (path ^ subpath, m)) endpoints

let example = CCIO.with_in raml CCIO.read_all
  |> Yaml.of_string
  |> Stdlib.Result.get_ok

(* all paths, start from empty root *)
let () = 
  let paths = subpaths ("", example) in
  List.iter (fun (a, _b) -> Printf.printf "%s\n" a ) paths;
  List.iter print_methods paths;
