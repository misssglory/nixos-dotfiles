{ ... }:

{
  services.screen-ocr-sender = {
    enable = true;

    user = "mg";

    configFile =
      "%h/.config/screen-ocr/config.sender.toml";

    #
    # screenshot-ocr устанавливаем
    # через Home Manager.
    #
    installScreenshotTool =
      false;
  };
}