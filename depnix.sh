#!/usr/bin/env bash

# Normalize
set -euo pipefail
exe_root=$(pwd) # Where we are executing from
git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd) # where we will be for most things

show_help() {

  cat <<'EOF'
    Usage: depnix <nix-file> [subcommand] [-d] [-h] [-k] [-c]
      <nix-file> This is the config depnix will use

      subcommands:
        Init:      Create template config the name is whatever you set as a <nix_file>
        Validate:  Just check if the config file is valid
        Generate:  Create new ssh keys to bootstrap a server
        Rekey:     Decrypt and re-key the secrets/sshkeys
        Deploy:    Run nixos-anywhere and deploy the server, destroying any and all data there.
        Test:      Run nixos-rebuild test and rebuild the server
        Boot:      Run nixos-rebuild boot on the server
        Switch:    Run nixos-rebuild switch and rebuild the server
        Ssh:       Run arbitrary commands on remote servers

      options:
        -o            add arbitrary options to nixos-rebuild/nixos-anywhere
        -h            show this help dialog
        -c            define a command wrapped in "" for ssh mode
        -k            when re-keying ssh_host_keys with a new key you need to point to the old key for decryption
        -d            explain what we are going to do instead of doing it

      nix options:
        deploy:           List of attrsets that contain host information prior to deployment
          .flake:           Str of the flake nixosConfiguration that this will work with
          .hostname:        Str of ssh host: root@hostname
          .secret:          Path to the private age key for decrypting the keys on deployment
          .keydir:          Path to where we store the encrypted ssh keys
        rebuild:          List of attrsets that contain host information after deployment
          .flake:           Str of the flake nixosConfiguration that this will work with
          .hostname:        Str of ssh host: user@hostname
          .secret:          Path to the private ssh key for authenticating to the server

      Example below:
      {
        deploy = [ {
            flake = "webserver";
            hostname = "root@10.0.10.120";
            secret = ../../../../.ssh/age.key;
            keydir = ../hosts/webserver/secrets;
        } ];

        rebuild = [ {
            flake = "webserver";
            hostname = "user@10.0.10.120";
            secret = ../../../../.ssh/id_ed25519;
        } ];

      }
EOF
}

dryrun() {
  local action="$1"
  local flake="$2"
  local hostname="$3"
  local secret="$4"
  local key="$5"
  local oldkey="$6"
  case $action in
    "validate") validate ;;
    "ssh") drysshrun "$hostname" "$sshcmd" "$secret" ;;
    "generate") drygenerate_keys "$flake" "$hostname" "$secret" "$key" ;;
    "rekey") dryrekey_keys "$flake" "$secret" "$key" "$oldkey" ;;
    "deploy") drydeploy "$flake" "$hostname" "$secret" "$key" ;;
    "switch"|"test"|"boot") dryrebuild "$flake" "$hostname" "$action" ;;
  esac
}

