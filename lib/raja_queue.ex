defmodule RajaQueue do
  use Application

  alias RajaQueue.TwitchAPI
  alias RajaQueue.QueueState
  alias RajaQueue.Bot

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    bot = Application.get_env(:raja_queue, :bot)

    bot_name = String.to_atom(bot.nick)

    children = [
      {QueueState, name: QueueState, state_file: Application.get_env(:raja_queue, :state_file)},
      # {TwitchAPI, [[{:bot_nick, bot_name} | Application.get_env(:raja_queue, TwitchAPI)], [name: TwitchAPI]]},
      %{id: bot_name, start: {Bot, :start_link, [bot, [name: bot_name]]}}
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RajaQueue.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
