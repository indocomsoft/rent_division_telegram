defmodule RentDivisionTelegram.Database.Entry do
  @enforce_keys [:last_update, :command, :data, :stage]
  defstruct @enforce_keys

  @type t() :: %__MODULE__{
          last_update: DateTime.t(),
          command: atom(),
          stage: pos_integer(),
          data: any()
        }
end
