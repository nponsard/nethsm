open Lwt.Infix

module Make (Wm : Webmachine.S with type +'a io = 'a Lwt.t) (Hsm : Hsm.S) = struct

  module Access = Access.Make(Hsm)

  type body = Cohttp_lwt.Body.t

  let respond_error (e, body) rd = 
    let code = Hsm.error_to_code e in
    Wm.respond ~body:(`String body) code rd

  let err_to_bad_request ok rd = function
    | Error m -> respond_error (Bad_request, m) rd
    | Ok data -> ok data 

  class virtual base = object
    inherit [body] Wm.resource
  end

  class no_cache = object
    method finish_request : (unit, body) Wm.op = fun rd ->
      let cc hdr = Cohttp.Header.replace hdr "Cache-control" "no-cache" in
      let rd' = Webmachine.Rd.with_resp_headers cc rd in
      Wm.continue () rd'
  end

  class role hsm_state role = object
    method is_authorized : (Wm.auth, body) Wm.op = fun rd ->
      Access.is_authorized hsm_state rd >>= fun (auth, rd') ->
      Wm.continue auth rd'

    method forbidden : (bool, body) Wm.op = fun rd ->
      Access.forbidden hsm_state role rd >>= fun auth ->
      Wm.continue auth rd
  end

  class role_operator_get hsm_state = object
    method is_authorized : (Wm.auth, body) Wm.op = fun rd ->
      Access.is_authorized hsm_state rd >>= fun (auth, rd') ->
      Wm.continue auth rd'

    method forbidden : (bool, body) Wm.op = fun rd ->
      Access.forbidden hsm_state `Administrator rd >>= function
      | true when rd.meth = `GET -> (* no admin - only get allowed for operator *)
        Access.forbidden hsm_state `Operator rd >>= fun not_an_operator ->
        Wm.continue not_an_operator rd
      | not_an_admin -> Wm.continue not_an_admin rd
  end

  class input_state_validated hsm_state allowed_input_states = object
    method service_available : (bool, body) Wm.op =
      if List.exists (Access.is_in_state hsm_state) allowed_input_states
      then Wm.continue true
      else Wm.respond (Cohttp.Code.code_of_status `Precondition_failed)
  end

  class virtual get_json = object(self)
    method virtual private to_json : body Wm.provider

    method content_types_provided : ((string * body Wm.provider) list, body) Wm.op =
      Wm.continue [ ("application/json", self#to_json) ]

    method content_types_accepted : ((string * body Wm.acceptor) list, body) Wm.op =
      Wm.continue [ ]
  end

  class virtual put_json = object(self)
    method virtual private of_json : Yojson.Safe.t -> body Wm.acceptor

    method content_types_accepted : ((string * body Wm.acceptor) list, body) Wm.op =
      Wm.continue [  ("application/json", self#parse_json) ]

   method content_types_provided : ((string * body Wm.provider) list, body) Wm.op =
      Wm.continue [ ("application/json", Wm.continue `Empty) ]

    method private parse_json rd =
      let body = rd.Webmachine.Rd.req_body in
      Cohttp_lwt.Body.to_string body >>= fun content ->
      try self#of_json (Yojson.Safe.from_string content) rd
      with Yojson.Json_error msg ->
        respond_error
          (Hsm.Bad_request, Printf.sprintf "Invalid JSON: %s." msg)
          rd

    method allowed_methods : (Cohttp.Code.meth list, body) Wm.op =
      Wm.continue [ `PUT ]
  end

  class virtual post = object(self)
    method virtual process_post : (bool, body) Wm.op

    method content_types_accepted : ((string * body Wm.acceptor) list, body) Wm.op =
      Wm.continue [ ("application/json", self#process_post) ]

    method content_types_provided : ((string * body Wm.provider) list, body) Wm.op =
      Wm.continue [ ("application/json", Wm.continue `Empty) ]

    method allowed_methods : (Cohttp.Code.meth list, body) Wm.op =
      Wm.continue [ `POST ]
  end

  class virtual post_json = object(self)
    inherit post

    method virtual private of_json : Yojson.Safe.t -> body Wm.acceptor

    method private parse_json rd =
      let body = rd.Webmachine.Rd.req_body in
      Cohttp_lwt.Body.to_string body >>= fun content ->
      try self#of_json (Yojson.Safe.from_string content) rd
      with Yojson.Json_error msg ->
        respond_error
          (Hsm.Bad_request, Printf.sprintf "Invalid JSON: %s." msg)
          rd

    method process_post = self#parse_json
  end

end