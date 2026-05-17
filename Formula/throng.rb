class Throng < Formula
  desc "Concurrent agentic coding platform orchestrating Claude Code sessions"
  homepage "https://throng.dev"
  version "0.8.2"

  depends_on "docker"
  depends_on "docker-compose"
  depends_on "gh"
  depends_on "git"
  depends_on "postgresql@16"
  depends_on "wireguard-tools"

  on_macos do
    on_arm do
      url "https://github.com/col/throng.dev/releases/download/throng-v#{version}/throng-v#{version}-darwin-arm64.tar.gz"
      sha256 "01d5ebd584c07fd0633b32cccd085eae14d5aa178546a27142448b72fb981148" # darwin-arm64
    end

    depends_on "colima"
  end

  on_linux do
    on_intel do
      url "https://github.com/col/throng.dev/releases/download/throng-v#{version}/throng-v#{version}-linux-amd64.tar.gz"
      sha256 "bb2b850a3dde27d51f9d8e0f02cca6d057d73758ac2d0bf4ff02be64fc31424a" # linux-amd64
    end
  end

  def install
    libexec.install Dir["*"]

    (bin/"throng").write <<~SH
      #!/bin/bash
      set -e
      export THRONG_HOME="${THRONG_HOME:-$HOME/.throng}"
      case "$1" in
        setup)    shift; exec "#{libexec}/bin/brew-setup" "$@" ;;
        migrate)  shift; exec "#{libexec}/bin/migrate"    "$@" ;;
        rollback) shift; exec "#{libexec}/bin/rollback"   "$@" ;;
        seed)     shift; exec "#{libexec}/bin/seed"       "$@" ;;
        server)   shift; exec "#{libexec}/bin/server"     "$@" ;;
        *)        exec "#{libexec}/bin/throng" "$@" ;;
      esac
    SH
    chmod 0755, bin/"throng"
  end

  def post_install
    (var/"throng").mkpath
    (var/"log/throng").mkpath
  end

  service do
    run [opt_libexec/"bin/migrate_and_server"]
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
        1. Run setup (starts Postgres, creates and migrates the DB, creates config files and installs WireGuard watcher):
             throng setup
        2. Start throng:
             brew services start throng

      Then open http://localhost:7654 or https://<instance-name>.hub.throng.dev (once registered)

      The WireGuard tunnel is managed automatically via a launchd watcher.
      When Throng connects to a Hub, the tunnel config is written and the
      watcher brings the interface up automatically.
    EOS
  end

  test do
    assert_match "throng", shell_output("#{bin}/throng --help 2>&1", 1)
  end
end
