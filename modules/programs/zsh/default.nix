{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    mkOrder
    optionalString
    types
    ;

  cfg = config.programs.zsh;

  relToDotDir = file: (optionalString (cfg.dotDir != null) (cfg.dotDir + "/")) + file;

  stateVersion = config.home.stateVersion;

  bindkeyCommands = {
    emacs = "bindkey -e";
    viins = "bindkey -v";
    vicmd = "bindkey -a";
  };
in
{
  imports = [
    ./prezto.nix
    ./zsh-abbr.nix
    (lib.mkRenamedOptionModule
      [ "programs" "zsh" "enableAutosuggestions" ]
      [ "programs" "zsh" "autosuggestion" "enable" ]
    )
    (lib.mkRenamedOptionModule
      [ "programs" "zsh" "enableSyntaxHighlighting" ]
      [ "programs" "zsh" "syntaxHighlighting" "enable" ]
    )
    (lib.mkRenamedOptionModule [ "programs" "zsh" "zproof" ] [ "programs" "zsh" "zprof" ])
  ];

  options =
    let
      historyModule = types.submodule (
        { config, ... }:
        {
          options = {
            append = mkOption {
              type = types.bool;
              default = false;
              description = ''
                If set, zsh sessions will append their history list to the history
                file, rather than replace it. Thus, multiple parallel zsh sessions
                will all have the new entries from their history lists added to the
                history file, in the order that they exit.

                This file will still be periodically re-written to trim it when the
                number of lines grows 20% beyond the value specified by
                `programs.zsh.history.save`.
              '';
            };

            size = mkOption {
              type = types.int;
              default = 10000;
              description = "Number of history lines to keep.";
            };

            save = mkOption {
              type = types.int;
              defaultText = 10000;
              default = config.size;
              description = "Number of history lines to save.";
            };

            path = mkOption {
              type = types.str;
              default =
                if lib.versionAtLeast stateVersion "20.03" then
                  "$HOME/.zsh_history"
                else
                  relToDotDir ".zsh_history";
              defaultText = literalExpression ''
                "$HOME/.zsh_history" if state version ≥ 20.03,
                "$ZDOTDIR/.zsh_history" otherwise
              '';
              example = literalExpression ''"''${config.xdg.dataHome}/zsh/zsh_history"'';
              description = "History file location";
            };

            ignorePatterns = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = literalExpression ''[ "rm *" "pkill *" ]'';
              description = ''
                Do not enter command lines into the history list
                if they match any one of the given shell patterns.
              '';
            };

            ignoreDups = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Do not enter command lines into the history list
                if they are duplicates of the previous event.
              '';
            };

            ignoreAllDups = mkOption {
              type = types.bool;
              default = false;
              description = ''
                If a new command line being added to the history list
                duplicates an older one, the older command is removed
                from the list (even if it is not the previous event).
              '';
            };

            saveNoDups = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Do not write duplicate entries into the history file.
              '';
            };

            findNoDups = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Do not display a line previously found in the history
                file.
              '';
            };

            ignoreSpace = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Do not enter command lines into the history list
                if the first character is a space.
              '';
            };

            expireDuplicatesFirst = mkOption {
              type = types.bool;
              default = false;
              description = "Expire duplicates first.";
            };

            extended = mkOption {
              type = types.bool;
              default = false;
              description = "Save timestamp into the history file.";
            };

            share = mkOption {
              type = types.bool;
              default = true;
              description = "Share command history between zsh sessions.";
            };
          };
        }
      );

      pluginModule = types.submodule (
        { config, ... }:
        {
          options = {
            src = mkOption {
              type = types.path;
              description = ''
                Path to the plugin folder.

                Will be added to {env}`fpath` and {env}`PATH`.
              '';
            };

            name = mkOption {
              type = types.str;
              description = ''
                The name of the plugin.
              '';
            };

            file = mkOption {
              type = types.str;
              description = ''
                The plugin script to source.
                Required if the script name does not match {file}`name.plugin.zsh`
                using the plugin {option}`name` from the plugin {option}`src`.
              '';
            };

            completions = mkOption {
              default = [ ];
              type = types.listOf types.str;
              description = "Paths of additional functions to add to {env}`fpath`.";
            };
          };

          config.file = lib.mkDefault "${config.name}.plugin.zsh";
        }
      );

      ohMyZshModule = types.submodule {
        options = {
          enable = mkEnableOption "oh-my-zsh";

          package = lib.mkPackageOption pkgs "oh-my-zsh" { };

          plugins = mkOption {
            default = [ ];
            example = [
              "git"
              "sudo"
            ];
            type = types.listOf types.str;
            description = ''
              List of oh-my-zsh plugins
            '';
          };

          custom = mkOption {
            default = "";
            type = types.str;
            example = "$HOME/my_customizations";
            description = ''
              Path to a custom oh-my-zsh package to override config of
              oh-my-zsh. See <https://github.com/robbyrussell/oh-my-zsh/wiki/Customization>
              for more information.
            '';
          };

          theme = mkOption {
            default = "";
            example = "robbyrussell";
            type = types.str;
            description = ''
              Name of the theme to be used by oh-my-zsh.
            '';
          };

          extraConfig = mkOption {
            default = "";
            example = ''
              zstyle :omz:plugins:ssh-agent identities id_rsa id_rsa2 id_github
            '';
            type = types.lines;
            description = ''
              Extra settings for plugins.
            '';
          };
        };
      };

      historySubstringSearchModule = types.submodule {
        options = {
          enable = mkEnableOption "history substring search";
          searchUpKey = mkOption {
            type = with types; either (listOf str) str;
            default = [ "^[[A" ];
            description = ''
              The key codes to be used when searching up.
              The default of `^[[A` may correspond to the UP key -- if not, try
              `$terminfo[kcuu1]`.
            '';
          };
          searchDownKey = mkOption {
            type = with types; either (listOf str) str;
            default = [ "^[[B" ];
            description = ''
              The key codes to be used when searching down.
              The default of `^[[B` may correspond to the DOWN key -- if not, try
              `$terminfo[kcud1]`.
            '';
          };
        };
      };

      syntaxHighlightingModule = types.submodule {
        options = {
          enable = mkEnableOption "zsh syntax highlighting";

          package = lib.mkPackageOption pkgs "zsh-syntax-highlighting" { };

          highlighters = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "brackets" ];
            description = ''
              Highlighters to enable
              See the list of highlighters: <https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md>
            '';
          };

          patterns = mkOption {
            type = types.attrsOf types.str;
            default = { };
            example = {
              "rm -rf *" = "fg=white,bold,bg=red";
            };
            description = ''
              Custom syntax highlighting for user-defined patterns.
              Reference: <https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/pattern.md>
            '';
          };

          styles = mkOption {
            type = types.attrsOf types.str;
            default = { };
            example = {
              comment = "fg=black,bold";
            };
            description = ''
              Custom styles for syntax highlighting.
              See each highlighter style option: <https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md>
            '';
          };
        };
      };
    in
    {
      programs.zsh = {
        enable = mkEnableOption "Z shell (Zsh)";

        package = lib.mkPackageOption pkgs "zsh" { };

        autocd = mkOption {
          default = null;
          description = ''
            Automatically enter into a directory if typed directly into shell.
          '';
          type = types.nullOr types.bool;
        };

        cdpath = mkOption {
          default = [ ];
          description = ''
            List of paths to autocomplete calls to {command}`cd`.
          '';
          type = types.listOf types.str;
        };

        dotDir = mkOption {
          default = null;
          example = ".config/zsh";
          description = ''
            Directory where the zsh configuration and more should be located,
            relative to the users home directory. The default is the home
            directory.
          '';
          type = types.nullOr types.str;
        };

        shellAliases = mkOption {
          default = { };
          example = literalExpression ''
            {
              ll = "ls -l";
              ".." = "cd ..";
            }
          '';
          description = ''
            An attribute set that maps aliases (the top level attribute names in
            this option) to command strings or directly to build outputs.
          '';
          type = types.attrsOf types.str;
        };

        shellGlobalAliases = mkOption {
          default = { };
          example = literalExpression ''
            {
              UUID = "$(uuidgen | tr -d \\n)";
              G = "| grep";
            }
          '';
          description = ''
            Similar to [](#opt-programs.zsh.shellAliases),
            but are substituted anywhere on a line.
          '';
          type = types.attrsOf types.str;
        };

        dirHashes = mkOption {
          default = { };
          example = literalExpression ''
            {
              docs  = "$HOME/Documents";
              vids  = "$HOME/Videos";
              dl    = "$HOME/Downloads";
            }
          '';
          description = ''
            An attribute set that adds to named directory hash table.
          '';
          type = types.attrsOf types.str;
        };

        enableCompletion = mkOption {
          default = true;
          description = ''
            Enable zsh completion. Don't forget to add
            ```nix
              environment.pathsToLink = [ "/share/zsh" ];
            ```
            to your system configuration to get completion for system packages (e.g. systemd).
          '';
          type = types.bool;
        };

        completionInit = mkOption {
          default = "autoload -U compinit && compinit";
          description = "Initialization commands to run when completion is enabled.";
          type = types.lines;
        };

        zprof.enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable zprof in your zshrc.
          '';
        };

        syntaxHighlighting = mkOption {
          type = syntaxHighlightingModule;
          default = { };
          description = "Options related to zsh-syntax-highlighting.";
        };

        historySubstringSearch = mkOption {
          type = historySubstringSearchModule;
          default = { };
          description = "Options related to zsh-history-substring-search.";
        };

        autosuggestion = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Enable zsh autosuggestions";
          };

          highlight = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "fg=#ff00ff,bg=cyan,bold,underline";
            description = ''
              Custom styles for autosuggestion highlighting. See
              {manpage}`zshzle(1)` for syntax.
            '';
          };

          strategy = mkOption {
            type = types.listOf (
              types.enum [
                "history"
                "completion"
                "match_prev_cmd"
              ]
            );
            default = [ "history" ];
            description = ''
              `ZSH_AUTOSUGGEST_STRATEGY` is an array that specifies how suggestions should be generated.
              The strategies in the array are tried successively until a suggestion is found.
              There are currently three built-in strategies to choose from:

              - `history`: Chooses the most recent match from history.
              - `completion`: Chooses a suggestion based on what tab-completion would suggest. (requires `zpty` module)
              - `match_prev_cmd`: Like `history`, but chooses the most recent match whose preceding history item matches
                  the most recently executed command. Note that this strategy won't work as expected with ZSH options that
                  don't preserve the history order such as `HIST_IGNORE_ALL_DUPS` or `HIST_EXPIRE_DUPS_FIRST`.

              Setting the option to an empty list `[]` will make ZSH_AUTOSUGGESTION_STRATEGY not be set automatically,
              allowing the variable to be declared in {option}`programs.zsh.localVariables` or {option}`programs.zsh.sessionVariables`
            '';
          };
        };

        history = mkOption {
          type = historyModule;
          default = { };
          description = "Options related to commands history configuration.";
        };

        defaultKeymap = mkOption {
          type = types.nullOr (types.enum (lib.attrNames bindkeyCommands));
          default = null;
          example = "emacs";
          description = "The default base keymap to use.";
        };

        sessionVariables = mkOption {
          default = { };
          type = types.attrs;
          example = {
            MAILCHECK = 30;
          };
          description = "Environment variables that will be set for zsh session.";
        };

        initContent = mkOption {
          default = "";
          type = types.lines;
          example = lib.literalExpression ''
            lib.mkOrder 1200 ''''
              echo "Hello zsh initContent!"
            '''';
          '';
          description = ''
            Content to be added to {file}`.zshrc`.

            To specify the order, use `lib.mkOrder`.

            Common order values:
            - 500 (mkBefore): Early initialization (replaces initExtraFirst)
            - 550: Before completion initialization (replaces initExtraBeforeCompInit)
            - 1000 (default): General configuration (replaces initExtra)
            - 1500 (mkAfter): Last to run configuration

            To specify both content in Early initialization and General configuration, use `lib.mkMerge`.

            e.g.

            initContent = let
                zshConfigEarlyInit = lib.mkOrder 500 "do something";
                zshConfig = lib.mkOrder 1000 "do something";
            in
                lib.mkMerge [ zshConfigEarlyInit zshConfig ];
          '';
        };

        initExtraBeforeCompInit = mkOption {
          default = "";
          type = types.lines;
          apply =
            x:
            lib.warnIfNot (x == "") ''
              `programs.zsh.initExtraBeforeCompInit` is deprecated, use `programs.zsh.initContent` with `lib.mkOrder 550` instead.

              Example: programs.zsh.initContent = lib.mkOrder 550 "your content here";
            '' x;
          visible = false;
          description = ''
            Extra commands that should be added to {file}`.zshrc` before compinit.
          '';
        };

        initExtra = mkOption {
          default = "";
          type = types.lines;
          visible = false;
          apply =
            x:
            lib.warnIfNot (x == "") ''
              `programs.zsh.initExtra` is deprecated, use `programs.zsh.initContent` instead.

              Example: programs.zsh.initContent = "your content here";
            '' x;
          description = ''
            Extra commands that should be added to {file}`.zshrc`.
          '';
        };

        initExtraFirst = mkOption {
          default = "";
          type = types.lines;
          visible = false;
          apply =
            x:
            lib.warnIfNot (x == "") ''
              `programs.zsh.initExtraFirst` is deprecated, use `programs.zsh.initContent` with `lib.mkBefore` instead.

              Example: programs.zsh.initContent = lib.mkBefore "your content here";
            '' x;
          description = ''
            Commands that should be added to top of {file}`.zshrc`.
          '';
        };

        envExtra = mkOption {
          default = "";
          type = types.lines;
          description = "Extra commands that should be added to {file}`.zshenv`.";
        };

        profileExtra = mkOption {
          default = "";
          type = types.lines;
          description = "Extra commands that should be added to {file}`.zprofile`.";
        };

        loginExtra = mkOption {
          default = "";
          type = types.lines;
          description = "Extra commands that should be added to {file}`.zlogin`.";
        };

        logoutExtra = mkOption {
          default = "";
          type = types.lines;
          description = "Extra commands that should be added to {file}`.zlogout`.";
        };

        plugins = mkOption {
          type = types.listOf pluginModule;
          default = [ ];
          example = literalExpression ''
            [
              {
                name = "enhancd";
                file = "init.sh";
                src = pkgs.fetchFromGitHub {
                  owner = "b4b4r07";
                  repo = "enhancd";
                  rev = "v2.2.1";
                  sha256 = "0iqa9j09fwm6nj5rpip87x3hnvbbz9w9ajgm6wkrd5fls8fn8i5g";
                };
              }
            {
              name = "wd";
              src = pkgs.zsh-wd;
              file = "share/wd/wd.plugin.zsh";
              completions = [ "share/zsh/site-functions" ];
            }
            ]
          '';
          description = "Plugins to source in {file}`.zshrc`.";
        };

        oh-my-zsh = mkOption {
          type = ohMyZshModule;
          default = { };
          description = "Options to configure oh-my-zsh.";
        };

        localVariables = mkOption {
          type = types.attrs;
          default = { };
          example = {
            POWERLEVEL9K_LEFT_PROMPT_ELEMENTS = [
              "dir"
              "vcs"
            ];
          };
          description = ''
            Extra local variables defined at the top of {file}`.zshrc`.
          '';
        };
      };
    };

  config =
    let
      pluginsDir = if cfg.dotDir != null then relToDotDir "plugins" else ".zsh/plugins";

      envVarsStr = config.lib.zsh.exportAll cfg.sessionVariables;
      localVarsStr = config.lib.zsh.defineAll cfg.localVariables;

      aliasesStr = concatStringsSep "\n" (
        lib.mapAttrsToList (
          k: v: "alias -- ${lib.escapeShellArg k}=${lib.escapeShellArg v}"
        ) cfg.shellAliases
      );

      dirHashesStr = concatStringsSep "\n" (
        lib.mapAttrsToList (k: v: ''hash -d ${k}="${v}"'') cfg.dirHashes
      );

      zdotdir = "$HOME/" + lib.escapeShellArg cfg.dotDir;
    in
    mkIf cfg.enable (
      lib.mkMerge [
        (mkIf (cfg.envExtra != "") {
          home.file."${relToDotDir ".zshenv"}".text = cfg.envExtra;
        })

        (mkIf (cfg.profileExtra != "") {
          home.file."${relToDotDir ".zprofile"}".text = cfg.profileExtra;
        })

        (mkIf (cfg.loginExtra != "") {
          home.file."${relToDotDir ".zlogin"}".text = cfg.loginExtra;
        })

        (mkIf (cfg.logoutExtra != "") {
          home.file."${relToDotDir ".zlogout"}".text = cfg.logoutExtra;
        })

        (mkIf cfg.oh-my-zsh.enable {
          home.file."${relToDotDir ".zshenv"}".text = ''
            ZSH="${cfg.oh-my-zsh.package}/share/oh-my-zsh";
            ZSH_CACHE_DIR="${config.xdg.cacheHome}/oh-my-zsh";
          '';
        })

        (mkIf (cfg.dotDir != null) {
          home.file."${relToDotDir ".zshenv"}".text = ''
            export ZDOTDIR=${zdotdir}
          '';

          # When dotDir is set, only use ~/.zshenv to source ZDOTDIR/.zshenv,
          # This is so that if ZDOTDIR happens to be
          # already set correctly (by e.g. spawning a zsh inside a zsh), all env
          # vars still get exported
          home.file.".zshenv".text = ''
            source ${zdotdir}/.zshenv
          '';
        })

        {
          home.file."${relToDotDir ".zshenv"}".text = ''
            # Environment variables
            . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"

            # Only source this once
            if [[ -z "$__HM_ZSH_SESS_VARS_SOURCED" ]]; then
              export __HM_ZSH_SESS_VARS_SOURCED=1
              ${envVarsStr}
            fi
          '';
        }

        {
          home.packages =
            [ cfg.package ]
            ++ lib.optional cfg.enableCompletion pkgs.nix-zsh-completions
            ++ lib.optional cfg.oh-my-zsh.enable cfg.oh-my-zsh.package;

          programs.zsh.initContent = lib.mkMerge [
            # zprof must be loaded before everything else, since it
            # benchmarks the shell initialization.
            (lib.mkIf cfg.zprof.enable (
              mkOrder 400 ''
                zmodload zsh/zprof
              ''
            ))

            (lib.mkIf (cfg.initExtraFirst != "") (lib.mkBefore cfg.initExtraFirst))

            (mkOrder 510 "typeset -U path cdpath fpath manpath")

            (lib.mkIf (cfg.cdpath != [ ]) (
              mkOrder 510 ''
                cdpath+=(${concatStringsSep " " cfg.cdpath})
              ''
            ))

            (mkOrder 520 ''
              for profile in ''${(z)NIX_PROFILES}; do
                fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
              done

              HELPDIR="${cfg.package}/share/zsh/$ZSH_VERSION/help"
            '')

            (lib.mkIf (cfg.defaultKeymap != null) (
              mkOrder 530 ''
                # Use ${cfg.defaultKeymap} keymap as the default.
                ${lib.getAttr cfg.defaultKeymap bindkeyCommands}
              ''
            ))

            (lib.mkIf (localVarsStr != "") (mkOrder 540 localVarsStr))

            (lib.mkIf (cfg.initExtraBeforeCompInit != "") (mkOrder 550 cfg.initExtraBeforeCompInit))

            (lib.mkIf (cfg.plugins != [ ]) (
              mkOrder 560 (
                lib.concatStrings (
                  map (plugin: ''
                    path+="$HOME/${pluginsDir}/${plugin.name}"
                    fpath+="$HOME/${pluginsDir}/${plugin.name}"
                    ${
                      (optionalString (plugin.completions != [ ]) ''
                        fpath+=(${
                          lib.concatMapStringsSep " " (
                            completion: "\"$HOME/${pluginsDir}/${plugin.name}/${completion}\""
                          ) plugin.completions
                        })
                      '')
                    }
                  '') cfg.plugins
                )
              )
            ))

            # NOTE: Oh-My-Zsh/Prezto calls compinit during initialization,
            # calling it twice causes slight start up slowdown
            # as all $fpath entries will be traversed again.
            (lib.mkIf (cfg.enableCompletion && !cfg.oh-my-zsh.enable && !cfg.prezto.enable) (
              mkOrder 570 cfg.completionInit
            ))

            (lib.mkIf cfg.autosuggestion.enable (
              mkOrder 700 ''
                source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
                ${
                  optionalString (cfg.autosuggestion.strategy != [ ]) ''
                    ZSH_AUTOSUGGEST_STRATEGY=(${concatStringsSep " " cfg.autosuggestion.strategy})
                  ''
                }${
                  optionalString (cfg.autosuggestion.highlight != null) ''
                    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="${cfg.autosuggestion.highlight}"
                  ''
                }
              ''
            ))

            (lib.mkIf cfg.oh-my-zsh.enable (
              mkOrder 800 ''
                # oh-my-zsh extra settings for plugins
                ${cfg.oh-my-zsh.extraConfig}
                # oh-my-zsh configuration generated by NixOS
                ${optionalString (
                  cfg.oh-my-zsh.plugins != [ ]
                ) "plugins=(${concatStringsSep " " cfg.oh-my-zsh.plugins})"}
                ${optionalString (cfg.oh-my-zsh.custom != "") ''ZSH_CUSTOM="${cfg.oh-my-zsh.custom}"''}
                ${optionalString (cfg.oh-my-zsh.theme != "") ''ZSH_THEME="${cfg.oh-my-zsh.theme}"''}
                source $ZSH/oh-my-zsh.sh
              ''
            ))

            (mkOrder 900 (
              (lib.concatStrings (
                map (plugin: ''
                  if [[ -f "$HOME/${pluginsDir}/${plugin.name}/${plugin.file}" ]]; then
                    source "$HOME/${pluginsDir}/${plugin.name}/${plugin.file}"
                  fi
                '') cfg.plugins
              ))
              + ''
                # History options should be set in .zshrc and after oh-my-zsh sourcing.
                # See https://github.com/nix-community/home-manager/issues/177.
                HISTSIZE="${toString cfg.history.size}"
                SAVEHIST="${toString cfg.history.save}"
                ${optionalString (
                  cfg.history.ignorePatterns != [ ]
                ) "HISTORY_IGNORE=${lib.escapeShellArg "(${lib.concatStringsSep "|" cfg.history.ignorePatterns})"}"}
                ${
                  if lib.versionAtLeast stateVersion "20.03" then
                    ''HISTFILE="${cfg.history.path}"''
                  else
                    ''HISTFILE="$HOME/${cfg.history.path}"''
                }
                mkdir -p "$(dirname "$HISTFILE")"

                setopt HIST_FCNTL_LOCK
                ${if cfg.history.append then "setopt" else "unsetopt"} APPEND_HISTORY
                ${if cfg.history.ignoreDups then "setopt" else "unsetopt"} HIST_IGNORE_DUPS
                ${if cfg.history.ignoreAllDups then "setopt" else "unsetopt"} HIST_IGNORE_ALL_DUPS
                ${if cfg.history.saveNoDups then "setopt" else "unsetopt"} HIST_SAVE_NO_DUPS
                ${if cfg.history.findNoDups then "setopt" else "unsetopt"} HIST_FIND_NO_DUPS
                ${if cfg.history.ignoreSpace then "setopt" else "unsetopt"} HIST_IGNORE_SPACE
                ${if cfg.history.expireDuplicatesFirst then "setopt" else "unsetopt"} HIST_EXPIRE_DUPS_FIRST
                ${if cfg.history.share then "setopt" else "unsetopt"} SHARE_HISTORY
                ${if cfg.history.extended then "setopt" else "unsetopt"} EXTENDED_HISTORY
                ${if cfg.autocd != null then "${if cfg.autocd then "setopt" else "unsetopt"} autocd" else ""}
              ''
            ))

            (lib.mkIf (cfg.initExtra != "") cfg.initExtra)

            (lib.mkIf (aliasesStr != "" || cfg.shellGlobalAliases != { }) (
              mkOrder 1100 (
                (optionalString (aliasesStr != "") aliasesStr)
                + (optionalString (cfg.shellGlobalAliases != { }) (
                  optionalString (cfg.shellAliases != { }) "\n"
                  + (concatStringsSep "\n" (
                    lib.mapAttrsToList (
                      k: v: "alias -g -- ${lib.escapeShellArg k}=${lib.escapeShellArg v}"
                    ) cfg.shellGlobalAliases
                  ))
                ))
              )
            ))

            (lib.mkIf (dirHashesStr != "") (
              mkOrder 1150 ''
                # Named Directory Hashes
                ${dirHashesStr}
              ''
            ))

            (lib.mkIf cfg.syntaxHighlighting.enable (
              mkOrder 1200
                # Load zsh-syntax-highlighting after all custom widgets have been created
                # https://github.com/zsh-users/zsh-syntax-highlighting#faq
                ''
                  source ${cfg.syntaxHighlighting.package}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
                  ZSH_HIGHLIGHT_HIGHLIGHTERS+=(${lib.concatStringsSep " " (map lib.escapeShellArg cfg.syntaxHighlighting.highlighters)})
                  ${lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (
                      name: value: "ZSH_HIGHLIGHT_STYLES[${lib.escapeShellArg name}]=${lib.escapeShellArg value}"
                    ) cfg.syntaxHighlighting.styles
                  )}
                  ${lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (
                      name: value: "ZSH_HIGHLIGHT_PATTERNS+=(${lib.escapeShellArg name} ${lib.escapeShellArg value})"
                    ) cfg.syntaxHighlighting.patterns
                  )}
                ''
            ))

            (lib.mkIf (cfg.historySubstringSearch.enable or false) (
              mkOrder 1250
                # Load zsh-history-substring-search after zsh-syntax-highlighting
                # https://github.com/zsh-users/zsh-history-substring-search#usage
                ''
                  source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
                  ${lib.concatMapStringsSep "\n" (upKey: ''bindkey "${upKey}" history-substring-search-up'') (
                    lib.toList cfg.historySubstringSearch.searchUpKey
                  )}
                  ${lib.concatMapStringsSep "\n" (downKey: ''bindkey "${downKey}" history-substring-search-down'') (
                    lib.toList cfg.historySubstringSearch.searchDownKey
                  )}
                ''
            ))

            (lib.mkIf cfg.zprof.enable (mkOrder 1450 "zprof"))
          ];

          home.file."${relToDotDir ".zshrc"}".text = cfg.initContent;
        }

        (mkIf cfg.oh-my-zsh.enable {
          # Make sure we create a cache directory since some plugins expect it to exist
          # See: https://github.com/nix-community/home-manager/issues/761
          home.file."${config.xdg.cacheHome}/oh-my-zsh/.keep".text = "";
        })

        (mkIf (cfg.plugins != [ ]) {
          # Many plugins require compinit to be called
          # but allow the user to opt out.
          programs.zsh.enableCompletion = lib.mkDefault true;

          home.file = lib.foldl' (a: b: a // b) { } (
            map (plugin: { "${pluginsDir}/${plugin.name}".source = plugin.src; }) cfg.plugins
          );
        })
      ]
    );
}
