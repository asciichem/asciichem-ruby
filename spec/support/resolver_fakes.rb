# frozen_string_literal: true

# Shared resolver test fakes. The house rule against doubles applies
# to mocks, not value fakes carrying recorded data.
RecordedFetch = Struct.new(:body) do
  def get(_url)
    body
  end
end

def null_cache
  Class.new do
    def key_for(*) = nil

    def read(*) = nil

    def write(*) = nil
  end.new
end
