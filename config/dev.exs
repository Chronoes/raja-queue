use Mix.Config

config :raja_queue,
  bot: %{
    :server => "irc.chat.twitch.tv",
    :port => 6667,
    :ssl? => false,
    :nick => "rajaq",
    :pass => System.fetch_env!("TWITCH_IRC_PASS"),
    :user => "RajaQ",
    :name => "RajaQueue Bot",
    :channel => "#chronoes"
  }

config :raja_queue, RajaQueue.TwitchAPI,
  client_secret: System.fetch_env!("TWITCH_API_CLIENT_SECRET"),
config :logger, level: :debug
