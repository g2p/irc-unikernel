open Mirage

let client =
  let packages = [ "dns"; "irc-client" ] in
  let libraries = [ "dns.mirage"; "irc-client"; "lwt.ppx" ] in
  foreign
    ~libraries ~packages
    "Unikernel.Client" @@ console @-> stackv4 @-> job

let () =
  let stack = generic_stackv4 tap0 in
  let job =  [ client $ default_console $ stack ] in
  register "irc" job
