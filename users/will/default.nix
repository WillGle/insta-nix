{ config, ... }:
{
  users.users.${config.primaryUser.username} = {
    isNormalUser = true;
    description = config.primaryUser.username;
  };
}
