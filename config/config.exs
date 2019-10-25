# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :raja_queue,
  bot: %{
    :server => "irc.chat.twitch.tv",
    :port => 6667,
    :ssl? => false,
    :nick => "rajaq",
    :pass => "",
    :user => "RajaQ",
    :name => "RajaQueue Bot",
    :channel => "#chronoes"
  },
  state_file: "state.json"

config :raja_queue, RajaQueue.TwitchAPI,
  client_id: "69j22qmzkmubds5bj763fknl6bxr2r",
  # Chronoes
  # user_id: "25434785"
  # Fairlight_Excalibur
  user_id: "54989347"

config :tesla, adapter: Tesla.Adapter.Hackney

import_config "config.secret.exs"

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :exirc_example, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:exirc_example, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
