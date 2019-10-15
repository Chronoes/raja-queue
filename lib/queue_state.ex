defmodule RajaQueue.QueueState do
  use Agent

  alias RajaQueue.QueueItem

  defmodule State do
    defstruct current_id: 0,
              queue: PriorityQueue.new(),
              whitelist: [],
              queue_displayed: nil,
              state_file: ""

    @spec from_json(binary) :: __MODULE__.t()
    def from_json(json) do
      %{"queue" => queue, "whitelist" => whitelist} = Jason.decode!(json)

      prio_queue =
        queue
        |> Enum.with_index(1)
        |> Enum.map(fn {action, i} -> {i + 1, %QueueItem{id: i, action: action}} end)
        |> Enum.into(PriorityQueue.new())

      %__MODULE__{
        current_id: PriorityQueue.size(prio_queue),
        queue: prio_queue,
        whitelist: whitelist
      }
    end

    @spec to_json(__MODULE__.t()) :: any
    def to_json(%__MODULE__{queue: queue, whitelist: whitelist}) do
      Jason.encode!(%{
        "queue" => queue |> Enum.map(fn {_prio, item} -> item.action end),
        "whitelist" => whitelist
      })
    end
  end

  def start_link(opts) do
    {state_file, opts} = Keyword.pop(opts, :state_file)
    state = File.read!(state_file)
    Agent.start_link(fn -> %{State.from_json(state) | state_file: state_file} end, opts)
  end

  def persist do
    state = Agent.get(__MODULE__, fn state -> state end)
    File.write!(state.state_file, State.to_json(state))
  end

  @spec get_queue :: PriorityQueue.t()
  def get_queue do
    Agent.get(__MODULE__, fn state -> state.queue end)
  end

  defp increment_id do
    Agent.get_and_update(__MODULE__, fn state ->
      id = state.current_id + 1
      {id, %{state | current_id: id}}
    end)
  end

  @spec find_item(id :: pos_integer()) :: QueueState.t() | nil
  def find_item(id) do
    Agent.get(__MODULE__, fn state -> state.queue |> Enum.find(fn {_prio, item} -> item.id == id end) |> elem(1) end)
  end

  @spec add_item(action :: binary()) :: QueueState.t()
  def add_item(action, priority \\ nil) do
    id = increment_id()

    Agent.get_and_update(__MODULE__, fn state ->
      item = %QueueItem{id: id, action: action}

      priority =
        if is_nil(priority) do
          PriorityQueue.size(state.queue) + 2
        else
          priority
        end

      queue = state.queue |> PriorityQueue.put(priority, item)
      {item, %{state | queue: queue}}
    end)
  end

  @spec bump_item(item :: QueueState.t()) :: :ok
  def bump_item(item) do
    Agent.update(__MODULE__, fn state ->
      queue =
        state.queue
        |> Enum.filter(fn {_prio, a} -> a != item end)
        |> Enum.into(PriorityQueue.new())
        |> PriorityQueue.put(1, item)

      %{state | queue: queue}
    end)
  end

  def pop_queue do
    Agent.update(__MODULE__, fn state -> %{state | queue: PriorityQueue.delete_min(state.queue)} end)
  end

  def clear_queue do
    Agent.update(__MODULE__, fn state -> %{state | queue: PriorityQueue.new()} end)
  end

  @spec is_whitelisted?(nick :: binary()) :: bool()
  def is_whitelisted?(nick) do
    Agent.get(__MODULE__, fn state -> state.whitelist |> Enum.member?(nick) end)
  end

  def queue_message_timeout?(timeout) do
    Agent.get_and_update(__MODULE__, fn
      %__MODULE__.State{queue_displayed: queue_displayed} = state when is_nil(queue_displayed) ->
        {false, %{state | queue_displayed: NaiveDateTime.utc_now()}}

      %__MODULE__.State{queue_displayed: queue_displayed} = state ->
        if NaiveDateTime.diff(NaiveDateTime.utc_now(), queue_displayed) > timeout do
          {false, %{state | queue_displayed: NaiveDateTime.utc_now()}}
        else
          {true, state}
        end
    end)
  end
end
