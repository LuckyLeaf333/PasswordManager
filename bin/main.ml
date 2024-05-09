open FinalProject

let login_procedure pwd =
  if FinalProject.MasterPassword.check_master pwd then
    let () = Encrypt.set_key pwd in
    true
  else false

let quit_procedure () =
  print_endline "Exited the program";
  exit 0

let help_msg =
  "Here are the available commands:\n\n\
   add: Add a new password.\n\
   list: List saved passwords.\n\
   findsing: Autocompletes given name and lists relevant password or login \
   information \n\
   check_strength: Checks if your password is at risk or not.\n\
   health_check: Checks saved passwords for health or duplicates \n\
   gen_password: Generates password with choice\n\
   setpwd: Change the master password.\n\
   import: Import passwords from an existing file.\n\
   export: Export passwords form an existing file. Warning: Exporting \
   passwords will export decrypted data to a file.\n\
   quit: Quit the program."

let get_hidden_input () =
  let settings = Unix.tcgetattr Unix.stdin in
  settings.c_echo <- false;
  Unix.tcsetattr Unix.stdin Unix.TCSANOW settings;
  let input = read_line () in
  settings.c_echo <- true;
  Unix.tcsetattr Unix.stdin Unix.TCSANOW settings;
  input

let help_procedure () = print_endline help_msg

let list_procedure () =
  let pwd_list = Persistence.read_all_encryptable () in
  List.iter (fun x -> print_endline (Types.string_of_encryptable x)) pwd_list

let findsing_procedure () =
  print_endline "Enter what you think the name of your password or login is";
  let desired = read_line () in
  let autocomplete : Types.encryptable list =
    Autocomplete.autocomplete desired
  in
  if List.length autocomplete = 0 then print_endline "No matches"
  else
    List.iter
      (fun x -> print_endline (Types.string_of_encryptable x))
      autocomplete

let gen_password_procedure () = print_endline (Gen_password.gen_password_val ())

let add_procedure () =
  print_endline
    "Usage: add [pwd|login].\n\
     Run add pwd if you would like to\n\
     add a password, and add login if you would like to add a login"

let add_password_procedure () =
  print_endline "What would you like to name this password?";
  let name = read_line () in
  print_endline "Enter the password:";
  let password = get_hidden_input () in
  let encryptable = Types.Password { name; password } in
  Persistence.write_encryptable encryptable

let add_login_procedure () =
  print_endline "What would you like to name this login?";
  let name = read_line () in
  print_endline "Enter the username:";
  let username = read_line () in
  print_endline "Enter the password:";
  let password = get_hidden_input () in
  print_endline "Enter the url, or press enter to skip:";
  let url = get_hidden_input () |> Util.non_empty_or_none in
  let encryptable = Types.Login { name; username; password; url } in
  Persistence.write_encryptable encryptable

let set_pwd_procedure () =
  print_endline "Type a new password: ";
  let newpwd = get_hidden_input () in
  (* Salt & Hash -> Convert ot MasterPasswordHash type*)
  let master_pwd = Encrypt.salt_hash newpwd in

  let () = Persistence.write_unencryptable master_pwd in
  print_endline ("The password input was :" ^ newpwd)

let check_strength_procedure () =
  print_endline "Enter your existing password.";
  let existing = read_line () in
  if Autocomplete.check_strength existing then
    print_endline
      "Your password is a security risk -- try one of our randomly generated \
       passwords by calling gen_password"
  else print_endline "Your password is fine!"

let health_check_procedure () =
  let check_vulnerabilities () =
    let pwd_list = Persistence.read_all_encryptable () in

    let get_only_passwords (pwd : Types.encryptable) =
      match pwd with
      | Types.Login l -> Types.string_of_master_password_hash l.password
      | Types.Password p -> Types.string_of_master_password_hash p.password
    in
    let get_only_names (pwd : Types.encryptable) : string =
      match pwd with
      | Types.Login l -> Types.string_of_master_password_hash l.name
      | Types.Password p -> Types.string_of_master_password_hash p.name
    in
    let string_pwd_list = List.map get_only_passwords pwd_list in
    let len = List.length string_pwd_list in
    let vulnerable = ref [] in

    (* we just want to modify this one ref rather than return a new list for
       each iteration of the loop*)
    for i = 0 to len - 1 do
      let password_entry = List.nth string_pwd_list i in
      if Autocomplete.check_strength password_entry then
        vulnerable := get_only_names (List.nth pwd_list i) :: !vulnerable
    done;
    !vulnerable
  in
  let output_lst = check_vulnerabilities () in
  let output_printer str =
    Printf.printf "Your password or login %s is not secure\n" str;
    ()
  in
  List.iter output_printer output_lst

let export_procedure () =
  print_endline "Type the path to which you would like to export: ";
  let path = read_line () in
  let secrets = Persistence.read_all_encryptable () in
  PasswordImport.export secrets path;
  Printf.printf "Passwords successfully exported to %s\n%!" path

let import_procedure () =
  print_endline "Type the path to the passwords you would like to import: ";
  let path = read_line () in
  let new_secrets = PasswordImport.import path in
  new_secrets |> List.iter Persistence.write_encryptable;
  Printf.printf "Passwords successfully imported from %s\n%!" path

let logged_in_loop () =
  PromptCommands.prompt_commands
    [
      ("quit", quit_procedure);
      ("help", help_procedure);
      ("list", list_procedure);
      ("findsing", findsing_procedure);
      ("gen_password", gen_password_procedure);
      ("add", add_procedure);
      ("add pwd", add_password_procedure);
      ("add login", add_login_procedure);
      ("setpwd", set_pwd_procedure);
      ("check_strength", check_strength_procedure);
      ("health_check", health_check_procedure);
      ("export", export_procedure);
      ("import", import_procedure);
    ]
    ~on_timeout:quit_procedure

let rec main_loop () =
  Persistence.set_file_perms ();
  print_endline "Type a command -- quit, help, or login:";
  let input = read_line () in
  match input with
  | "quit" -> quit_procedure ()
  | "help" ->
      print_endline "Must login before accessing other functionalities";
      main_loop ()
  | "login" -> begin
      print_endline "Type your master password:";
      let pwd = get_hidden_input () in
      if login_procedure pwd then begin
        print_endline "Logged in!";
        logged_in_loop ()
      end
      else
        let () = print_endline "The password does not match" in
        main_loop ()
    end
  | x -> begin
      if
        x = "add"
        || x = "list"
        || x = "findsing"
        || x = "gen_password"
        || x = "setpwd"
        || x = "import"
        || x = "export"
        || x = "check_strength"
        || x = "health_check"
      then
        let () =
          print_endline
            "Must log in before using these commands -- try 'login' to log in \
             or 'help'"
        in
        main_loop ()
      else print_endline "That is not a valid command.";
      main_loop ()
    end

let _ = main_loop ()
