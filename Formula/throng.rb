require "json"

class Throng < Formula
  desc "Concurrent agentic coding platform orchestrating Claude Code sessions"
  homepage "https://throng.dev"
  version "0.7.20"
  sha256 "2e0c8dd5d7e2e6502a3c590cb8c98ca5bc08dec9443a093c56c1b659ed5d23f6"
  url "https://github.com/col/throng.dev/releases/download/throng-v#{version}/throng-v#{version}-darwin-arm64.tar.gz"

  depends_on arch: :arm64
  depends_on "colima"
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

    docker_dir = Pathname.new("#{Dir.home}/.docker")
    docker_dir.mkpath
    config_path = docker_dir/"config.json"
    plugin_dir = (HOMEBREW_PREFIX/"lib/docker/cli-plugins").to_s

    begin
      config = config_path.exist? ? JSON.parse(config_path.read) : {}
      extra_dirs = config["cliPluginsExtraDirs"]
      extra_dirs = [] unless extra_dirs.is_a?(Array)
      unless extra_dirs.include?(plugin_dir)
        config["cliPluginsExtraDirs"] = extra_dirs + [plugin_dir]
        config_path.atomic_write(JSON.pretty_generate(config))
      end
    rescue JSON::ParserError
      opoo "~/.docker/config.json is not valid JSON; skipping cliPluginsExtraDirs setup. " \
           "Add #{plugin_dir} to cliPluginsExtraDirs manually so `docker compose` works."
    end

    plist = "#{Dir.home}/Library/LaunchAgents/homebrew.mxcl.throng.plist"
    if File.exist?(plist)
      sleep(3000)
      system HOMEBREW_PREFIX/"bin/brew", "services", "restart", "throng"
    end
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
        1. Start the Docker runtime (Colima):
             colima start
           Or to start automatically on login:
             brew services start colima
        2. Run setup (starts Postgres, creates DB and config, migrates,
           installs WireGuard watcher):
             throng setup
        3. Start throng:
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
