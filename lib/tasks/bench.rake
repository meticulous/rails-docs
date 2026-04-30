require "benchmark"

namespace :bench do
  desc <<~DESC
    Benchmark the ClassPresenter render pipeline against the heaviest
    real entity in the DB (default: ActiveRecord::Base in current_stable
    rails).
      bin/rails bench:class_page                # AR::Base
      bin/rails bench:class_page FQN=ActionController::Base
      bin/rails bench:class_page RUNS=100
  DESC
  task class_page: :environment do
    fqn = ENV.fetch("FQN", "ActiveRecord::Base")
    runs = Integer(ENV.fetch("RUNS", "50"))

    pv = PackageVersion.current_stable
    abort "No current_stable PackageVersion ingested" unless pv

    identity = pv.source.entity_identities.find_by(fqn: fqn, kind: %w[class module])
    abort "No entity_identity for #{fqn}" unless identity

    ev = identity.entity_versions.find_by!(package_version: pv)

    # Warm up the connection / Rails autoload
    3.times { build_presenter(ev).inherited_methods_grouped }

    samples = Array.new(runs) do
      ms = Benchmark.realtime do
        presenter = build_presenter(ev)
        presenter.inherited_methods_grouped
        presenter.included_modules
        presenter.extended_modules
        presenter.constants
        presenter.attributes
        presenter.own_methods
        presenter.inheritors
      end * 1000
      ms
    end.sort

    closure_count = InheritanceClosure.where(descendant_identity: identity, package_version: pv).count
    method_count = build_presenter(ev).inherited_methods_grouped.sum { |_, ms| ms.size }

    puts <<~REPORT
      #{fqn} on #{pv.source.slug} v#{pv.channel} (#{runs} cold ClassPresenter runs):

        ancestors via closure : #{closure_count}
        inherited methods     : #{method_count}

        min  : #{samples.first.round(2)} ms
        p50  : #{samples[runs / 2].round(2)} ms
        p95  : #{samples[(runs * 0.95).floor].round(2)} ms
        max  : #{samples.last.round(2)} ms

      Plan target: <100ms p95 for a class-page render.
    REPORT
  end

  desc "Benchmark search on a typical query"
  task :search, [:query] => :environment do |_, args|
    query = args[:query] || ENV.fetch("QUERY", "has_many")
    runs = Integer(ENV.fetch("RUNS", "20"))

    SearchAdapter.current.search(query: query, limit: 25) # warm

    samples = Array.new(runs) do
      response = nil
      ms = Benchmark.realtime { response = SearchAdapter.current.search(query: query, limit: 25) } * 1000
      [ms, response]
    end

    times = samples.map(&:first).sort
    last_response = samples.last.last

    puts <<~REPORT
      Search "#{query}" (#{runs} runs):

        results returned    : #{last_response.results.size} of #{last_response.total} total
        suggestions         : #{last_response.suggestions.size}
        sources represented : #{last_response.facets[:source].keys.size}

        min  : #{times.first.round(2)} ms
        p50  : #{times[runs / 2].round(2)} ms
        p95  : #{times[(runs * 0.95).floor].round(2)} ms
        max  : #{times.last.round(2)} ms
    REPORT
  end

  def build_presenter(entity_version)
    ClassPresenter.new(entity_version)
  end
end
