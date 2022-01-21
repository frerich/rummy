defmodule Rummy.MixProject do
  use Mix.Project

  def project do
    [
      app: :rummy,
      version: System.get_env("GIT_VERSION") || git_describe(),
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Massage 'git describe' output into SemVer compatible format.
  #
  # If there's a tag pointing at HEAD, the returned version is in the format
  # "<tag>+<sha>", e.g. "0.4.2+72c26ac". Otherwise, the most recent tag on the
  # branch is chosen and a "-dev" suffix is appended, e.g. "0.4.2-dev+72c26ac".
  #
  # If there are no tags for any commits on the branch, a dummy version and the
  # SHA of HEAD is returned, e.g. "0.1.0-dev+72c26ac".
  #
  def git_describe() do
    {output, 0} = System.cmd("git", ["describe", "--tags", "--long", "--always", "HEAD"])

    case Regex.run(~r{(.+)-(\d+)-g([0-9a-f]+)\n}, output) do
      [_, tag, "0", sha] -> "#{tag}+#{sha}"
      [_, tag, _n, sha] -> "#{tag}-dev+#{sha}"
      nil -> "0.1.0-dev+#{String.trim_trailing(output)}"
    end
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Rummy.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.0-rc.0", override: true},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_view, "~> 0.17.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:floki, ">= 0.27.0", only: :test},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 0.5"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:credo, "~> 1.5.6", only: [:dev, :test], runtime: false},
      {:esbuild, "~> 0.2", runtime: Mix.env() == :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "cmd npm install --prefix assets"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"],
      deploy: &deploy_to_gigalixir/1
    ]
  end

  defp deploy_to_gigalixir(_args) do
    System.cmd("gigalixir", ["config:set", "GIT_VERSION=#{project()[:version]}"])
    System.cmd("git", ["push", "-f", "gigalixir", "HEAD"])
  end
end
