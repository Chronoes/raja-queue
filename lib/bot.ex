defmodule RajaQueue.Bot do
  use GenServer
  require Logger

  alias ExIRC.Client
  alias ExIRC.SenderInfo

  alias RajaQueue.TwitchAPI

  defmodule Config do
    defstruct server: nil,
              port: nil,
              pass: nil,
              nick: nil,
              user: nil,
              name: nil,
              channel: nil,
              client: nil

    @type t :: %__MODULE__{
            server: String.t() | nil,
            port: pos_integer() | nil,
            pass: String.t() | nil,
            nick: String.t() | nil,
            user: String.t() | nil,
            name: String.t() | nil,
            channel: String.t() | nil,
            client: Client.t() | nil
          }

    @spec from_params(map :: map()) :: Config.t()
    def from_params(params) when is_map(params) do
      Enum.reduce(params, %Config{}, fn {k, v}, acc ->
        case Map.has_key?(acc, k) do
          true -> Map.put(acc, k, v)
          false -> acc
        end
      end)
    end
  end

  def start_link(params, opts) when is_map(params) do
    config = Config.from_params(params)
    GenServer.start_link(__MODULE__, [config], opts)
  end

  @spec init([Config.t()]) :: {:ok, Config.t()}
  def init([config]) do
    # Start the client and handler processes, the ExIRC supervisor is automatically started when your app runs
    {:ok, client} = ExIRC.start_link!()

    # Register the event handler with ExIRC
    Client.add_handler(client, self())

    # Connect and logon to a server, join a channel and send a simple message
    Logger.debug("Connecting to #{config.server}:#{config.port}")
    Client.connect!(client, config.server, config.port)

    {:ok, %Config{config | :client => client}}
  end

  @spec send_message(pid :: GenServer.server(), message :: binary()) :: :ok
  def send_message(pid, message) do
    GenServer.cast(pid, {:privmsg, message})
  end

  def handle_cast({:privmsg, message}, config) do
    Client.msg(config.client, :privmsg, config.channel, message)
    {:noreply, config}
  end

  @doc """
  Handle messages from the client

  Examples:

    def handle_info({:connected, server, port}, _state) do
      IO.puts "Connected to \#{server}:\#{port}"
    end
    def handle_info(:logged_in, _state) do
      IO.puts "Logged in!"
    end
    def handle_info(%ExIRC.Message{nick: from, cmd: "PRIVMSG", args: ["mynick", msg]}, _state) do
      IO.puts "Received a private message from \#{from}: \#{msg}"
    end
    def handle_info(%ExIRC.Message{nick: from, cmd: "PRIVMSG", args: [to, msg]}, _state) do
      IO.puts "Received a message in \#{to} from \#{from}: \#{msg}"
    end
  """
  def handle_info({:connected, server, port}, config) do
    Logger.debug("Connected to #{server}:#{port}")
    Logger.debug("Logging to #{server}:#{port} as #{config.nick}..")
    Client.logon(config.client, config.pass, config.nick, config.user, config.name)
    {:noreply, config}
  end

  def handle_info(:logged_in, config) do
    Logger.debug("Logged in to #{config.server}:#{config.port}")
    Logger.debug("Joining #{config.channel}..")
    Client.join(config.client, config.channel)
    own_channel = "##{config.nick}"
    Logger.debug("Joining own channel #{own_channel}..")
    Client.join(config.client, own_channel)
    {:noreply, config}
  end

  def handle_info({:login_failed, :nick_in_use}, config) do
    nick = Enum.map(1..8, fn _x -> Enum.random('abcdefghijklmnopqrstuvwxyz') end)
    Client.nick(config.client, to_string(nick))
    {:noreply, config}
  end

  def handle_info(:disconnected, config) do
    Logger.debug("Disconnected from #{config.server}:#{config.port}")
    {:stop, :normal, config}
  end

  def handle_info({:joined, channel}, %Config{channel: conf_channel} = config) when conf_channel == channel do
    Logger.debug("Joined #{channel}")
    # TwitchAPI.check_stream_status()
    {:noreply, config}
  end

  def handle_info({:joined, channel}, config) do
    Logger.debug("Joined #{channel}")
    {:noreply, config}
  end

  def handle_info({:names_list, channel, names_list}, config) do
    names =
      String.split(names_list, " ", trim: true)
      |> Enum.map(fn name -> " #{name}\n" end)

    Logger.info("Users logged in to #{channel}:\n#{names}")
    {:noreply, config}
  end

  def handle_info({:received, msg, %SenderInfo{nick: nick} = sender, channel}, config) do
    Logger.info("#{nick} from #{channel}: #{msg}")
    {:noreply, RajaQueue.MessageHandler.handle_message(msg, sender, config)}
  end

  # def handle_info({:mentioned, msg, %SenderInfo{nick: nick}, channel}, config) do
  #   Logger.warn("#{nick} mentioned you in #{channel}")

  #   case String.contains?(msg, "hi") do
  #     true ->
  #       reply = "Hi #{nick}!"
  #       Client.msg(config.client, :privmsg, config.channel, reply)
  #       Logger.info("Sent #{reply} to #{config.channel}")

  #     false ->
  #       :ok
  #   end

  #   {:noreply, config}
  # end

  def handle_info({:received, msg, %SenderInfo{nick: nick}}, config) do
    Logger.warn("#{nick}: #{msg}")
    # reply = "Hi!"
    # Client.msg(config.client, :privmsg, nick, reply)
    # Logger.info("Sent #{reply} to #{nick}")
    {:noreply, config}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, config) do
    {:noreply, config}
  end

  def terminate(_, state) do
    # Quit the channel and close the underlying client connection when the process is terminating
    Client.quit(state.client, "Goodbye, cruel world.")
    Client.stop!(state.client)
    :ok
  end
end
