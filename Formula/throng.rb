class Throng < Formula
  desc "Concurrent agentic coding platform orchestrating Claude Code sessions"
  homepage "https://throng.dev"
  version "0.4.1"
  sha256 "f5e8c84aec1014912633f8bde5d639711e6c0850dc697d7cbfeadeb02944aabc"
  url "https://github.com/col/throng.dev/releases/download/throng-v#{version}/throng-v#{version}-darwin-arm64.tar.gz"

  depends_on arch: :arm64
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
  end

  service do
    run [opt_bin/"throng", "start"]
    keep_alive true
    working_dir var/"throng"
    log_path var/"log/throng/throng.log"
    error_log_path var/"log/throng/throng.error.log"
    environment_variables PHX_SERVER: "true"
  end

  def caveats
    <<~EOS
      Config file: ~/.throng/config.toml  (created by `throng setup`)
      WireGuard:   ~/.throng/throng.conf (managed by launchd watcher)
      Logs:        #{var}/log/throng/

      First-time setup:
        1. Run setup (starts Postgres, creates DB and config, migrates,
           installs WireGuard watcher):
             throng setup
        2. Start throng:
             brew services start throng

      Then open http://localhost:4000

      The WireGuard tunnel is managed automatically via a launchd watcher.
      When Throng connects to a Hub, the tunnel config is written and the
      watcher brings the interface up automatically.
    EOS
  end

  test do
    assert_match "throng", shell_output("#{bin}/throng --help 2>&1", 1)
  end
end
