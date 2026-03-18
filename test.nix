{
  vaultwarden = {
    deploy = {
        hostname = "root@192.168.1.1";
        secret = ../../age.key;
        keydir = ../hosts/name/secrets;
    };

    rebuild = [
      {
        hostname = "user@192.168.1.1";
        secret = ../../id_ed25519;
      }
    ];
  };
}
