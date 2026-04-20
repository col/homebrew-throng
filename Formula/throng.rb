class Throng < Formula
  desc "Concurrent agentic coding platform orchestrating Claude Code sessions"
  homepage "https://throng.dev"
  version "0.2.2"

  url "https://github.com/col/throng/releases/download/v#{version}/throng-v#{version}-darwin-arm64.tar.gz"
  sha256 "sha256:e38aa7f6e33b2abf8684f2e7c0c7fc5818ae0e2dbd6fed3fab71b64cb3b98376"

  depends_on "postgresql@16"
  depends_on "git"
  depends_on :macos
  depends_on arch: :arm64

  def install
    libexec.install Dir["*"]

    (bin/"throng").write <<~SH
      #!/bin/bash
      set -e
      export THRONG_DATA_DIR="${THRONG_DATA_DIR:-#{var}/throng}"
      export DATABASE_URL="${DATABASE_URL:-ecto://${USER}@localhost/throng_prod}"
      export PHX_HOST="${PHX_HOST:-localhost}"
      export PORT="${PORT:-4000}"
      if [ -f "#{etc}/throng/throng.env" ]; then
        set -a
        . "#{etc}/throng/throng.env"
        set +a
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
    (etc/"throng").mkpath

    env_file = etc/"throng/throng.env"
    return if env_file.exist?

    secret = Utils.safe_popen_read(
      libexec/"bin/throng",
      "eval",
      "IO.write(:crypto.strong_rand_bytes(64) |> Base.encode64(padding: false))",
    ).strip

    env_file.write <<~ENV
      # Throng runtime configuration. Uncomment and adjust as needed.
      SECRET_KEY_BASE=#{secret}
      # DATABASE_URL=ecto://user@localhost/throng_prod
      # PHX_HOST=localhost
      # PORT=4000
      # PUBLIC_DOMAIN=
      # GITHUB_TOKEN=
    ENV
    env_file.chmod 0600
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
      Config file: #{etc}/throng/throng.env
      Data dir:    #{var}/throng
      Logs:        #{var}/log/throng/

      First-time setup:
        1. Start PostgreSQL:    brew services start postgresql@16
        2. Create the database: createdb throng_prod
        3. Run migrations:      throng-migrate
        4. Start throng:        brew services start throng

      Then open http://localhost:4000

      To customise (database URL, host, port, tokens), edit:
        #{etc}/throng/throng.env
    EOS
  end

  test do
    assert_match "throng", shell_output("#{bin}/throng --help 2>&1", 1)
  end
end
