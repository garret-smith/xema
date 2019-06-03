defprotocol Xema.Castable do
  @moduledoc """
  Converts data using the specified schema.
  """

  @doc """
  Converts the given data using the specified schema.
  """
  def cast(value, schema)
end

defmodule Xema.Castable.Helper do
  @moduledoc false

  import Xema.Utils, only: [to_existing_atom: 1]

  defmacro __using__(_) do
    quote do
      import Xema.Castable.Helper
      import Xema.Utils, only: [to_existing_atom: 1]

      alias Xema.Schema

      def cast(value, %Schema{type: :any}), do: {:ok, value}

      def cast(value, %Schema{type: type})
          when is_boolean(type),
          do: {:ok, value}

      def cast(value, %Schema{type: type, module: module} = schema),
        do: cast(value, type, module, schema)

      def cast(atom, types, module, schema) when is_list(types),
        do:
          types
          |> Stream.map(fn type -> cast(atom, type, module, schema) end)
          |> Enum.find(%{to: types, value: atom}, fn
            {:ok, _} -> true
            {:error, _} -> false
          end)
    end
  end

  def to_integer(str, type) when type in [:integer, :number] do
    case Integer.parse(str) do
      {int, ""} -> {:ok, int}
      _ -> {:error, %{to: type, value: str}}
    end
  end

  def to_float(str, type) when type in [:float, :number] do
    case Float.parse(str) do
      {int, ""} -> {:ok, int}
      _ -> {:error, %{to: type, value: str}}
    end
  end

  def module(module) do
    unless module == nil, do: module, else: :struct
  end

  def check_keyword(list, to) do
    case Keyword.keyword?(list) do
      true -> :ok
      false -> {:error, %{to: to, value: list}}
    end
  end

  def cast_key(value, :atoms) when is_binary(value) do
    case to_existing_atom(value) do
      nil -> :error
      cast -> {:ok, cast}
    end
  end

  def cast_key(value, :strings) when is_atom(value),
    do: {:ok, Atom.to_string(value)}

  def cast_key(value, _),
    do: {:ok, value}

  def fields(map) do
    Enum.reduce_while(map, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case cast_key(key, :atoms) do
        {:ok, key} ->
          {:cont, {:ok, Map.put(acc, key, value)}}

        :error ->
          {:halt, {:error, %{to: :struct, key: key}}}
      end
    end)
  end
end

defimpl Xema.Castable, for: Atom do
  use Xema.Castable.Helper

  def cast(nil, nil, _module, _schema), do: {:ok, nil}

  def cast(nil, :string, _module, _schema), do: {:error, %{to: :string, value: nil}}

  def cast(atom, type, module, _schema) when is_atom(type) do
    case type do
      :atom ->
        {:ok, atom}

      :boolean when atom in [true, false] ->
        {:ok, atom}

      nil ->
        {:error, %{to: nil, value: atom}}

      :string ->
        {:ok, to_string(atom)}

      :struct ->
        {:error, %{to: module(module), value: atom}}

      _ ->
        {:error, %{to: type, value: atom}}
    end
  end
end

defimpl Xema.Castable, for: BitString do
  use Xema.Castable.Helper

  def cast(str, :struct, module, _schema)
      when module in [Date, DateTime, NaiveDateTime, Time] do
    case apply(module, :from_iso8601, [str]) do
      {:ok, value, _offset} -> {:ok, value}
      {:ok, value} -> {:ok, value}
      {:error, _} -> {:error, %{to: module, value: str}}
    end
  end

  def cast(str, :struct, Decimal, _schema) do
    {:ok, Decimal.new(str)}
  rescue
    _ -> {:error, %{to: Decimal, value: str}}
  end

  def cast(str, type, module, _schema) do
    case type do
      :atom ->
        case to_existing_atom(str) do
          nil -> {:error, %{to: :atom, value: str}}
          atom -> {:ok, atom}
        end

      :float ->
        to_float(str, :float)

      :integer ->
        to_integer(str, :integer)

      :number ->
        case String.contains?(str, ".") do
          true -> to_float(str, :number)
          false -> to_integer(str, :number)
        end

      :string ->
        {:ok, str}

      :struct ->
        {:error, %{to: module(module), value: str}}

      _ ->
        {:error, %{to: type, value: str}}
    end
  end
end

defimpl Xema.Castable, for: Date do
  use Xema.Castable.Helper

  def cast(date, :struct, Date, _schema), do: {:ok, date}

  def cast(date, :struct, module, _schema), do: {:error, %{to: module(module), value: date}}

  def cast(date, type, _module, _schema), do: {:error, %{to: type, value: date}}
end

defimpl Xema.Castable, for: DateTime do
  use Xema.Castable.Helper

  def cast(date_time, :struct, DateTime, _schema), do: {:ok, date_time}

  def cast(date_time, :struct, module, _schema),
    do: {:error, %{to: module(module), value: date_time}}

  def cast(date_time, type, _module, _schema), do: {:error, %{to: type, value: date_time}}
end

