class Throng < Formula
  desc "Concurrent agentic coding platform orchestrating Claude Code sessions"
  homepage "https://throng.dev"
  version "0.7.14"
  sha256 "b995617303de4d72902f379ea04dcd75362449a79702ea7d02dfa0d23586c1c3"
  url "https://github.com/col/throng.dev/releases/download/throng-v#{version}/throng-v#{version}-darwin-arm64.tar.gz"

  depends_on arch: :arm64
  depends_on "docker"
  depends_on "docker-compose"
  depends_on "gh"
  depends_on "git"
  depends_on :macos
  depends_on "postgresql@16"
  depends_on "wireguard-tools"

  def install
    libexec.install Dir["*"]

    (bin/"throng").write <<~SH
      #!/bin/bash
      set -e
      if [ "$1" = "setup" ]; then
        shift
        exec "#{libexec}/bin/brew-setup" "$@"
      fi
      exec "#{libexec}/bin/throng" "$@"
    SH
    chmod 0755, bin/"throng"

    (bin/"throng-migrate").write <<~SH
      #!/bin/bash
      exec "#{bin}/throng" eval "Throng.Release.migrate"
    SH
    chmod 0755, bin/"throng-migrate"
  end

  def post_install
    (var/"throng").mkpath
    (var/"log/throng").mkpath

    plist = "#{Dir.home}/Library/LaunchAgents/homebrew.mxcl.throng.plist"
    if File.exist?(plist)
      system HOMEBREW_PREFIX/"bin/brew", "services", "restart", "throng"
    end
  end

  service do
    run [opt_bin/"throng", "start"]
    keep_alive true
    working_dir var/"throng"
    log_path var/"log/throng/throng.log"
    error_log_path var/"log/throng/throng.error.log"
    environment_variables PHX_SERVER: "true",
                          THRONG_HOME: "#{Dir.home}/.throng",
                          PATH: "#{HOMEBREW_PREFIX}/bin:#{HOMEBREW_PREFIX}/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
  end

  def caveats
    <<~EOS
      Config file: ~/.throng/config.toml  (created by `throng setup`)
      WireGuard:   ~/.throng/wireguard/throng.conf (managed by launchd watcher)
      Logs:        #{var}/log/throng/

      First-time setup:
        1. Run setup (starts Postgres, creates DB and config, migrates,
           installs WireGuard watcher):
             throng setup
        2. Start throng:
             brew services start throng

      Then open http://localhost:7654

      The WireGuard tunnel is managed automatically via a launchd watcher.
      When Throng connects to a Hub, the tunnel config is written and the
      watcher brings the interface up automatically.
    EOS
  end

  test do
    assert_match "throng", shell_output("#{bin}/throng --help 2>&1", 1)
  end
end