validate() {
  nix eval --impure --expr "
    let
      data = import ${exe_root}/$nix_file;

      validateList = listName: list:
        if !builtins.isList list then
          throw \"Error: '\${listName}' is expected to be a list, but got \${builtins.typeOf list}\"
        else
          builtins.all (y:
            if !builtins.isAttrs y then
              throw \"Error in '\${listName}': Each item should be an attribute set, but got \${builtins.typeOf y}\"
            else if !builtins.isString (toString y.flake) then
              throw \"Error in '\${listName}': 'flake' should be a string, but got \${builtins.typeOf y.flake}\"
            else if !builtins.isString (toString y.hostname) then
              throw \"Error in '\${listName}': 'hostname' should be a string, but got \${builtins.typeOf y.hostname}\"
            else if !builtins.isPath y.secret then
              throw \"Error in '\${listName}': 'secret' should be a path, but got \${builtins.typeOf y.secret}\"
            else if listName == \"deploy\" && !builtins.isPath y.keydir then
              throw \"Error in '\${listName}': 'keydir' should be a path, but got \${builtins.typeOf y.keydir}\"
            else
              true
          ) list;

      isValid =
        if !builtins.isAttrs data then
          throw \"Error: Top-level data should be an attribute set, but got \${builtins.typeOf data}\"
        else
          (validateList \"rebuild\" data.rebuild) &&
          (validateList \"deploy\" data.deploy);
    in
      isValid"
}

init() {
  [[ ! -f "$exe_root/$nix_file" ]] || (read -p "This file exists do you want to overwrite it? (y/n): " reply && [[ $reply =~ ^[Yy]$ ]]) || exit 0
  cat <<EOF > $nix_file
  {
    deploy = [
      {
        flake = "name";
        hostname = "root@192.168.1.1";
        secret = ../../age.key;
        keydir = ../hosts/name/secrets;
      }
    ];

    rebuild = [
      {
        flake = "name";
        hostname = "user@192.168.1.1";
        secret = ../../id_ed25519;
      }
    ];
  }
EOF

  echo "Created $nix_file"
  exit 0
}
dryinit() {
  [[ ! -f "$exe_root/$nix_file" ]] || (read -p "This file exists do you want to overwrite it? (y/n): " reply && [[ $reply =~ ^[Yy]$ ]]) || exit 0
  cat <<EOF
  {
    deploy = [
      {
        flake = "name";
        hostname = "root@192.168.1.1";
        secret = ../../age.key;
        keydir = ../hosts/name/secrets;
      }
    ];

    rebuild = [
      {
        flake = "name";
        hostname = "user@192.168.1.1"; secret = ../../id_ed25519;
      }
    ];
  }
EOF

  echo "Created $nix_file"
  exit 0
}

generate_keys() {
  local flake="$1" # Needs to be in each function because we don't want to share a directory with multiple servers
  local hostname="$2"
  local secret="$3"
  local key="$4" # where the ssh_host_keys will go
  local temp=$(mktemp -d)
  local host="${hostname#*@}"
  public_key=$(age-keygen -y $secret)
  echo "Generating and encrypting SSH keys for $host..."

  install -d -m755 $temp/etc/ssh
  ssh-keygen -Af $temp
  echo "Generated keys ..."
  [ -d $key ] || mkdir -p $key
  tar -cz -C $temp etc | age -e -r $public_key > ${key}/${flake}_sshkeys.tgz.age

  echo "Keys encrypted and saved as ${key}/${flake}_sshkeys.tgz.age"
  echo ""
  echo "You can use these keys for decrypting secrets with agenix/sopsnix"
  echo "Use the host key to sign all secrets:"
  echo "$(cat $temp/etc/ssh/ssh_host_ed25519_key.pub)"
  echo ""
  echo "Cleaning $temp ..."
  rm -rf $temp
  echo "Done generating $flake keys"
}
drygenerate_keys() {
  local flake="$1" # Needs to be in each function because we don't want to share a directory with multiple servers
  local hostname="$2"
  local secret="$3"
  local key="$4" # where the ssh_host_keys will go
  local temp=$(echo "(mktemp -d)")
  local host="${hostname#*@}"
  public_key=$(echo "(age-keygen -y $secret)")
  echo "Generating and encrypting SSH keys for $host..."

  echo install -d -m755 $temp/etc/ssh
  echo ssh-keygen -Af $temp
  echo "Generated keys ..."
  echo "[ -d $key ] || mkdir -p $key"
  echo "tar -cz -C $temp etc | age -e -r $public_key > ${key}/${flake}_sshkeys.tgz.age"

  echo "Keys encrypted and saved as ${key}/${flake}_sshkeys.tgz.age"
  echo ""
  echo "You can use these keys for decrypting secrets with agenix/sopsnix"
  echo "Use the host key to sign all secrets:"
  echo "cat $temp/etc/ssh/ssh_host_ed25519_key.pub)"
  echo ""
  echo "Cleaning $temp ..."
  echo "rm -rf $temp"
  echo "Done generating $flake keys"
}

rekey_keys() {
  local flake="$1"
  local secret="$2"
  local key="$3" # where the ssh_host_keys will go
  local oldkey="$4" # -k defines the old key to re-key with
  local temp=$(mktemp -d)
  public_key=$(age-keygen -y $secret)
  echo "de-crypting SSH keys with old key for $hostname..."
  age -d -i $oldkey ${key}/${flake}_sshkeys.tgz.age | tar -xz -C "$temp"
  echo "re-encrypting SSH keys with new key for $hostname..."
  tar -cz -C $temp etc |age -e -r $public_key > ${key}/${flake}_sshkeys.tgz.age
  echo ""
  echo "Cleaning $temp ..."
  rm -rf $temp
  echo "Done rekeying $flake keys"
}
dryrekey_keys() {
  local flake="$1"
  local secret="$2"
  local key="$3" # where the ssh_host_keys will go
  local oldkey="$4" # -k defines the old key to re-key with
  local temp=$(echo "(mktemp -d)")
  public_key=$(echo "(age-keygen -y $secret)")
  echo "de-crypting SSH keys with old key for $hostname..."
  echo "age -d -i $oldkey ${key}/${flake}_sshkeys.tgz.age | tar -xz -C \"$temp\""
  echo "re-encrypting SSH keys with new key for $hostname..."
  echo "tar -cz -C $temp etc |age -e -r $public_key > ${key}/${flake}_sshkeys.tgz.age"
  echo ""
  echo "Cleaning $temp ..."
  echo "rm -rf $temp"
  echo "Done rekeying $flake keys"
}

deploy() {
  local flake="$1"
  local hostname="$2"
  local secret="$3"
  local key="$4" # where the ssh_host_keys are located
  local temp=$(mktemp -d)

  echo "Deploying $flake to $hostname..."
  mkdir -p "$temp"
  age -d -i $secret ${key}/${flake}_sshkeys.tgz.age | tar -xz -C "$temp"

  # Run nixos-anywhere
  nixos-anywhere ${options} -f .\#$flake --target-host $hostname --extra-files $temp
  echo "Cleaning $temp ..."
  rm -rf $temp
  echo "Finished deploying $flake"
}
drydeploy() {
  local flake="$1"
  local hostname="$2"
  local secret="$3"
  local key="$4" # where the ssh_host_keys are located
  local temp=$(echo "(mktemp -d)")

  echo "Deploying $flake to $hostname..."
  echo mkdir -p "$temp"
  echo "age -d -i $secret ${key}/${flake}_sshkeys.tgz.age | tar -xz -C \"$temp\""

  # Run nixos-anywhere
  echo nixos-anywhere ${options} -f .\#$flake --target-host $hostname --extra-files $temp
  echo "Cleaning $temp ..."
  echo rm -rf $temp
  echo "Finished deploying $flake"
}

sshrun() {
  local hostname="$1"
  local sshcmd="$2"
  local secret="$3"
  ssh $hostname -i $secret $sshcmd
}
drysshrun() {
  local hostname="$1"
  local sshcmd="$2"
  local secret="$3"
  echo "ssh $hostname -i $secret $sshcmd"
}

rebuild() {
  local flake="$1"
  local hostname="$2"
  local action="$3"
  local user="${hostname%@*}"
  if ! [ $user == "root" ]; then
      sudocmd=" --use-remote-sudo"
  else
      sudocmd=""
  fi
  echo "Rebuilding $flake to $hostname..."
  nixos-rebuild $action --flake .\#$flake ${options} --target-host $hostname $sudocmd
}
dryrebuild() {
  local flake="$1"
  local hostname="$2"
  local action="$3"
  local user="${hostname%@*}"
  if ! [ $user == "root" ]; then
      sudocmd=" --use-remote-sudo"
  else
      sudocmd=""
  fi
  echo "Rebuilding $flake to $hostname..."
  echo nixos-rebuild $action --flake .\#$flake ${options} --target-host $hostname $sudocmd
}

main() {
  for arg in "$@"; do
    if [[ "$arg" == "-h" ]]; then
      show_help && exit 0
    fi
  done

  if [[ "$#" -lt 2 ]]; then
      echo "There is not enough arguments. Use -h to read help" && exit 1
  fi

  nix_file="$1"
  action="$2"
  dry=0
  key=0
  oldkey=0
  jsonroot=0
  sshcmd=0
  options=""
  shift 2

  # sanity
  [[ -f "$exe_root/$nix_file" || $action == "init" ]] || (echo "File: $nix_file doesn't exist" && echo "" && show_help && exit 1)
  [[ $action == "init" ]] || [[ $(validate) ]] || exit 1

  while getopts ":hdo:k:c:" opt; do
    case $opt in
      h) show_help && exit 0 ;;
      d) original_action=$action && action="dryrun" ;;
      o) options="$OPTARG" ;;
      k) oldkey="$OPTARG" ;;
      c) sshcmd="$OPTARG" ;;
      :) show_help && exit 1 ;;
      \?) show_help && exit 1 ;;
    esac
  done

  [[ $action == "ssh" && $sshcmd == 0 ]] && (echo "No command given for ssh mode" && exit 1)

  case $action in
    "init") init ;;
    "validate") echo "Successful Validation" && exit 0 ;;
    "dryrun") [[ $original_action == "init" ]] && dryinit || [[ "$original_action" =~ ^(generate|rekey|deploy)$ ]] && jsonroot="deploy" || jsonroot="rebuild" ;;
    "generate"|"rekey"|"deploy") jsonroot="deploy" ;;
    "switch"|"test"|"boot"|"ssh") jsonroot="rebuild" ;;
    *) echo "Invalid action: $action" && echo "" && show_help && exit 1 ;;
  esac

  server_configs=$(nix eval --file $nix_file --json|jq .$jsonroot)
  echo "$server_configs" | jq -c '.[]' | while read -r jsonroot; do

    flake=$(echo "$jsonroot" | jq -r '.flake')
    hostname=$(echo "$jsonroot" | jq -r '.hostname')
    secret=$(echo "$jsonroot" | jq -r '.secret')
    key=$(echo "$jsonroot" | jq -r '.keydir')

    echo "performing $action on $flake ==================================="
    case $action in
      "validate") validate;;
      "ssh") sshrun "$hostname" "$sshcmd" "$secret" ;;
      "dryrun") dryrun "$original_action" "$flake" "$hostname" "$secret" "$key" "$oldkey" ;;
      "generate") generate_keys "$flake" "$hostname" "$secret" "$key" ;;
      "rekey") rekey_keys "$flake" "$secret" "$key" "$oldkey" ;;
      "deploy") deploy "$flake" "$hostname" "$secret" "$key" ;;
      "switch"|"test"|"boot") rebuild "$flake" "$hostname" "$action" ;;
      *) echo "Invalid action: $action" && echo "" && show_help && exit 1 ;;
    esac
    echo ""
    echo "================================================================"

  done
}

main "$@"
