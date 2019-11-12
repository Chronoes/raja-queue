defmodule RajaQueue.TwitchAPI do
  use GenServer

  alias RajaQueue.Bot
  alias RajaQueue.TwitchAPI.Client

  defmodule Config do
    defstruct client_id: "",
              client_secret: "",
              user_id: "",
              bot_nick: nil,
              stream_online: false

    def from_params(params) do
      struct(__MODULE__, params)
    end
  end

  @offline_check 5 * 60 * 1000
  @online_check 60 * 60 * 1000

  def start_link([params, opts]) do
    config = Config.from_params(params)
    GenServer.start_link(__MODULE__, [config], opts)
  end

  @spec init([Config.t()]) :: {:ok, Config.t()}
  def init([config]) do
    schedule_stream_check(@offline_check)
    {:ok, config}
  end

  def check_stream_status do
    Kernel.send(__MODULE__, :stream_check)
  end

  def handle_call({:stream_online, since}, config) do
    unless config.stream_online do
      time =
        if is_nil(since) do
          @offline_check
        else
          NaiveDateTime.from_iso8601!(since)
          # Add fixed time to stream start
          |> NaiveDateTime.add(@offline_check, :millisecond)
          # Check how much time passed since now
          |> NaiveDateTime.diff(NaiveDateTime.utc_now(), :millisecond)
          # < 0 means it's started longer than 5 minutes ago, so send msg immediately
          |> max(0)
        end

      Process.send_after(self(), :send_boot_msg, time)
    end

    {:noreply, %{config | stream_online: true}}
  end

  def handle_call(:stream_offline, config) do
    {:noreply, %{config | stream_online: false}}
  end

  def handle_info(:stream_check, %Config{user_id: user_id} = config) do
    case Client.get_stream_by_user(user_id) do
      {:ok, response} ->
        {:noreply, new_config} = process_response(response.body, config)
        # Schedule once an hour check if stream has started
        schedule_stream_check(
          if new_config.stream_online do
            @online_check
          else
            @offline_check
          end
        )

        {:noreply, new_config}

      {:error, _} ->
        schedule_stream_check(@offline_check)
        {:noreply, config}
    end
  end

  def handle_info(:send_boot_msg, config) do
    Bot.send_message(config.bot_nick, "fairBot RajaQ booting up fairBot")
    {:noreply, config}
  end

  defp schedule_stream_check(time) do
    Process.send_after(self(), :stream_check, time)
  end

  defp process_response(%{"stream" => stream}, config) when is_nil(stream) do
    handle_call(:stream_offline, config)
  end

  defp process_response(%{"stream" => stream}, config) do
    handle_call({:stream_online, Map.get(stream, "created_at")}, config)
  end
end
