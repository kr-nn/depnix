    {
      flakename = {
        deploy = {
          username = "root";
          host = "10.0.10.120";
          secret = /home/kyle/.ssh/id_ed25519;
          keydir = ./hosts/hostname/secrets;
        };
        rebuild = {
          username = "user";
          host = "10.0.10.120";
          secret = /home/kyle/.ssh/id_ed25519;
        };
      };

      newflake = {
        deploy = {
          username = "root";
          host = "10.0.10.120";
          secret = /home/kyle/.ssh/id_ed25519;
          keydir = ./hosts/hostname/secrets;
        };
        rebuild = {
          username = "kyle";
          host = "10.0.10.120";
          secret = /home/kyle/.ssh/id_ed25519;
        };
      };
    }
