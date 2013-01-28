open Core.Std

module Command = Core_extended.Std.Core_command

(* BEGIN -- useful utilities *)

include struct
  open Async.Std
  let uses_async =
    Command.Spec.step (fun finished ->
      printf "uses_async\n%!";
      upon finished Shutdown.shutdown;
      never_returns (Scheduler.go ()))
end

let flag_prompt_if_missing name of_string ~doc =
  let open Command.Spec in
  step (fun m v_opt ->
    match v_opt with
    | Some v -> m v
    | None ->
      printf "enter %s: %!" name;
      match In_channel.input_line stdin with
      | None -> failwith "no value entered. aborting."
      | Some line -> m (of_string line)
  )
  ++ flag ("-" ^ name) (optional (arg_type of_string)) ~doc

let fields_flag spec ~doc s field =
  let open Command.Spec in
  s ++ flag ("-" ^ Fieldslib.Field.name field) spec ~doc

(* END -- useful utilities *)

module Sing = struct
  module Note = struct
    type t = A | B | C | D | E | F | G with sexp
    let of_string x = t_of_sexp (Sexp.Atom x)
    let arg_type = Command.Spec.arg_type of_string
  end
  let command =
    Command.basic ~summary:"sing a song"
      Command.Spec.(
        (* flags *)
        step (fun k slow -> k ~slow)
        ++ flag "slow" ~aliases:["AA";"-BB"] no_arg ~doc:" sing slow"
        ++ flag "-loudness" (optional int)
          ~doc:"N how loud to sing (number of decibels)"
        ++ flag "-date" (optional date) ~doc:"DATE the date"
        ++ flag "-note" (listed Note.arg_type) ~doc:"NOTE a note"
        (* anonymous arguments *)
        ++ anon ("NAME" %: string)
        ++ anon ("FOO" %: string)
        ++ anon (sequence "BAR" string)
      )
      (fun ~slow loudness date notes song _ _ ->
        (* ... your code here... *)
        print_endline (if slow then "slow" else "fast");
        printf "loudness = %s\n"
          (Option.value ~default:"none"
            (Option.map ~f:Int.to_string loudness));
        printf "date = %s\n"
          (Option.value ~default:"no date"
            (Option.map date ~f:Date.to_string));
        printf "song name = %s\n" song;
        List.iter notes ~f:(fun note ->
          print_endline
            (Sexp.to_string_hum (
              Sexp.List [Sexp.Atom "note"; Note.sexp_of_t note])))
      )
end

let revision_flag () =
  let open Command.Spec in
  flag "-revision" ~doc:"REV revision number" (required string)

module Hg_log = struct
  let command =
    Command.basic ~summary:"show a point in hg history"
      Command.Spec.(
        revision_flag () ++
        flag "-print" no_arg ~doc:" display all changes (not just a summary)")
      (fun revision print ->
        (* ... your code here ... *)
        ignore (revision, print)
      )
end

module Hg_cat = struct
  let command =
    Command.basic ~summary:"cat a file from hg history"
      Command.Spec.(revision_flag () ++ anon ("FILE" %: string))
      (fun revision file ->
        (* ... your code here ... *)
        ignore (revision, file)
      )
end

module Cat = struct
  open Async.Std
  let command =
    Command.basic ~summary:"example async command: cat a file to stdout"
      Command.Spec.(anon ("FILE" %: string) ++ uses_async)
      (fun path ->
        Reader.with_file path ~f:(fun r ->
          Pipe.iter_without_pushback (Reader.pipe r) ~f:(fun chunk ->
            Writer.write (Lazy.force Writer.stdout) chunk))
        >>= fun _ ->
        return 0)
end

module Prompting = struct
  let command =
    Command.basic ~summary:"command demonstrting prompt-if-missing flags"
      Command.Spec.(
        (* flags *)
        flag "-rev" (required string) ~doc:" print stuff"
        ++ flag_prompt_if_missing "id" Fn.id ~doc:" whatever"
      )
      (fun revision id ->
        (* ... your code here ... *)
        print_endline "MAIN STARTED";
        printf "revision = %s\n%!" revision;
        printf "id = %s\n%!" id
      )
end

module Fields = struct

  type t = {
    foo : int;
    bar : string option;
    baz : float list;
  } with fields, sexp

  let main t =
    (* ... your code here ... *)
    print_endline (Sexp.to_string_hum (sexp_of_t t))

  let command =
    Command.basic ~summary:"example using fieldslib"
      Command.Spec.(
        Fields.fold
          ~init:(step Fn.id)
          ~foo:(fields_flag (required int)    ~doc:"N foo factor")
          ~bar:(fields_flag (optional string) ~doc:"B error bar (optional)")
          ~baz:(fields_flag (listed float)    ~doc:"X whatever (listed)"))
      (fun foo bar baz ->
        main {foo; bar; baz})

end

module Complex_anons = struct
  let command =
    Command.basic ~summary:"command with complex anonymous argument structure"
      Command.Spec.(
        anon ("A" %: string)
        ++ anon ("B" %: string)
        ++ anon (maybe (t3
            ("C" %: string)
            ("D" %: string)
            (maybe (t3
              ("E" %: string)
              ("F" %: string)
              (sequence "G" string)))))
      )
      (fun a b rest ->
        (* ... your code here... *)
        printf "A = %s\n" a;
        printf "B = %s\n" b;
        Option.iter rest ~f:(fun (c, d, rest) ->
          printf "C = %s\n" c;
          printf "D = %s\n" d;
          Option.iter rest ~f:(fun (e, f, gs) ->
            printf "E = %s\n" e;
            printf "F = %s\n" f;
            List.iter gs ~f:(fun g ->
              printf "G = %s\n" g;
            )
          )
        )
      )
end

module Goodies = struct
  let command =
    Command.basic ~summary:"demo of how to get various backdoor values"
      Command.Spec.(
        help
        ++ path ()
        ++ args
        ++ flag "t" (optional string) ~doc:""
        ++ flag "-fail" no_arg ~doc:" die, die, die!"
      )
      (fun help path args _ _ ->
        print_endline "PATH:";
        List.iter path ~f:(fun x -> print_endline ("  " ^ x));
        print_endline "ARGS:";
        List.iter args ~f:(fun x -> print_endline ("  " ^ x));
        print_endline "HELP!";
        print_endline (Lazy.force help)
      )
end

let command =
  Command.group ~summary:"fcommand examples"
  [
    ("sing", Sing.command);
    ("hg",
      Command.group ~summary:"commands sharing a flag specification" [
        ("log", Hg_log.command);
        ("cat", Hg_cat.command);
      ]);
    ("cat", Cat.command);
    ("prompting", Prompting.command);
    ("fields", Fields.command);
    ("complex-anons", Complex_anons.command);
    ("sub",
      Command.group ~summary:"a subcommand" [
        ("goodies", Goodies.command);
      ]);
  ]

let () = Command.run command

