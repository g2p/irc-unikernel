open Mirage

let client =
  let packages = [ "mirage-http"; "duration"; "irc-client" ] in
  let libraries = [ "mirage-http"; "duration"; "irc-client"; "lwt.ppx" ] in
  foreign
    ~libraries ~packages
    "Unikernel.Client" @@ time @-> console @-> stackv4 @-> resolver @-> conduit @-> job

let () =
  let stack = generic_stackv4 tap0 in
  let res_dns = resolver_dns stack in
  let conduit = conduit_direct stack in
  let job =  [ client $ default_time $ default_console $ stack $ res_dns $ conduit ] in
  register "irc" job
