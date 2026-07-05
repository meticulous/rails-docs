require "test_helper"

class CrossrefLinkerTest < ActiveSupport::TestCase
  setup do
    @pv = package_versions(:v8_1_3)
    @persistence = entity_identities(:ar_persistence)
    @save = entity_identities(:ar_persistence_save)
  end

  # ---- Fully-qualified constants ----

  test "links a fully-qualified constant that exists in this version" do
    html = "<p>See ActiveRecord::Validations for more information.</p>"
    result = link_from(@save, html)
    assert_includes result, %(<a href="/v8.1.3/active_record/validations"><code>ActiveRecord::Validations</code></a>)
  end

  test "does not link a FQN whose identity is absent from this version" do
    # ActiveRecord::Callbacks has an identity but no entity_version in v8_1_3.
    html = "<p>See ActiveRecord::Callbacks for further details.</p>"
    result = link_from(@save, html)
    assert_not_includes result, "<a"
    assert_includes result, "ActiveRecord::Callbacks"
  end

  test "does not link a FQN that has no identity at all" do
    html = "<p>See ActiveRecord::TotallyMadeUp for details.</p>"
    result = link_from(@save, html)
    assert_not_includes result, "<a"
  end

  # ---- FQN + method ----

  test "links a fully-qualified method reference with #" do
    html = "<p>Prefer ActiveRecord::Persistence#update! over manual updates.</p>"
    result = link_from(@save, html)
    assert_includes result, %(<a href="/v8.1.3/active_record/persistence/update-bang"><code>ActiveRecord::Persistence#update!</code></a>)
  end

  test "links a fully-qualified method reference with a dot" do
    # Render from the Persistence module page so the reference to #save
    # is a cross-reference, not a self-link.
    html = "<p>Calls ActiveRecord::Persistence.save internally.</p>"
    result = link_from(@persistence, html)
    assert_includes result, %(href="/v8.1.3/active_record/persistence/save")
    assert_includes result, "ActiveRecord::Persistence.save</code></a>"
  end

  # ---- Bare #method on the current class ----

  test "links a bare #method against the current entity's class context" do
    # Rendering on the #save method page — parent is ActiveRecord::Persistence,
    # which also owns #update!.
    html = "<p>Unlike #update!, this does not run validations.</p>"
    result = link_from(@save, html)
    assert_includes result, %(<a href="/v8.1.3/active_record/persistence/update-bang"><code>#update!</code></a>)
  end

  test "links a bare #method on a class page against the class itself" do
    html = "<p>Use #save to persist.</p>"
    result = link_from(@persistence, html)
    assert_includes result, %(<a href="/v8.1.3/active_record/persistence/save"><code>#save</code></a>)
  end

  test "does not link a bare #method that does not exist on the current class" do
    html = "<p>There is no #frobnicate here.</p>"
    result = link_from(@save, html)
    assert_not_includes result, "<a"
  end

  # ---- Namespace-chain resolution for bare constants ----

  test "resolves a bare constant by walking the namespace chain outward" do
    # From ActiveRecord::Persistence, "Validations" should resolve to
    # ActiveRecord::Validations (chain: ...::Persistence::Validations, then
    # ActiveRecord::Validations).
    html = "<p>Validations run before save.</p>"
    result = link_from(@save, html)
    assert_includes result, %(<a href="/v8.1.3/active_record/validations"><code>Validations</code></a>)
  end

  test "does not fall through to top-level for a bare constant" do
    # "Base" is only ActiveRecord::Base here (no top-level Base). From the
    # ActiveRecord::Validations namespace there is no ActiveRecord::Validations::Base
    # nor ActiveRecord::Base... actually ActiveRecord::Base DOES exist, so pick
    # a name that only exists at top level to prove no top-level fallthrough.
    # "Foo" exists only as a top-level identity — must NOT be linked from an AR page.
    html = "<p>Foo is unrelated.</p>"
    result = link_from(@save, html)
    assert_not_includes result, "<a"
  end

  # ---- No self-links ----

  test "never links the entity the page is about (constant self-link)" do
    html = "<p>ActiveRecord::Persistence is a module.</p>"
    result = link_from(@persistence, html)
    assert_not_includes result, "<a"
  end

  test "never links the method the page is about (bare self-link)" do
    html = "<p>#save persists the record.</p>"
    result = link_from(@save, html)
    assert_not_includes result, "<a"
  end

  # ---- Skip inside <pre> and existing <a> ----

  test "skips references inside <pre> code blocks" do
    html = "<pre>ActiveRecord::Validations</pre>"
    result = link_from(@save, html)
    assert_not_includes result, "<a"
  end

  test "skips references already inside an <a> tag" do
    html = %(<p><a href="/elsewhere">ActiveRecord::Validations</a></p>)
    result = link_from(@save, html)
    assert_equal 1, result.scan("<a").size, "should not add a nested link"
    assert_includes result, %(href="/elsewhere")
  end

  # ---- Linking inside inline <code> ----

  test "links a reference inside inline <code>, keeping the <code> wrapper" do
    html = "<p>The <code>ActiveRecord::Validations</code> module.</p>"
    result = link_from(@save, html)
    assert_includes result, %(<code><a href="/v8.1.3/active_record/validations">ActiveRecord::Validations</a></code>)
  end

  # ---- HTML escaping / safety ----

  test "escapes < and & in pass-through text when splicing a link into the node" do
    html = "<p>expects a value &lt; 5, x &lt;b size, AT&amp;T — see ActiveRecord::Validations</p>"
    result = link_from(@save, html)
    assert_includes result, "&lt; 5"
    assert_includes result, "&lt;b size"
    assert_includes result, "AT&amp;T"
    assert_includes result, %(<a href="/v8.1.3/active_record/validations">)
  end

  test "returns blank input untouched" do
    linker = CrossrefLinker.new(@pv, @save)
    assert_equal "", linker.link("")
    assert_nil linker.link(nil)
  end

  test "leaves prose with no references untouched" do
    html = "<p>just some words here.</p>"
    assert_equal html, link_from(@save, html)
  end

  private

  def link_from(identity, html)
    CrossrefLinker.new(@pv, identity).link(html)
  end
end
