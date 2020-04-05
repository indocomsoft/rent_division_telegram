defmodule RentDivisionTelegram.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      ExGram,
      RentDivisionTelegram.Database,
      {RentDivisionTelegram.Bot,
       [method: :polling, token: Application.get_env(:rent_division_telegram, :token)]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RentDivisionTelegram.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
