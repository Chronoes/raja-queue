defmodule RajaQueue.MessageHandler do
  require Logger

  alias ExIRC.Client
  alias ExIRC.SenderInfo
  alias RajaQueue.Bot.Config
  alias RajaQueue.QueueState

  @prefix "-"
  @queue_action "queue"
  @add_action "add "
  @bump_action "bump "
  @prio_action "prio "
  @next_action "next"
  @clear_action "clear"

  @spec handle_message(binary(), SenderInfo.t(), Config.t()) :: Config.t()
  def handle_message(@prefix <> msg, sender, config), do: handle_command(String.trim(msg), sender, config)
  def handle_message(_msg, _sender, config), do: config

  defp send_message(config, msg) do
    Client.msg(config.client, :privmsg, config.channel, msg)
  end

  defp is_whitelisted?(%SenderInfo{nick: nick} = _sender), do: QueueState.is_whitelisted?(nick)

  defp do_queue(config, timeout \\ nil)

  defp do_queue(config, timeout) when is_nil(timeout) do
    queue = QueueState.get_queue()

    unless PriorityQueue.empty?(queue) do
      queue_str =
        queue
        |> Enum.map_join(" FBBlock ", fn {_prio, item} -> "#{item.action} (#{item.id})" end)

      send_message(config, queue_str)
      Logger.info("Queue items messaged")
    end

    config
  end

  defp do_queue(config, timeout) do
    if QueueState.queue_message_timeout?(timeout) do
      config
    else
      do_queue(config)
    end
  end

  @spec handle_command(binary(), SenderInfo.t(), Config.t()) :: Config.t()
  def handle_command(@queue_action, _sender, config), do: do_queue(config, 60)

  def handle_command(@add_action <> msg, sender, config) do
    if is_whitelisted?(sender) do
      QueueState.add_item(msg)
      Logger.info("Added \"#{msg}\" to queue")
      do_queue(config)
    else
      config
    end
  end

  def handle_command(@bump_action <> id, sender, config) do
    if is_whitelisted?(sender) do
      {id, _} = Integer.parse(id)

      case QueueState.find_item(id) do
        nil ->
          config

        item ->
          QueueState.bump_item(item)
          Logger.info("Bumped \"#{item.action}\" to top")
          do_queue(config)
      end
    else
      config
    end
  end

  def handle_command(@prio_action <> msg, sender, config) do
    if is_whitelisted?(sender) do
      QueueState.add_item(msg, 1)
      Logger.info("Added priority \"#{msg}\" to queue")
      do_queue(config)
    else
      config
    end
  end

  def handle_command(@next_action, sender, config) do
    if is_whitelisted?(sender) do
      QueueState.pop_queue()
      Logger.info("Removed next item from queue")
      do_queue(config)
    else
      config
    end
  end

  def handle_command(@clear_action, sender, config) do
    if is_whitelisted?(sender) do
      QueueState.clear_queue()
      send_message(config, "Cleared queue")
      Logger.info("Cleared queue")
    end

    config
  end

  def handle_command(cmd, _sender, config) do
    Logger.debug("Unknown command: #{cmd}")
    config
  end
end