open Mirage

let irc_nick =
    let doc = Key.Arg.info ~doc:"IRC nickname." ["irc-nick"] in
    Key.(abstract @@ create "irc-nick" Arg.(opt string "milog" doc))

let client =
  let packages = [ "git-mirage"; "irmin"; "mirage-dns"; "irc-client" ] in
  let libraries = [ "git.mirage"; "irmin"; "dns.mirage"; "irc-client"; "lwt.ppx" ] in
  foreign
    ~libraries ~packages ~keys:[irc_nick]
    ~deps:[abstract nocrypto]
    "Unikernel.Client" @@ console @-> stackv4 @-> fs @-> job

let () =
  let fat = fat_of_files ~regexp:".gitignore" () in
  let stack = generic_stackv4 tap0 in
  let job =  [ client $ default_console $ stack $ fat ] in
  register "irc" job
