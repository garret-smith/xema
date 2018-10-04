defmodule Xema.Utils do
  @moduledoc false

  @spec get_value(map, String.t() | atom) :: any
  def get_value(map, key) when is_map(map) and is_atom(key) do
    do_get_value(map, to_string(key), key)
  end

  def get_value(map, key) when is_map(map) do
    do_get_value(map, key, to_existing_atom(key))
  end

  defp do_get_value(map, key_string, key_atom) do
    case {Map.get(map, key_string), Map.get(map, key_atom)} do
      {nil, nil} ->
        {:ok, nil}

      {nil, value} ->
        {:ok, value}

      {value, nil} ->
        {:ok, value}

      _ ->
        {:error, :mixed_map}
    end
  end

  @spec default(any, any) :: any
  def default(nil, b), do: b
  def default(a, _b), do: a

  @spec get_key(map, String.t() | atom) :: atom | String.t()
  def get_key(map, key) when is_map(map) and is_atom(key) do
    if Map.has_key?(map, key), do: key, else: to_string(key)
  end

  def get_key(map, key) when is_map(map) do
    if Map.has_key?(map, key), do: key, else: String.to_existing_atom(key)
  end

  @spec has_key?(map | [{term(), term()}], String.t() | atom) :: boolean
  def has_key?(map, key) when is_map(map),
    do: Map.has_key?(map, key) || Map.has_key?(map, toggle_key(key))

  def has_key?(list, key) when is_list(list) do
    Enum.any?(list, fn {k, _} -> k == key end)
  end

  @spec toggle_key(String.t() | atom) :: atom | String.t()
  def toggle_key(key) when is_binary(key), do: to_existing_atom(key)

  def toggle_key(key) when is_atom(key), do: Atom.to_string(key)

  @spec to_existing_atom(String.t()) :: atom | nil
  def to_existing_atom(str) do
    String.to_existing_atom(str)
  rescue
    _ -> nil
  end

  @spec intersection(map, map) :: map
  def intersection(a, b) when is_map(a) and is_map(b),
    do:
      for(
        key <- Map.keys(a),
        true == Map.has_key?(b, key),
        into: %{},
        do: {key, Map.get(b, key)}
      )

  @spec update_id(map, binary) :: map
  def update_id(%{id: a} = map, b) do
    Map.put(map, :id, update_uri(a, b))
  end


  @spec update_uri(URI.t() | nil, URI.t() | nil) :: URI.t() | nil
  def update_uri(nil, nil), do: nil

  def update_uri(id, nil), do: URI.parse(id)

  def update_uri(nil, id), do: URI.parse(id)

  def update_uri(old, new), do: old |> URI.merge(new)
end
