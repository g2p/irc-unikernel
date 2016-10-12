open Lwt.Infix
open V1_LWT
open Printf

let ns = "8.8.8.8"

exception ConnectionFailure
exception NotImplemented

module Client (T: TIME) (C: CONSOLE) (STACK: STACKV4) (RES: Resolver_lwt.S) (CON: Conduit_mirage.S) = struct
  let start _time c stack res (ctx:CON.t) =

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
        |`Error `Unknown st -> Lwt.fail ConnectionFailure
        |`Ok flow -> Lwt.return flow
      let close_socket = STACK.TCPV4.close

      let read socket buf off len = Lwt.fail NotImplemented
      let write socket buf off len = Lwt.fail NotImplemented

      let gethostbyname name = Lwt.fail NotImplemented
    end in
    let module Irc = Irc_client.Make(Irc_io) in
    Lwt.return ()
end
