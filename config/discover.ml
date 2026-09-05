module C = Configurator.V1

(* Opt-in static link of libsodium, so the built binaries carry no
   libsodium.so.NN runtime dependency: set SODIUM_STATIC=1 in the build
   environment. Off by default -- a dynamic link is the normal behaviour, this
   is only for builds that ship their own libsodium. --push-state/--pop-state
   are GNU ld / lld only, hence Linux-only. *)
let static_requested c =
  match Sys.getenv_opt "SODIUM_STATIC" with
  | None | Some "" | Some "0" ->
      false
  | Some _ -> (
      match C.ocaml_config_var c "system" with
      | Some ("linux" | "linux_elf") ->
          true
      | _ ->
          false )

let statically c libs =
  if not (static_requested c) then libs
  else
    List.concat_map
      (function
        | "-lsodium" ->
            [ "-Wl,--push-state,-Bstatic"; "-lsodium"; "-Wl,--pop-state" ]
        | flag -> [ flag ])
      libs

let () =
  C.main ~name:"sodium" (fun c ->
      let default : C.Pkg_config.package_conf =
        { libs = [ "-lsodium" ]; cflags = [] }
      in
      let conf =
        match C.Pkg_config.get c with
        | None -> default
        | Some pc -> (
            match C.Pkg_config.query pc ~package:"libsodium" with
            | None -> default
            | Some deps -> deps)
      in
      C.Flags.write_sexp "c_flags.sexp" conf.cflags;
      C.Flags.write_sexp "c_library_flags.sexp" (statically c conf.libs))
