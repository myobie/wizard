defmodule Wizard.Previews.PNG do
  defstruct name: nil,
            image: %Imagineer.Image.PNG{}

  @type t :: %__MODULE__{}

  @type result :: {:ok, t} | {:error, atom}

  @spec read(Path.t) :: result
  def read(filename) do
    with name = Path.basename(filename),
      {:ok, data} <- File.read(filename)
    do
      from_binary(data, name: name)
    end
  end

  @spec full_path(Path.t, t) :: Path.t
  def full_path(path, %__MODULE__{} = png),
    do: Path.join(path, png.name)

  @spec write(t, [to: Path.t]) :: result
  def write(%__MODULE__{} = png, [to: path]) do
    with data = to_binary(png.image),
      :ok <- File.write(full_path(path, png), data)
    do
      {:ok, png}
    end
  end

  @spec to_binary(t) :: binary
  def to_binary(%__MODULE__{} = png),
    do: Imagineer.Image.PNG.to_binary(png.image)

  @spec from_binary(binary, keyword) :: result
  def from_binary(data, opts \\ []) do
    with name = Keyword.get(opts, :name),
      :png <- Imagineer.FormatDetector.detect(data),
      {:ok, image} <- Imagineer.Image.PNG.process(data)
    do
      {:ok, %__MODULE__{image: image, name: name}}
    else
      :unkown -> {:error, :not_a_valid_png}
      error -> error
    end
  end
end
