open Lwt.Infix

module Make (Wm : Webmachine.S with type +'a io = 'a Lwt.t) = struct

  class handler hsm_state = object(self)
    inherit [Cohttp_lwt.Body.t] Wm.resource

    method private system_info rd =
      match Webmachine.Rd.lookup_path_info "ep" rd with
      | Some "info" -> 
        let open Hsm in
        let json = Yojson.Safe.to_string (system_info_to_yojson @@ system_info hsm_state) in
        Wm.continue (`String json) rd
      | _ -> Wm.respond (Cohttp.Code.code_of_status `Not_found) rd
       
    (* TODO we get 500 instead of 200 when we post to reset etc *)
    method private system rd =
      match Webmachine.Rd.lookup_path_info "ep" rd with
      | Some "reboot" -> 
        Hsm.reboot () ;
        Wm.continue true rd
      | Some "shutdown" -> 
        Hsm.shutdown () ;
        Wm.continue true rd
      | Some "reset" ->
        Hsm.reset () ;
        Wm.continue true rd
      | Some "update" ->  Wm.respond (Cohttp.Code.code_of_status `Not_found) rd
      | Some "backup" ->  Wm.respond (Cohttp.Code.code_of_status `Not_found) rd
      | Some "restore" -> Wm.respond (Cohttp.Code.code_of_status `Not_found) rd
      | _ -> Wm.respond (Cohttp.Code.code_of_status `Not_found) rd
 
    method !process_post rd =
      Wm.continue true rd 

    method !allowed_methods rd =
      Wm.continue [ `GET ; `POST ] rd
 
    method content_types_provided rd =
      Wm.continue [ ("application/json", self#system_info) ] rd

    method content_types_accepted rd =
      Wm.continue [ ("application/json", self#system) ] rd

  end

end
