defmodule RentDivisionTelegram.Database do
  use GenServer

  # seconds
  @ttl 3600

  alias RentDivisionTelegram.Database.Entry

  @type state() :: %{required(integer()) => Entry.t()}

  # SERVER

  @impl true
  def init(_) do
    Process.send_after(self(), :cleanup, @ttl * 1000)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get, id}, _from, state) when is_integer(id) do
    {:reply, Map.get(state, id), state}
  end

  @impl true
  def handle_call({:put, id, {command, data, stage}}, _from, state)
      when is_integer(id) and is_atom(command) do
    entry = %Entry{last_update: DateTime.utc_now(), command: command, data: data, stage: stage}
    {:reply, entry, Map.put(state, id, entry)}
  end

  @impl true
  def handle_call({:delete, id}, _from, state) when is_integer(id) do
    {:reply, :ok, Map.delete(state, id)}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = DateTime.utc_now()

    new_state =
      state
      |> Enum.filter(fn {_, %Entry{last_update: last_update}} ->
        DateTime.diff(last_update, now) >= @ttl
      end)
      |> Map.new()

    Process.send_after(self(), :cleanup, @ttl * 1000)

    {:noreply, new_state}
  end

  # CLIENT

  def start_link(default) when is_list(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  def get(id) when is_integer(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  def put(id, command, data, stage)
      when is_integer(id) and is_atom(command) and is_integer(stage) do
    GenServer.call(__MODULE__, {:put, id, {command, data, stage}})
  end

  def delete(id) when is_integer(id) do
    GenServer.call(__MODULE__, {:delete, id})
  end
end
