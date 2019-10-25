defmodule RajaQueue.MessageHandler do
  require Logger

  alias ExIRC.Client
  alias ExIRC.SenderInfo
  alias RajaQueue.Bot
  alias RajaQueue.QueueState

  @prefix "-"
  @queue_delimiter " FBBlock "

  @queue_action "queue"

  @add_action "add"
  @remove_action "remove"
  @remove_alt_action "rm"

  @bump_action "bump"
  @prio_action "prio"
  @next_action "next"
  @clear_action "clear"

  @whitelist_action "whitelist"

  @help_action "help"

  @help_doc ~s(#{@prefix}#{@queue_action} -> Show queue
#{@prefix}#{@add_action} TEXT -> Add new item to the end
#{@prefix}#{@bump_action} ID -> Bump existing item in queue to top
#{@prefix}#{@prio_action} TEXT -> Add new item to top
#{@prefix}#{@remove_action},#{@prefix}#{@remove_alt_action} ID -> Remove item from queue
#{@prefix}#{@next_action} -> Clear topmost item
#{@prefix}#{@clear_action} -> Clear all of queue
#{@prefix}#{@whitelist_action} NICK -> Add NICK to whitelist
#{@prefix}#{@help_action} -> Show this help)

  @spec handle_message(binary(), SenderInfo.t(), Bot.Config.t()) :: Bot.Config.t()
  def handle_message(@prefix <> msg, sender, config) do
    case handle_command(String.trim(msg), sender, config) do
      {:persist, result} ->
        QueueState.persist()
        result

      {:noaction, result} ->
        result
    end
  end

  def handle_message(_msg, _sender, config), do: config

  defp send_message(config, msg) do
    Bot.handle_cast({:privmsg, msg}, config)
  end

  defp is_whitelisted?(%SenderInfo{nick: nick}), do: QueueState.is_whitelisted?(nick)

  defp do_queue(config, timeout \\ nil)

  defp do_queue(config, nil) do
    queue = QueueState.get_queue()

    unless Enum.empty?(queue) do
      queue_str =
        queue
        |> Enum.map_join(@queue_delimiter, fn item -> "#{item.action} (#{item.id})" end)

      send_message(config, queue_str)
      Logger.debug("Queue items messaged")
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

  defp remove_command(id, sender, config) do
    if is_whitelisted?(sender) do
      case Integer.parse(id) do
        :error ->
          {:noaction, config}

        {id, _} ->
          case QueueState.find_item(id) do
            nil ->
              {:noaction, config}

            item ->
              QueueState.remove_item(item)
              Logger.info("Removed \"#{item.action}\" from queue")
              {:persist, config}
          end
      end
    else
      {:noaction, config}
    end
  end

  @spec handle_command(binary(), SenderInfo.t(), Bot.Config.t()) :: {:noaction | :persist, Bot.Config.t()}
  def handle_command(@queue_action <> _msg, sender, config) do
    if is_whitelisted?(sender) do
      {:noaction, do_queue(config)}
    else
      {:noaction, do_queue(config, 60)}
    end
  end

  def handle_command("#{@add_action} " <> msg, sender, config) do
    if is_whitelisted?(sender) do
      QueueState.add_item(msg)
      Logger.info("Added \"#{msg}\" to queue")
      {:persist, do_queue(config)}
    else
      {:noaction, config}
    end
  end

  def handle_command("#{@bump_action} " <> id, sender, config) do
    if is_whitelisted?(sender) do
      case Integer.parse(id) do
        :error ->
          {:noaction, config}

        {id, _} ->
          case QueueState.find_item(id) do
            nil ->
              {:noaction, config}

            item ->
              QueueState.bump_item(item)
              Logger.info("Bumped \"#{item.action}\" to top")
              {:persist, config}
          end
      end
    else
      {:noaction, config}
    end
  end

  def handle_command("#{@prio_action} " <> msg, sender, config) do
    if is_whitelisted?(sender) do
      QueueState.add_item(msg, true)
      Logger.info("Added priority \"#{msg}\" to queue")
      {:persist, do_queue(config)}
    else
      {:noaction, config}
    end
  end

  def handle_command("#{@remove_alt_action} " <> id, sender, config), do: remove_command(id, sender, config)

  def handle_command("#{@remove_action} " <> id, sender, config), do: remove_command(id, sender, config)

  def handle_command(@next_action <> _msg, sender, config) do
    if is_whitelisted?(sender) do
      QueueState.pop_queue()
      Logger.info("Removed next item from queue")
      {:persist, do_queue(config)}
    else
      {:noaction, config}
    end
  end

  def handle_command(@clear_action <> _msg, sender, config) do
    if is_whitelisted?(sender) do
      QueueState.clear_queue()
      Logger.info("Cleared queue")
      {:persist, config}
    else
      {:noaction, config}
    end
  end

  def handle_command("#{@whitelist_action} " <> msg, sender, config) do
    if is_whitelisted?(sender) do
      QueueState.whitelist_user(String.downcase(msg))
      send_message(config, "Whitelisted @#{msg}")
      Logger.info("Whitelisted #{msg}")
      {:persist, config}
    else
      {:noaction, config}
    end
  end

  def handle_command(@help_action <> _msg, _sender, config) do
    help_doc = @help_doc |> String.replace("\n", " | ")
    # Client.msg(config.client, :privmsg, nick, help_doc)
    Client.msg(config.client, :privmsg, "##{config.nick}", help_doc)
    {:noaction, config}
  end

  def handle_command(cmd, _sender, config) do
    Logger.debug("Unknown command: #{cmd}")
    {:noaction, config}
  end
end
