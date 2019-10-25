defmodule RajaQueue.TwitchAPI.Client do
  use Tesla, only: [:get]

  plug Tesla.Middleware.BaseUrl, "https://api.twitch.tv"

  plug Tesla.Middleware.Headers, [
    {"Client-ID", Keyword.get(Application.get_env(:raja_queue, RajaQueue.TwitchAPI), :client_id)},
    {"Accept", "application/vnd.twitchtv.v5+json"}
  ]

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger

  @kraken "/kraken"

  @spec get_stream_by_user(user :: binary()) :: Tesla.Env.result()
  def get_stream_by_user(user) do
    get("#{@kraken}/streams/#{user}")
  end
end
