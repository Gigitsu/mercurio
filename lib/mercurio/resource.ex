defmodule Mercurio.Resource do
  @moduledoc """
  Resource modeling

  Allows to define structs representing an API resources.
  """

  require Logger

  alias Mercurio.Resource

  @typedoc "API Resource"
  @type t :: struct()

  @type inflect_mode :: :camel | :pascal | :snake | :kebab | :none

  @callback inflect :: inflect_mode

  defmacro __using__(_) do
    quote do
      import Mercurio.Resource, only: [resource: 1, resource: 2, field: 1, field: 2, field: 3]

      alias Mercurio.Resource

      @behaviour Resource

      @derive [Resource.Serializable]

      def inflect,
        do:
          :libsvc
          |> Application.get_env(:rest, [])
          |> Keyword.get(:inflect_keys, :none)

      defoverridable Resource
    end
  end

  @doc """
  Defines an api resource
  """
  defmacro resource(opts \\ [], do: block) do
    inflect = Keyword.get(opts, :inflect)

    quote do
      alias Mercurio.Resource

      Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :resource_fields, accumulate: true)

      @type t :: %__MODULE__{}

      unquote(block)

      Module.eval_quoted(__ENV__, [
        Resource.__defstruct__(@struct_fields),
        Resource.__fields__(@struct_fields),
        Resource.__types__(@resource_fields),
        Resource.__inflect__(unquote(inflect))
      ])
    end
  end

  defmacro field(name, type \\ :string, opts \\ []) do
    quote do
      Mercurio.Resource.__field__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  def __defstruct__(fields) do
    quote do
      defstruct unquote(Macro.escape(fields))
    end
  end

  def __fields__(struct_fields) do
    fields =
      struct_fields
      |> Enum.reverse()
      |> Enum.map(&elem(&1, 0))

    quote do
      def __fields__(), do: unquote(fields)
    end
  end

  def __field__(mod, name, type, opts) do
    fields = Module.get_attribute(mod, :struct_fields)

    if List.keyfind(fields, name, 0) do
      raise ArgumentError, "field #{inspect(name)} is already defined on resource #{mod}"
    end

    default = Keyword.get(opts, :default)

    Module.put_attribute(mod, :struct_fields, {name, default})
    Module.put_attribute(mod, :resource_fields, {name, type, opts})
  end

  def __types__(fields) do
    quoted =
      Enum.map(fields, fn {name, type, _} ->
        quote do
          def __type__(unquote(name)) do
            unquote(Macro.escape(type))
          end
        end
      end)

    types =
      fields
      |> Enum.map(&Tuple.delete_at(&1, 2))
      |> Map.new()
      |> Macro.escape()

    quote do
      def __types__(), do: unquote(types)
      unquote(quoted)
      def __type__(_), do: nil
    end
  end

  def __inflect__(nil), do: []

  def __inflect__(inflect) do
    quote do
      def inflect, do: unquote(inflect)
    end
  end

  # @doc """
  # Serializes a resource to a map with string keys.
  # """
  # @spec serialize(t() | [t()]) :: any()
  # def serialize(resource) when is_list(resource),
  #   do: Enum.map(resource, &serialize/1)
  #
  # def serialize(%module{} = resource) do
  #   inflect_mode = module.inflect()
  #
  #   resource
  #   |> Map.from_struct()
  #   |> Enum.reduce(%{}, fn
  #     {key, value}, acc ->
  #       case serialize_value(value) do
  #         nil ->
  #           acc
  #
  #         value ->
  #           inflected_key = do_inflect(key, inflect_mode)
  #           Map.put(acc, inflected_key, value)
  #       end
  #   end)
  # end

  # @doc """
  # Deserializes a map into a resource
  # """
  # @spec deserialize(t() | atom, any()) :: t() | [t()]
  # def deserialize(resource, data) when is_list(data),
  #   do: Enum.map(data, &deserialize(resource, &1))
  #
  # def deserialize(%module{}, data),
  #   do: deserialize(module, data)
  #
  # def deserialize(module, data) when is_atom(module) do
  #   inflect_mode = module.inflect()
  #
  #   Logger.debug("Deserializing resource #{module}\n#{inspect(data)}")
  #
  #   module.__types__()
  #   |> Enum.reduce(struct(module), fn
  #     {key, type}, acc ->
  #       inflected_key = do_inflect(key, inflect_mode)
  #
  #       case Map.fetch(data, inflected_key) do
  #         {:ok, value} ->
  #           Logger.debug("Deserializing attribute #{key} of type #{type}\n#{inspect(value)}")
  #           %{acc | key => deserialize_value(type_struct(type), value)}
  #
  #         :error ->
  #           Logger.debug("Attribute #{key}, inflected to #{inflected_key}, not found")
  #           %{acc | key => nil}
  #       end
  #   end)
  # end

  # defp do_inflect(atom, mode) when is_atom(atom), do: atom |> Atom.to_string() |> do_inflect(mode)
  #
  # defp do_inflect(string, :camel), do: Recase.to_camel(string)
  # defp do_inflect(string, :kebab), do: Recase.to_kebab(string)
  # defp do_inflect(string, :snake), do: Recase.to_snake(string)
  # defp do_inflect(string, :pascal), do: Recase.to_pascal(string)
  # defp do_inflect(string, _), do: string
  #
  # defp serialize_value({_type, nil}), do: nil
  # defp serialize_value({_type, default}), do: Serializable.serialize(default)
  # defp serialize_value(value), do: Serializable.serialize(value)
  #
  # defp deserialize_value(type, value) when is_nil(type), do: value
  # defp deserialize_value(type, value), do: Serializable.deserialize(type, value)
  #
  # defp type_struct(type) do
  #   case Kernel.function_exported?(type, :__struct__, 0) do
  #     true -> struct(type)
  #     false -> nil
  #   end
  # end
end
