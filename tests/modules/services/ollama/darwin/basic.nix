{
  services.ollama = {
    enable = true;
    host = "localhost";
    port = 11111;
    environmentVariables = {
      OLLAMA_LLM_LIBRARY = "cpu";
      HIP_VISIBLE_DEVICES = "0,1";
    };
  };

  nmt.script = ''
    serviceFile=LaunchAgents/org.nix-community.home.ollama.plist
    assertFileExists "$serviceFile"
    assertFileContent "$serviceFile" ${./expected-agent.plist}
  '';
}
