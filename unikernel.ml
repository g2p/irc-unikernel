open Lwt.Infix
open V1_LWT
open Printf

module Client (T: TIME) (C: CONSOLE) (RES: Resolver_lwt.S) (CON: Conduit_mirage.S) = struct
  let start _time c res (ctx:CON.t) =
    Lwt.return ()
end
