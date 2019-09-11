open Mirage

let stack = generic_stackv4 default_network
let htdocs_key = Key.(value @@ kv_ro ~group:"htdocs" ())
let htdocs = generic_kv_ro ~key:htdocs_key "htdocs"
(* set ~tls to false to get a plain-http server *)
let https_srv = cohttp_server @@ conduit_direct ~tls:true stack

let http_port =
  let doc = Key.Arg.info ~doc:"Listening HTTP port." ["http"] in
  Key.(create "http_port" Arg.(opt int 8080 doc))

let store = direct_kv_rw "store"

let https_port =
  let doc = Key.Arg.info ~doc:"Listening HTTPS port." ["https"] in
  Key.(create "https_port" Arg.(opt int 4433 doc))

let main =
  let packages = [
    package "keyfender"; 
  ] in
  let keys = List.map Key.abstract [ http_port; https_port ] in
  foreign
    ~packages ~keys
    "Unikernel.Main" (random @-> pclock @-> kv_ro @-> kv_rw @-> http @-> job)

let () =
  register "keyfender" [main $ default_random $ default_posix_clock $ htdocs $ store $ https_srv]
