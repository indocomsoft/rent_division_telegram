defmodule RentDivisionTelegram.Database.Entry do
  @moduledoc """
  This module is only used to define a struct for each entry in the database.
  """

  @enforce_keys [:last_update, :command, :data, :stage]
  defstruct @enforce_keys

  @type t() :: %__MODULE__{
          last_update: DateTime.t(),
          command: atom(),
          stage: pos_integer(),
          data: any()
        }
end
