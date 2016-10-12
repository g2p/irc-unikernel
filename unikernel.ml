open V1_LWT

let ns = "8.8.8.8"

exception ConnectionFailure
exception NotImplemented

module Client (T: TIME) (C: CONSOLE) (STACK: STACKV4) (RES: Resolver_lwt.S) (CON: Conduit_mirage.S) = struct
  module Resolver = Dns_resolver_mirage.Make(OS.Time)(STACK)

  let start _time _ stack _ _ =
    let resolver = Resolver.create stack in

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
        STACK.TCPV4.read socket >>=
        function
           `Eof -> Lwt.return 0
          |`Error _ -> Lwt.fail ConnectionFailure
          |`Ok buf1 -> let len1 = Cstruct.len buf1 in
            assert%lwt (len1 <= len) >> (* XXX DOS *)
            begin Cstruct.blit_to_bytes buf1 0 buf 0 len1;
            Lwt.return len1 end

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
    Lwt.return ()
end
