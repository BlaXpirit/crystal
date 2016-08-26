require "spec"
require "oauth"

describe OAuth::Params do
  it "builds" do
    params = OAuth::Params.new
    params.add "foo", "value1"
    params.add "bar", "a+b"
    params.add "a=", "=/="
    assert params.to_s == "a%253D%3D%253D%252F%253D%26bar%3Da%252Bb%26foo%3Dvalue1"
  end
end