defimpl Xema.Castable, for: Decimal do
  use Xema.Castable.Helper

  def cast(decimal, :struct, Decimal, _schema), do: {:ok, decimal}

  def cast(decimal, :struct, module, _schema), do: {:error, %{to: module(module), value: decimal}}

  def cast(decimal, type, _module, _schema), do: {:error, %{to: type, value: decimal}}
end

defimpl Xema.Castable, for: Float do
  use Xema.Castable.Helper

  def cast(float, :struct, Decimal, _schema), do: {:ok, Decimal.from_float(float)}

  def cast(float, type, module, _schema) do
    case type do
      :float ->
        {:ok, float}

      :number ->
        {:ok, float}

      :string ->
        {:ok, to_string(float)}

      :struct ->
        {:error, %{to: module(module), value: float}}

      _ ->
        {:error, %{to: type, value: float}}
    end
  end
end

defimpl Xema.Castable, for: Integer do
  use Xema.Castable.Helper

  def cast(int, :struct, Decimal, _schema), do: {:ok, Decimal.new(int)}

  def cast(int, type, module, _schema) do
    case type do
      :integer ->
        {:ok, int}

      :number ->
        {:ok, int}

      :string ->
        {:ok, to_string(int)}

      :float ->
        {:ok, int * 1.0}

      :struct ->
        {:error, %{to: module(module), value: int}}

      _ ->
        {:error, %{to: type, value: int}}
    end
  end
end

defimpl Xema.Castable, for: List do
  use Xema.Castable.Helper

  def cast([], type, module, _schema) do
    case type do
      :keyword ->
        {:ok, []}

      :map ->
        {:ok, %{}}

      :list ->
        {:ok, []}

      :tuple ->
        {:ok, {}}

      :struct ->
        {:error, %{to: module(module), value: []}}

      _ ->
        {:error, %{to: type, value: []}}
    end
  end

  def cast(list, :map, _module, %Schema{keys: :strings}) do
    with :ok <- check_keyword(list, :map) do
      {:ok, Enum.into(list, %{}, fn {key, value} -> {to_string(key), value} end)}
    end
  end

  def cast(list, :map, _module, _schema) do
    with :ok <- check_keyword(list, :map) do
      {:ok, Enum.into(list, %{}, & &1)}
    end
  end

  def cast(list, type, module, _schema) do
    case type do
      :keyword ->
        {:ok, list}

      :struct ->
        case module do
          nil ->
            {:error, %{to: :struct, value: list}}

          module ->
            case Keyword.keyword?(list) do
              true -> {:ok, struct!(module, list)}
              false -> {:error, %{to: module, value: list}}
            end
        end

      :tuple ->
        case Keyword.keyword?(list) do
          true -> {:error, %{to: :tuple, value: list}}
          false -> {:ok, List.to_tuple(list)}
        end

      :list ->
        {:ok, list}

      _ ->
        {:error, %{to: type, value: list}}
    end
  end
end

defimpl Xema.Castable, for: Map do
  use Xema.Castable.Helper

  def cast(map, :struct, nil, _schem), do: {:ok, map}

  def cast(map, :struct, module, _schema) do
    with {:ok, fields} <- fields(map) do
      {:ok, struct!(module, fields)}
    end
  end

  def cast(map, :keyword, _module, _schema) do
    Enum.reduce_while(map, {:ok, []}, fn {key, value}, {:ok, acc} ->
      case cast_key(key, :atoms) do
        {:ok, key} ->
          {:cont, {:ok, [{key, value} | acc]}}

        :error ->
          {:halt, {:error, %{to: :keyword, key: key}}}
      end
    end)
  end

  def cast(map, :map, _module, %Schema{keys: keys}) do
    Enum.reduce_while(map, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case cast_key(key, keys) do
        {:ok, key} ->
          {:cont, {:ok, Map.put(acc, key, value)}}

        :error ->
          {:halt, {:error, %{to: :map, key: key}}}
      end
    end)
  end

  def cast(map, type, _module, _schema),
    do: {:error, %{to: type, value: map}}
end

defimpl Xema.Castable, for: NaiveDateTime do
  use Xema.Castable.Helper

  def cast(date_time, :struct, NaiveDateTime, _schema), do: {:ok, date_time}

  def cast(date_time, :struct, module, _schema),
    do: {:error, %{to: module(module), value: date_time}}

  def cast(date_time, type, _module, _schema), do: {:error, %{to: type, value: date_time}}
end

defimpl Xema.Castable, for: Time do
  use Xema.Castable.Helper

  def cast(time, :struct, Time, _schema), do: {:ok, time}

  def cast(time, :struct, module, _schema),
    do: {:error, %{to: module(module), value: time}}

  def cast(time, type, _module, _schema), do: {:error, %{to: type, value: time}}
end

defimpl Xema.Castable, for: Tuple do
  use Xema.Castable.Helper

  def cast(tuple, type, module, _schema) do
    case type do
      :tuple ->
        {:ok, tuple}

      :list ->
        {:ok, Tuple.to_list(tuple)}

      :struct ->
        {:error, %{to: module(module), value: tuple}}

      _ ->
        {:error, %{to: type, value: tuple}}
    end
  end
end