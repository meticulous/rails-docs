require "json"
require "securerandom"

# Imports a JSONL stream produced by `rails_docs_ingester` into Postgres.
# The header carries source metadata and a schema_version that this loader
# tolerates as long as the producer's version is <= our SCHEMA_VERSION
# (forward-compat for additive field changes).
class Loader
  SCHEMA_VERSION = 1

  class HeaderRequired < StandardError; end
  class UnsupportedSchemaVersion < StandardError; end
  class UnknownRecordType < StandardError; end
  class PackageVersionRequired < StandardError; end

  def initialize(io, run_id: self.class.next_run_id)
    @io = io
    @run_id = run_id
    @line_number = 0
    @source = nil
    @package_version = nil
    @framework_cache = {}
    @identity_cache = {}
    @entity_version_cache = {}
  end

  def import!
    ApplicationRecord.transaction do
      process_header(read_first_record)
      while (record = read_next_record)
        dispatch(record)
      end
      finalize!
    end
  end

  def self.next_run_id
    SecureRandom.random_number(2**63)
  end

  private

  def read_first_record
    line = @io.gets
    raise HeaderRequired, "JSONL stream is empty" if line.nil?
    @line_number = 1
    JSON.parse(line)
  end

  def read_next_record
    while (line = @io.gets)
      @line_number += 1
      next if line.strip.empty?
      return JSON.parse(line)
    end
    nil
  end

  def process_header(record)
    raise HeaderRequired, "First record must be {type: 'header'}, got #{record['type'].inspect}" \
      unless record["type"] == "header"
    if record["schema_version"].to_i > SCHEMA_VERSION
      raise UnsupportedSchemaVersion,
            "JSONL schema_version=#{record['schema_version']} exceeds loader SCHEMA_VERSION=#{SCHEMA_VERSION}"
    end

    @source = Source.find_or_initialize_by(slug: record["source_slug"])
    @source.assign_attributes(
      display_name: record["source_display_name"] || @source.display_name || record["source_slug"].humanize,
      github_repo: record["source_github_repo"] || @source.github_repo || "#{record['source_slug']}/#{record['source_slug']}",
      default_branch: record["source_default_branch"] || @source.default_branch || "main"
    )
    @source.save!
  end

  def dispatch(record)
    case record["type"]
    when "package_version" then upsert_package_version(record)
    when "framework" then upsert_framework(record)
    when "entity_identity" then upsert_entity_identity(record)
    when "entity_version" then upsert_entity_version(record)
    when "method_version" then upsert_method_version(record)
    when "class_version" then upsert_class_version(record)
    when "constant_version" then upsert_constant_version(record)
    when "attribute_version" then upsert_attribute_version(record)
    when "method_param" then upsert_method_param(record)
    when "inheritance_edge" then upsert_inheritance_edge(record)
    else raise UnknownRecordType, "Line #{@line_number}: unknown record type #{record['type'].inspect}"
    end
  end

  def upsert_package_version(record)
    @package_version = @source.package_versions.find_or_initialize_by(channel: record["channel"])
    @package_version.assign_attributes(
      git_ref: record["git_ref"],
      git_sha: record["git_sha"],
      ord: record["ord"],
      major: record["major"],
      minor: record["minor"],
      patch: record["patch"],
      prerelease: record["prerelease"],
      release_series: record["release_series"],
      released_on: record["released_on"],
      ingest_status: "running"
    )
    @package_version.save!
  end

  def upsert_framework(record)
    framework = @source.frameworks.find_or_initialize_by(slug: record["slug"])
    framework.update!(display_name: record["display_name"])
    @framework_cache[framework.slug] = framework
  end

  def upsert_entity_identity(record)
    require_package_version!
    identity = @source.entity_identities.find_or_initialize_by(
      fqn: record["fqn"], kind: record["kind"], scope: record["scope"]
    )
    identity.assign_attributes(
      name: record["name"],
      parent_fqn: record["parent_fqn"],
      framework: framework_for(record["framework_slug"])
    )
    identity.save!
    cache_identity(identity)
  end

  def upsert_entity_version(record)
    require_package_version!
    identity = identity_for!(record["fqn"], record["kind"], record["scope"])
    version = identity.entity_versions.find_or_initialize_by(package_version: @package_version)
    version.assign_attributes(
      framework: framework_for(record["framework_slug"]),
      visibility: record["visibility"] || "public",
      deprecated: record.fetch("deprecated", false),
      deprecation_note: record["deprecation_note"],
      doc_markdown: record["doc_markdown"],
      doc_html: record["doc_html"],
      doc_summary: record["doc_summary"],
      source_path: record["source_path"],
      source_line_start: record["source_line_start"],
      source_line_end: record["source_line_end"],
      source_code: record["source_code"],
      signature_text: record["signature_text"],
      call_seq: record["call_seq"],
      last_ingest_run_id: @run_id
    )
    version.save!
    @entity_version_cache[identity.id] = version
  end

  def upsert_method_version(record)
    version = entity_version_for!(record["fqn"], "method", record["scope"])
    aliased = identity_for(record["aliased_fqn"], "method", record["aliased_scope"]) if record["aliased_fqn"]
    method_version = MethodVersion.find_or_initialize_by(entity_version: version)
    method_version.update!(
      yields: record["yields"],
      return_doc: record["return_doc"],
      aliased: aliased,
      ghost: record.fetch("ghost", false)
    )
  end

  def upsert_class_version(record)
    version = entity_version_for!(record["fqn"], record["kind"] || "class", nil)
    superclass = identity_for(record["superclass_fqn"], record["superclass_kind"] || "class", nil) if record["superclass_fqn"]
    class_version = ClassVersion.find_or_initialize_by(entity_version: version)
    class_version.update!(superclass_identity: superclass)
  end

  def upsert_constant_version(record)
    version = entity_version_for!(record["fqn"], "constant", nil)
    constant_version = ConstantVersion.find_or_initialize_by(entity_version: version)
    constant_version.update!(value_expr: record["value_expr"])
  end

  def upsert_attribute_version(record)
    version = entity_version_for!(record["fqn"], "attribute", record["scope"])
    attr_version = AttributeVersion.find_or_initialize_by(entity_version: version)
    attr_version.update!(rw: record["rw"])
  end

  def upsert_method_param(record)
    version = entity_version_for!(record["method_fqn"], "method", record["method_scope"])
    param = version.method_params.find_or_initialize_by(position: record["position"])
    param.update!(
      name: record["name"],
      kind: record["kind"],
      default_expr: record["default_expr"],
      doc: record["doc"]
    )
  end

  def upsert_inheritance_edge(record)
    require_package_version!
    child = identity_for(record["child_fqn"], record["child_kind"], nil)
    ancestor = identity_for(record["ancestor_fqn"], record["ancestor_kind"], nil)
    return unless child && ancestor # silently skip edges referencing un-ingested entities
    edge = InheritanceEdge.find_or_initialize_by(
      package_version: @package_version,
      child_identity: child,
      ancestor_identity: ancestor,
      relation: record["relation"]
    )
    edge.update!(position: record["position"])
  end

  def finalize!
    return unless @package_version

    cleanup_stale_entity_versions
    refresh_first_last_seen_versions
    refresh_inheritance_closure
    refresh_search_vectors
    @package_version.update!(ingest_status: "ok", ingested_at: Time.current)
  end

  # Populates entity_versions.search_vector for this package_version using
  # the four-weight scheme (name=A, signature/params=B, summary=C, body=D).
  # Postgres FTS ranks accordingly when ts_rank_cd is applied.
  def refresh_search_vectors
    sql = ApplicationRecord.sanitize_sql([<<~SQL, @package_version.id])
      UPDATE entity_versions ev
      SET search_vector =
        setweight(to_tsvector('english', COALESCE(ei.name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(ev.signature_text, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(ev.doc_summary, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(ev.doc_markdown, '')), 'D')
      FROM entity_identities ei
      WHERE ev.entity_identity_id = ei.id
        AND ev.package_version_id = ?
    SQL
    ApplicationRecord.connection.execute(sql)
  end

  def cleanup_stale_entity_versions
    @package_version.entity_versions
                    .where.not(last_ingest_run_id: @run_id)
                    .destroy_all
  end

  # One grouped query + one UPDATE FROM VALUES per 1000-row batch. Avoids
  # the per-identity N+1 of the naive find_each / versions.first /
  # versions.last loop.
  def refresh_first_last_seen_versions
    rows = EntityVersion
      .joins(:package_version)
      .where(entity_identity_id: @package_version.entity_versions.select(:entity_identity_id))
      .group(:entity_identity_id)
      .pluck(
        :entity_identity_id,
        Arel.sql("(array_agg(entity_versions.package_version_id ORDER BY package_versions.ord ASC))[1]"),
        Arel.sql("(array_agg(entity_versions.package_version_id ORDER BY package_versions.ord DESC))[1]")
      )
    return if rows.empty?

    rows.each_slice(1_000) do |slice|
      values = slice.map { |id, first, last|
        "(#{Integer(id)}, #{quote_nullable_int(first)}, #{quote_nullable_int(last)})"
      }.join(",")
      ApplicationRecord.connection.execute(<<~SQL)
        UPDATE entity_identities AS ei
        SET first_seen_version_id = data.first_id,
            last_seen_version_id = data.last_id
        FROM (VALUES #{values}) AS data(id, first_id, last_id)
        WHERE ei.id = data.id
      SQL
    end
  end

  def quote_nullable_int(value)
    value.nil? ? "NULL" : Integer(value).to_s
  end

  def refresh_inheritance_closure
    InheritanceClosure.where(package_version_id: @package_version.id).delete_all
    sql = ApplicationRecord.sanitize_sql([<<~SQL, @package_version.id])
      INSERT INTO inheritance_closures
        (package_version_id, descendant_identity_id, ancestor_identity_id, depth, via_relation)
      WITH RECURSIVE closure AS (
        SELECT
          ie.package_version_id,
          ie.child_identity_id AS descendant_identity_id,
          ie.ancestor_identity_id,
          1 AS depth,
          ie.relation AS via_relation
        FROM inheritance_edges ie
        WHERE ie.package_version_id = ?

        UNION

        SELECT
          c.package_version_id,
          c.descendant_identity_id,
          ie.ancestor_identity_id,
          c.depth + 1,
          c.via_relation
        FROM closure c
        JOIN inheritance_edges ie
          ON ie.child_identity_id = c.ancestor_identity_id
         AND ie.package_version_id = c.package_version_id
      )
      SELECT package_version_id, descendant_identity_id, ancestor_identity_id, MIN(depth), MIN(via_relation)
      FROM closure
      GROUP BY package_version_id, descendant_identity_id, ancestor_identity_id
    SQL
    ApplicationRecord.connection.execute(sql)
  end

  def framework_for(slug)
    return nil if slug.blank?
    @framework_cache[slug] ||= @source.frameworks.find_by(slug: slug)
  end

  def identity_for!(fqn, kind, scope)
    @identity_cache[identity_key(fqn, kind, scope)] ||=
      @source.entity_identities.find_by!(fqn: fqn, kind: kind, scope: scope)
  end

  # Soft sibling: returns nil instead of raising when the identity is
  # missing. Used for cross-references (aliases, superclasses, edge
  # endpoints) where the target may legitimately have been suppressed
  # by RDoc (:nodoc:, vendored, outside the parsed source set).
  def identity_for(fqn, kind, scope)
    return nil if fqn.blank?
    key = identity_key(fqn, kind, scope)
    return @identity_cache[key] if @identity_cache.key?(key)
    @identity_cache[key] = @source.entity_identities.find_by(fqn: fqn, kind: kind, scope: scope)
  end

  def cache_identity(identity)
    @identity_cache[identity_key(identity.fqn, identity.kind, identity.scope)] = identity
  end

  def entity_version_for!(fqn, kind, scope)
    identity = identity_for!(fqn, kind, scope)
    @entity_version_cache[identity.id] ||=
      identity.entity_versions.find_by!(package_version: @package_version)
  end

  def identity_key(fqn, kind, scope)
    "#{fqn}|#{kind}|#{scope}"
  end

  def require_package_version!
    return if @package_version
    raise PackageVersionRequired,
          "Line #{@line_number}: package_version record must appear before entity records"
  end
end
