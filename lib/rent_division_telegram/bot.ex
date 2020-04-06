defmodule RentDivisionTelegram.Bot do
  @moduledoc """
  The main implementation of the bot.
  """

  @bot :rent_division_telegram

  use ExGram.Bot,
    name: @bot

  middleware(ExGram.Middleware.IgnoreUsername)

  alias RentDivisionTelegram.Database

  def bot, do: @bot

  def handle({:command, "start", _msg}, context) do
    answer(
      context,
      "Hi! I help you get envy-free and efficient rent allocation. Use /help for commands you can run"
    )
  end

  def handle({:command, "help", _msg}, context) do
    answer(
      context,
      """
      /create -- create apartment
      /apt <id> -- get information about apartment with the given id
      /submit -- submit your valuation as a renter
      """
    )
  end

  def handle({:command, "apt", %{text: text}}, context) do
    with {:ok, %{body: body, status_code: 200}} <- api_get("/apartments/#{text}"),
         {:ok,
          %{"status" => status, "results" => results, "renters" => renters, "rooms" => rooms}} <-
           Jason.decode(body) do
      renters_lookup =
        renters
        |> Enum.map(fn %{"id" => id, "name" => name} -> {id, name} end)
        |> Map.new()

      rooms_lookup =
        rooms
        |> Enum.map(fn %{"id" => id, "name" => name} -> {id, name} end)
        |> Map.new()

      processed_results =
        results
        |> Enum.map(fn %{"renter_id" => renter_id, "room_id" => room_id, "rent" => rent} ->
          "#{renters_lookup[renter_id]} gets room #{rooms_lookup[room_id]} with rent $#{rent}"
        end)
        |> Enum.join("\n")

      processed_valuations =
        renters_lookup
        |> Map.keys()
        |> get_valuations()
        |> Enum.map(fn {renter_id, valuations} ->
          processed =
            Enum.map(valuations, fn %{"room_id" => room_id, "value" => value} ->
              "- #{rooms_lookup[room_id]}: $#{value}"
            end)

          Enum.join(["#{renters_lookup[renter_id]} valuations:" | processed], "\n")
        end)
        |> Enum.join("\n\n")

      answer(
        context,
        """
        Apartment id #{text} has status #{status}.

        The result is:
        #{processed_results}

        Valuations by each renter:
        #{processed_valuations}
        """
      )
    else
      {:ok, %{status_code: 404}} ->
        answer(context, "Apartment with that id is not found")

      {:ok, response} ->
        answer(
          context,
          "Something went wrong. Please contact @indocomsoft and forward him this message.\n\n\n#{
            inspect(response)
          }"
        )

      {:error, error} ->
        answer(
          context,
          "Something when wrong. Please contact @indocomsoft and forward him this message.\n\n\n#{
            inspect(error)
          }"
        )
    end
  end

  def handle({:command, "create", %{from: %{id: id}}}, context) do
    Database.put(id, :start, nil, 1)
    answer(context, "Let's create a new apartment. What is the name of the apartment?")
  end

  def handle({:command, "submit", %{from: %{id: id}}}, context) do
    Database.put(id, :submit, nil, 1)
    answer(context, "What is the apartment id?")
  end

  def handle({:command, "done", %{from: %{id: id}}}, context) do
    case Database.get(id) do
      nil -> answer(context, "Use /help for commands you can run")
      entry -> process(id, :done, entry, context)
    end
  end

  def handle({:command, _, _}, context) do
    answer(context, "Use /help for commands you can run")
  end

  def handle({:text, text, %{from: %{id: id}}}, context) do
    case Database.get(id) do
      nil -> answer(context, "Use /help for commands you can run")
      entry -> process(id, text, entry, context)
    end
  end

  defp process(id, text, %{command: :start, stage: 1}, context) do
    Database.put(id, :start, %{name: text}, 2)
    answer(context, "Got it. How much is the rent? (send only a whole number, e.g. 1000)")
  end

  defp process(id, text, %{command: :start, data: data, stage: 2}, context) do
    case Integer.parse(text) do
      {rent, ""} ->
        Database.put(id, :start, Map.put(data, :rent, rent), 3)

        answer(
          context,
          "Got it. Please send me the names of the renters. Duplicate names will be deduplicated.\n\n Use /done when you're finished"
        )

      _ ->
        answer(context, "Invalid rent. Please only send a whole number, e.g. 1000")
    end
  end

  defp process(id, :done, %{command: :start, data: data, stage: 3}, context) do
    case Map.get(data, :renters, []) do
      [] ->
        answer(context, "You must specify at least one renter")

      renters ->
        uniq_renters = Enum.uniq(renters)
        Database.put(id, :start, %{data | renters: uniq_renters}, 4)

        answer(
          context,
          "The renters are #{Enum.join(uniq_renters, ", ")}. \n\nNow, please send me the names of the rooms. Duplicates names will be deduplicated.\n\n Use /done when you're finished"
        )
    end
  end

  defp process(id, text, %{command: :start, data: data, stage: 3}, _context) do
    renters = Map.get(data, :renters, [])
    Database.put(id, :start, Map.put(data, :renters, [text | renters]), 3)
  end

  defp process(
         id,
         :done,
         %{command: :start, data: data = %{name: name, rent: rent, renters: renters}, stage: 4},
         context
       ) do
    case Map.get(data, :rooms, []) do
      [] ->
        answer(context, "You must specify at least one renter")

      rooms ->
        Database.delete(id)
        uniq_rooms = Enum.uniq(rooms)

        with {:ok, %{body: body, status_code: 200}} <-
               api_post("/apartments", %{name: name, rent: rent}),
             {:ok, %{"id" => id}} <- Jason.decode(body),
             {:ok, %{status_code: 200}} <-
               api_post("/apartments/#{id}/renters", %{names: renters}),
             {:ok, %{status_code: 200}} <-
               api_post("/apartments/#{id}/rooms", %{names: uniq_rooms}) do
          answer(context, """
          Created apartment #{name} with $#{rent} rent.
          The renters are #{Enum.join(renters, ", ")}.
          The rooms are #{Enum.join(uniq_rooms, ", ")}.

          The created apartment id is #{id}
          """)
        else
          {:ok, response} ->
            answer(
              context,
              "Something went wrong. Please contact @indocomsoft and forward him this message.\n\n\n#{
                inspect(response)
              }"
            )

          {:error, error} ->
            answer(
              context,
              "Something when wrong. Please contact @indocomsoft and forward him this message.\n\n\n#{
                inspect(error)
              }"
            )
        end
    end
  end

  defp process(id, text, %{command: :start, data: data, stage: 4}, _context) do
    renters = Map.get(data, :rooms, [])
    Database.put(id, :start, Map.put(data, :rooms, [text | renters]), 4)
  end

  defp process(id, apartment_id, %{command: :submit, stage: 1}, context) do
    with {:ok, %{body: body, status_code: 200}} <- api_get("/apartments/#{apartment_id}"),
         {:ok, %{"name" => name, "rent" => rent, "renters" => renters, "rooms" => rooms}} <-
           Jason.decode(body) do
      renters_lookup =
        renters
        |> Enum.map(fn %{"id" => id, "name" => name} -> {"#{id}", name} end)
        |> Map.new()

      rooms = Enum.map(rooms, fn %{"id" => id, "name" => name} -> {id, name} end)

      rendered_renters =
        renters_lookup
        |> Enum.map(fn {id, name} -> "#{id}: #{name}" end)
        |> Enum.join("\n")

      Database.put(id, :submit, %{rent: rent, renters: renters_lookup, rooms: rooms}, 2)

      answer(
        context,
        """
        Submitting valuation for Apartment #{name} with rent $#{rent}.

        Please send the number corresponding to your name:
        #{rendered_renters}
        """
      )
    else
      {:ok, %{status_code: 404}} ->
        answer(context, "Apartment with that id is not found")

      {:ok, response} ->
        answer(
          context,
          "Something went wrong. Please contact @indocomsoft and forward him this message.\n\n\n#{
            inspect(response)
          }"
        )

      {:error, error} ->
        Database.delete(id)

        answer(
          context,
          "Something when wrong. Please contact @indocomsoft and forward him this message.\n\n\n#{
            inspect(error)
          }"
        )
    end
  end

  defp process(
         id,
         renter_id,
         %{command: :submit, stage: 2, data: %{rent: rent, renters: renters, rooms: rooms}},
         context
       ) do
    if Map.has_key?(renters, renter_id) do
      data = %{rent: rent, renter_id: renter_id, done: %{}, leftover: rooms}
      Database.put(id, :submit, data, 3)

      process(
        id,
        :first,
        %{
          command: :submit,
          stage: 3,
          data: data
        },
        context
      )
    else
      answer(context, "Invalid number. Please only enter number from the given list.")
    end
  end

  defp process(
         id,
         text,
         %{
           command: :submit,
           stage: 3,
           data: data = %{done: done, leftover: leftover = [{room_id, _name} | rooms]}
         },
         context
       ) do
    if text == :first do
      ask_next_rooms(leftover, done, id, data, context)
    else
      case Integer.parse(text) do
        {value, ""} ->
          ask_next_rooms(rooms, Map.put(done, room_id, value), id, data, context)

        _ ->
          answer(context, "Invalid rent. Please only send a whole number, e.g. 1000")
      end
    end
  end

  defp ask_next_rooms(next_rooms, next_done, id, %{renter_id: renter_id, rent: rent}, context) do
    case next_rooms do
      [] ->
        Database.delete(id)

        if rent == next_done |> Map.values() |> Enum.sum() do
          case api_post("/renters/#{renter_id}/valuations", %{"valuations" => next_done}) do
            {:ok, %{status_code: 200}} ->
              answer(context, "Your valuation has been submitted")

            {:ok, %{status_code: 409}} ->
              answer(context, "Valuation for one particular renter can only be submitted once.")

            other ->
              answer(
                context,
                "Something when wrong. Please contact @indocomsoft and forward him this message.\n\n\n#{
                  inspect(other)
                }"
              )
          end
        else
          answer(
            context,
            "Your valuations do not sum up to the rent of the apartment. Aborting."
          )
        end

      [{_, name} | _] ->
        answer(
          context,
          """
          Note that your valuations must sum up to the rent of the apartment, $#{rent}.

          How much do you value room #{name}? (send only a whole number, e.g. 1000)
          """
        )
    end
  end

  defp base_url, do: Application.get_env(:rent_division_telegram, :base_url)

  defp api_get(path) do
    HTTPoison.get("#{base_url()}#{path}")
  end

  defp api_post(path, payload) do
    HTTPoison.post("#{base_url()}#{path}", Jason.encode!(payload), [
      {"Content-Type", "application/json"}
    ])
  end

  defp get_valuations(renter_ids) do
    renter_ids
    |> Enum.map(fn renter_id ->
      with {:ok, %{body: body}} <- api_get("/renters/#{renter_id}"),
           {:ok, parsed} <- Jason.decode(body) do
        {renter_id, Map.get(parsed, "valuations", [])}
      else
        _ -> {renter_id, []}
      end
    end)
  end
end
