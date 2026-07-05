# Rebuilds RDoc's crossref auto-linking at render time. Doc bodies mention
# other API entities as plain text — "See ActiveRecord::Validations for more
# information", "<code>ActiveRecord::Base</code>", "#save" — because the
# crossref anchors RDoc emits were dropped at ingest. This walks the rendered
# doc fragment and turns those mentions back into version-scoped links against
# the database.
#
# Conservative by design: a wrong link is worse than a missed one. We only
# link when the target identity actually exists in this package_version, never
# link the page's own entity, and never fall through to top-level for bare
# single-word constants (which would turn every "Base" or "Rails" into a link).
#
# Constructed with the current (package_version, current_identity); call
# #link on an HTML fragment string to get it back with references linked.
class CrossrefLinker
  # A method name as it appears in prose references: plain names with the
  # usual trailing punctuation (?, !, =) and the operator methods.
  METHOD_NAME = /[A-Za-z_][A-Za-z0-9_]*[?!=]?|\[\]=?|[<>=!]=|[<>]|<=>|[+\-*\/%&|^~]|\*\*|<<|>>|===|=~/

  # A constant path segment: ActiveRecord, Validations, CONFIG_KEY.
  CONST_NAME = /[A-Z][A-Za-z0-9_]*/

  # One combined scanner over a text node. Order matters: try the qualified
  # FQN (with optional #method or .method suffix), then a bare #method,
  # then a bare constant. Everything else is passed through untouched.
  TOKEN_SCANNER = /
    (?<qualified>(?:#{CONST_NAME}::)+#{CONST_NAME}(?:(?:\#|\.)(?:#{METHOD_NAME}))?)
    |
    (?<bare_method>\#(?:#{METHOD_NAME}))
    |
    (?<bare_const>#{CONST_NAME})
  /x

  def initialize(package_version, current_identity)
    @package_version = package_version
    @current_identity = current_identity
    @source = package_version.source
  end

  # Takes an HTML fragment string, returns it with cross-references linked.
  # Returns the input unchanged when there's nothing that could be a reference.
  # Every candidate token needs either an uppercase letter (constants) or a
  # '#' (bare methods), so bail cheaply when neither is present.
  def link(html)
    return html if html.blank? || !html.match?(/[A-Z]|\#/)

    fragment = Nokogiri::HTML.fragment(html)
    text_nodes = linkable_text_nodes(fragment)
    return html if text_nodes.empty?

    resolve_targets(collect_tokens(text_nodes))
    return html if @resolved.empty? && @bare_const_map.empty?

    text_nodes.each { |node| rewrite(node) }
    fragment.to_html
  end

  private

  # Text nodes eligible for linking: everything except text inside <a> (already
  # a link) and <pre> (code blocks — highlighted separately, never linked).
  # Inline <code> IS eligible: RDoc wraps constant mentions in <code>, and we
  # want those linked while keeping the <code> styling.
  def linkable_text_nodes(fragment)
    fragment.xpath(".//text()").reject do |node|
      node.ancestors.any? { |a| a.name == "a" || a.name == "pre" }
    end
  end

  # First pass: gather every candidate token (constant FQNs, bare methods,
  # bare constants) so they can be resolved in one batched round-trip rather
  # than one query per token.
  def collect_tokens(text_nodes)
    fqns = Set.new          # "ActiveRecord::Validations"
    bare_consts = Set.new   # "Validations"
    method_refs = Set.new   # [parent_fqn, method_name]
    bare_methods = Set.new  # "save"

    text_nodes.each do |node|
      node.text.scan(TOKEN_SCANNER) do
        m = Regexp.last_match
        if (tok = m[:qualified])
          fqn, meth = split_qualified(tok)
          if meth
            method_refs << [ fqn, meth ]
          else
            fqns << fqn
          end
        elsif (tok = m[:bare_method])
          bare_methods << tok[1..] # strip leading '#'
        elsif (tok = m[:bare_const])
          bare_consts << tok
        end
      end
    end

    { fqns:, bare_consts:, method_refs:, bare_methods: }
  end

  # Second pass: resolve all collected tokens against the DB, filtered to
  # identities that have an entity_version in this package_version. Populates
  # @resolved — a hash keyed by the token strings we'll re-scan for — with the
  # target EntityIdentity for each.
  def resolve_targets(tokens)
    @resolved = {}

    # Bare constants resolve via the namespace chain to a concrete FQN, which
    # then gets looked up alongside the explicit FQNs.
    const_fqn_candidates = tokens[:fqns].dup
    bare_const_map = {} # "Validations" => "ActiveRecord::Validations" (first that resolves)
    tokens[:bare_consts].each do |bare|
      namespace_chain_fqns(bare).each { |candidate| const_fqn_candidates << candidate }
    end

    # Bare methods resolve against the current entity's class/module context.
    method_parent = current_method_context
    method_ref_candidates = tokens[:method_refs].dup
    tokens[:bare_methods].each do |name|
      method_ref_candidates << [ method_parent, name ] if method_parent
    end

    existing_const_fqns = existing_fqns(const_fqn_candidates, %w[class module constant])
    existing_methods = existing_method_identities(method_ref_candidates)

    # Map explicit FQN tokens.
    tokens[:fqns].each do |fqn|
      id = existing_const_fqns[fqn]
      @resolved["const::#{fqn}"] = id if id && id.id != @current_identity.id
    end

    # Map bare constants to the first namespace-chain candidate that exists.
    tokens[:bare_consts].each do |bare|
      namespace_chain_fqns(bare).each do |candidate|
        id = existing_const_fqns[candidate]
        next unless id && id.id != @current_identity.id
        bare_const_map[bare] = id
        break
      end
    end
    @bare_const_map = bare_const_map

    # Map explicit FQN#method and bare #method.
    existing_methods.each do |(parent_fqn, name), id|
      next if id.id == @current_identity.id
      @resolved["method::#{parent_fqn}##{name}"] = id
    end
    @method_parent = method_parent
  end

  # Rewrite a single text node in place, replacing each resolved reference
  # with a link and leaving unmatched text alone. Assembled with explicit
  # offsets (not gsub) so the pass-through text between tokens gets
  # HTML-escaped — the node's raw text can legitimately contain < or &
  # ("expects a value < 5"), which must not reach the fragment parser
  # unescaped once we splice anchors into the same string.
  def rewrite(node)
    original = node.text
    return unless original.match?(TOKEN_SCANNER)

    # References in plain prose get a <code> wrapper (matching how RDoc
    # renders crossrefs); references already inside <code> keep their
    # existing wrapper rather than nesting a second one.
    @in_code = node.ancestors.any? { |a| a.name == "code" }

    linked = false
    replacement = +""
    last = 0
    original.scan(TOKEN_SCANNER) do
      m = Regexp.last_match
      link = if (tok = m[:qualified])
        link_for_qualified(tok)
      elsif (tok = m[:bare_method])
        link_for_bare_method(tok)
      else
        link_for_bare_const(m[:bare_const])
      end

      replacement << ERB::Util.h(original[last...m.begin(0)])
      replacement << (link || ERB::Util.h(m[0]))
      linked ||= !link.nil?
      last = m.end(0)
    end
    replacement << ERB::Util.h(original[last..])

    return unless linked
    node.replace(Nokogiri::HTML.fragment(replacement))
  end

  def link_for_qualified(tok)
    fqn, meth = split_qualified(tok)
    if meth
      id = @resolved["method::#{fqn}##{meth}"]
      id && anchor(id, tok)
    else
      id = @resolved["const::#{fqn}"]
      id && anchor(id, tok)
    end
  end

  def link_for_bare_method(tok)
    return nil unless @method_parent
    name = tok[1..]
    id = @resolved["method::#{@method_parent}##{name}"]
    id && anchor(id, tok)
  end

  def link_for_bare_const(tok)
    id = @bare_const_map[tok]
    id && anchor(id, tok)
  end

  # Build the <a>. Both interpolations are escaped and must stay that
  # way. Prose-context references get a <code> label so they read as
  # code (like RDoc's own crossref output); inside an existing <code>
  # the bare label avoids nesting code-in-code.
  def anchor(identity, label)
    href = path_for(identity)
    text = ERB::Util.h(label)
    text = "<code>#{text}</code>" unless @in_code
    %(<a href="#{ERB::Util.h(href)}">#{text}</a>)
  end

  # Splits "ActiveRecord::Base#save" into ["ActiveRecord::Base", "save"];
  # a bare "ActiveRecord::Base" returns [fqn, nil].
  def split_qualified(tok)
    if (m = tok.match(/\A(.+?)(?:\#|\.)(.+)\z/)) && m[1].include?("::")
      [ m[1], m[2] ]
    else
      [ tok, nil ]
    end
  end

  # Namespace-chain candidates for a bare constant name, innermost first.
  # From ActiveRecord::Persistence, "Validations" yields
  # ["ActiveRecord::Persistence::Validations", "ActiveRecord::Validations"].
  # Never includes the bare top-level name (prevents "Base"/"Rails" spam).
  def namespace_chain_fqns(bare)
    parts = namespace_prefix.split("::")
    (parts.size).downto(1).map { |n| (parts[0...n] + [ bare ]).join("::") }
  end

  # The namespace we resolve bare names within: for a method page, its parent
  # class/module; for a class/module page, the entity itself.
  def namespace_prefix
    @namespace_prefix ||=
      if @current_identity.kind == "method"
        @current_identity.parent_fqn.to_s
      else
        @current_identity.fqn.to_s
      end
  end

  # Context for bare #method resolution: the class/module the method lives on
  # (method page → parent) or the class/module itself (class page → self).
  def current_method_context
    if @current_identity.kind == "method"
      @current_identity.parent_fqn
    elsif @current_identity.kind == "class" || @current_identity.kind == "module"
      @current_identity.fqn
    end
  end

  # Batched lookup: which of these FQNs exist as class/module/constant
  # identities with an entity_version in this package_version. Returns
  # {fqn => EntityIdentity}.
  def existing_fqns(fqns, kinds)
    return {} if fqns.empty?
    @source.entity_identities
           .where(fqn: fqns.to_a, kind: kinds)
           .joins(:entity_versions)
           .where(entity_versions: { package_version_id: @package_version.id })
           .distinct
           .index_by(&:fqn)
  end

  # Batched lookup for method identities. Candidates are [parent_fqn, name]
  # pairs. Returns {[parent_fqn, name] => EntityIdentity} for those present in
  # this package_version. Prefers the instance method when both scopes exist.
  def existing_method_identities(candidates)
    return {} if candidates.empty?
    parent_fqns = candidates.map(&:first).uniq
    names = candidates.map(&:last).uniq

    rows = @source.entity_identities
                  .where(kind: "method", parent_fqn: parent_fqns, name: names)
                  .joins(:entity_versions)
                  .where(entity_versions: { package_version_id: @package_version.id })
                  .distinct
                  .to_a

    wanted = candidates.to_set
    result = {}
    rows.each do |id|
      key = [ id.parent_fqn, id.name ]
      next unless wanted.include?(key)
      # Prefer instance scope on collision (docs usually mean #method).
      result[key] = id if result[key].nil? || id.scope == "instance"
    end
    result
  end

  # Version-scoped URL path for an identity. EntityIdentity#entity_url_path
  # is the single source of truth for the slug shape, shared with
  # EntityPathHelper, so prose links can't drift from the canonical routes.
  def path_for(identity)
    "/#{version_segment}/#{identity.entity_url_path}"
  end

  def version_segment
    @package_version.channel == "edge" ? "edge" : "v#{@package_version.channel}"
  end
end
