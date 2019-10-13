defmodule RajaQueue do
  use Application

  alias RajaQueue.QueueState
  alias RajaQueue.Bot

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      {QueueState, name: QueueState, state_file: Application.get_env(:raja_queue, :state_file)}
      | Application.get_env(:raja_queue, :bots)
        |> Enum.map(fn bot -> worker(Bot, [bot]) end)
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RajaQueue.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
