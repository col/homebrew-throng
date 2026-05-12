class ThrongPre < Formula
  desc "Concurrent agentic coding platform (pre-release)"
  homepage "https://throng.dev"
  version "0.8.0-rc.7"

  depends_on "docker"
  depends_on "docker-compose"
  depends_on "gh"
  depends_on "git"
  depends_on "postgresql@16"
  depends_on "wireguard-tools"

  on_macos do
    on_arm do
      url "https://github.com/col/throng.dev/releases/download/throng-v#{version}/throng-v#{version}-darwin-arm64.tar.gz"
      sha256 "ef3c423d74712e81972d55e95eb911419a53a128f5a695b4d7d83d4f2e6aaaa2" # darwin-arm64
    end

    depends_on "colima"
  end

  on_linux do
    on_intel do
      url "https://github.com/col/throng.dev/releases/download/throng-v#{version}/throng-v#{version}-linux-amd64.tar.gz"
      sha256 "a78d939e8222f48928b9dfaf1896a278b3e90009dacb438742e8114cce7cbab1" # linux-amd64
    end
  end

  conflicts_with "throng", because: "both install a `throng` binary"

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
      *** PRE-RELEASE BUILD ***
      This is a pre-release version of Throng (alpha/beta/RC). It may contain bugs
      or breaking changes. For production use, install the stable formula instead:
        brew install col/throng/throng

      Config file: ~/.throng/config.toml  (created by `throng setup`)
      WireGuard:   ~/.throng/wireguard/throng.conf (managed by launchd watcher)
      Logs:        #{var}/log/throng/

      First-time setup:
        1. Run setup (starts Postgres, creates and migrates the DB, creates config files and installs WireGuard watcher):
             throng setup
        2. Start throng:
             brew services start throng-pre

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
