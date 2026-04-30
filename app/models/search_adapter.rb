# Vendor-neutral search interface. v1 has one implementation
# (SearchAdapter::Postgres), but the SearchController only depends on this
# module's Result/Response shape so a Typesense/Algolia/Meilisearch swap
# happens by setting `SearchAdapter.current = OtherAdapter.new` in an
# initializer — no controller or view edits needed.
module SearchAdapter
  Result = Struct.new(:entity_version, :score, :highlights, keyword_init: true)
  Response = Struct.new(:results, :total, :facets, :suggestions, :took_ms, keyword_init: true) do
    def initialize(results: [], total: 0, facets: { kind: {}, framework: {} }, suggestions: [], took_ms: 0)
      super
    end
  end

  class << self
    attr_writer :current

    def current
      @current ||= Postgres.new
    end
  end
end
