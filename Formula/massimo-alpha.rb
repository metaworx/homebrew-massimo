# The Homebrew formula of Massimo for the update channel alpha, rendered
# from packaging/homebrew/massimo.rb.in by packaging/homebrew/render.sh at
# each release and pushed to the tap metaworx/homebrew-massimo
# (packaging/README.md, "Homebrew"). Built from source on the Mac, so
# nothing needs notarization and nothing is quarantined; brew then owns
# the binary, which the marker under share/massimo tells massimo.
class MassimoAlpha < Formula
  desc "Server for eQ-3 MAX! Cube heating systems: API, web UI, the Cube proxy"
  homepage "https://github.com/metaworx/massimo"
  url "https://github.com/metaworx/massimo/archive/refs/tags/v0.12.0-alpha.1.tar.gz"
  sha256 "aa2e111afd811694e2d1dba7cffd0cd016a96ab9d721ee4df74fa2c828d3bfad"
  version "0.12.0-alpha.1"
  license "AGPL-3.0-or-later"
  head "https://github.com/metaworx/massimo.git", branch: "main"

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(output: bin/"massimo", ldflags: "-s -w -X main.version=v#{version} -X main.channel=alpha"), "./cmd/massimo"
    # The marker internal/install.Packaged reads: brew owns this binary, so
    # massimo update and the web UI leave the install to it.
    (share/"massimo").mkpath
    (share/"massimo"/"packaged").write "brew\nbrew upgrade massimo-alpha\nbrew uninstall massimo-alpha\n"
    template = (buildpath/"packaging/env.template").read
    template = template.sub("MASSIMO_LOG=/var/log/massimo/serve.log",
                            "# The log is #{var}/log/massimo.log, written by brew services; no MASSIMO_LOG here.")
    (share/"massimo"/"env.template").write template
  end

  # Declarative, as brew asks of every tap (post_install is deprecated):
  # the directories, and the settings file once from the template, which
  # brew keeps from then on.
  post_install_steps do
    mkdir_p "massimo", base: :etc
    mkdir_p "massimo", base: :var
    mkdir_p "log", base: :var
    unless_path_exists "massimo/env", base: :etc do
      copy "share/massimo/env.template", "massimo/env", source_base: :prefix, target_base: :etc
      set_permissions "massimo/env", "0600", base: :etc
    end
  end

  service do
    run [opt_bin/"massimo", "-env", etc/"massimo/env", "-data", var/"massimo", "serve", "-listen", ":8099"]
    keep_alive true
    working_dir var/"massimo"
    log_path var/"log/massimo.log"
    error_log_path var/"log/massimo.log"
  end

  def caveats
    <<~EOS
      Put the Cubes' addresses and MASSIMO_API_TOKEN into
        #{etc}/massimo/env
      (README.md, "Cube variables"), then run massimo serve as yourself while
      you are logged in with
        brew services start massimo-alpha
      or as a daemon at boot with
        sudo brew services start massimo-alpha
      The web UI is then at http://localhost:8099/. Updates come through
      brew upgrade; massimo update leaves them to it. Do not mix this with
      massimo install, which sets up a Mac without Homebrew.
    EOS
  end

  test do
    port = free_port
    pid = spawn bin/"massimo", "serve", "-listen", "127.0.0.1:#{port}", "-proxy", "off"
    sleep 3
    begin
      assert_match "\"ok\": true", shell_output("curl -s http://127.0.0.1:#{port}/healthz")
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
