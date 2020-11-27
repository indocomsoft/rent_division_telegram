import Config

token = System.get_env("TOKEN")

case token do
  nil ->
    import_config "secrets.exs"

  x when is_binary(x) ->
    config :rent_division_telegram, token: token

    base_url =
      System.get_env("BASE_URL") ||
        raise """
        environment variable BASE_URL is missing.
        """

    config :rent_division_telegram, base_url: base_url
end
