open Mirage

let irc_nick =
    let doc = Key.Arg.info ~doc:"IRC nickname." ["irc-nick"] in
    Key.(abstract @@ create "irc-nick" Arg.(opt string "milog" doc))

let client =
  let packages = [ "dns"; "irc-client" ] in
  let libraries = [ "dns.mirage"; "irc-client"; "lwt.ppx" ] in
  foreign
    ~libraries ~packages ~keys:[irc_nick]
    "Unikernel.Client" @@ console @-> stackv4 @-> job

let () =
  let stack = generic_stackv4 tap0 in
  let job =  [ client $ default_console $ stack ] in
  register "irc" job
