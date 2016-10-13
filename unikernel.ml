open Lwt.Infix
open V1_LWT
open Printf

let irc_server = "chat.freenode.net"
let irc_port = 6667
let nick = "milog"
let username = nick
let realname = nick
let channel = "#mirage"

exception ConnectionFailure

module Client (C: CONSOLE) (STACK: STACKV4) = struct
  module Resolver = Dns_resolver_mirage.Make(OS.Time)(STACK)

  let start con stack =
    let resolver = Resolver.create stack in

    (* XXX Use Ephemeron.K1.Make *)
    let read_remainder = Hashtbl.create 1 in

    let module Irc_io = struct
      type 'a t = 'a Lwt.t
      let (>>=) = Lwt.bind
      let return = Lwt.return
      let iter = Lwt_list.iter_s

      type file_descr = STACK.TCPV4.flow
      type inet_addr = STACK.ipv4addr

      let open_socket addr port =
        match%lwt STACK.TCPV4.create_connection (STACK.tcpv4 stack) (addr, port) with
        |`Error `Refused -> Lwt.fail ConnectionFailure
        |`Error `Timeout -> Lwt.fail ConnectionFailure
        |`Error `Unknown _ -> Lwt.fail ConnectionFailure
        |`Ok flow -> Lwt.return flow
      let close_socket = STACK.TCPV4.close

      let read socket buf off len =
      (* read is tricky, because we might get more data than ocaml-irc-client has
       * room for in its read buffer *)
        assert%lwt (off == 0) >>
        assert%lwt (len == Bytes.length buf) >>
        match Hashtbl.find_all read_remainder socket with
        |(buf1, off1, len1)::_ ->
            (*let () = C.log con (sprintf "rem lengths %d %d" len1 len) in*)
            let len2 = min len len1 in
            let () = Cstruct.blit_to_bytes buf1 off1 buf off len2 in
            let () = if len2 == len1
            then Hashtbl.remove read_remainder socket
            else Hashtbl.replace read_remainder socket (buf1, off1+len2, len1-len2) in
            Lwt.return len2
        |[] -> begin
          STACK.TCPV4.read socket >>=
          function
             `Eof -> Lwt.return 0
            |`Error _ -> Lwt.fail ConnectionFailure
            |`Ok buf1 -> let len1 = Cstruct.len buf1 in
              (*let () = C.log con (sprintf "lengths %d %d" len1 len) in*)
              let len2 = min len len1 in
              let () = Cstruct.blit_to_bytes buf1 0 buf off len2 in
              let () = if len2 < len1
              then Hashtbl.add read_remainder socket (buf1, len2, len1-len2) in
              Lwt.return len2
        end

      let write socket buf off len =
        assert%lwt (off == 0) >>
        assert%lwt (len == String.length buf) >>
        STACK.TCPV4.write socket (Cstruct.of_string buf) >>=
        function
           `Eof -> Lwt.return 0
          |`Error _ -> Lwt.fail ConnectionFailure
          |`Ok () -> Lwt.return len

      let gethostbyname name =
        Resolver.gethostbyname resolver name >>=
        Lwt_list.filter_map_s
          (function
            Ipaddr.V4 ip -> return (Some ip) | Ipaddr.V6 _ -> return None)
    end in
    let module Irc = Irc_client.Make(Irc_io) in
    let on_message connection result =
      match result with
            | Result.Ok msg ->
                Lwt.return (C.log con (Irc_message.to_string msg))
            | Result.Error e ->
                Lwt.return (C.log con e)
    in
    Irc.connect_by_name ~server:irc_server ~port:irc_port ~nick ~username ~realname () >>=
      function
        |None -> Lwt.fail ConnectionFailure
        |Some connection ->
            Irc.send_join ~connection ~channel >>
            Irc.listen ~connection ~callback:on_message
end
