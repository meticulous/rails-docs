require "test_helper"

class LoaderTest < ActiveSupport::TestCase
  COMPLETE_JSONL = <<~JSONL.freeze
    {"type":"header","source_slug":"rails","source_display_name":"Ruby on Rails","source_github_repo":"rails/rails","schema_version":1}
    {"type":"package_version","channel":"99.0.0","major":99,"minor":0,"patch":0,"release_series":"99.0","released_on":"2099-01-01","git_ref":"v99.0.0","git_sha":"deadbeef","ord":99000000}
    {"type":"framework","slug":"activerecord","display_name":"Active Record"}
    {"type":"entity_identity","fqn":"Foo","kind":"class","scope":null,"name":"Foo","parent_fqn":null,"framework_slug":"activerecord"}
    {"type":"entity_identity","fqn":"FooMod","kind":"module","scope":null,"name":"FooMod","parent_fqn":null,"framework_slug":"activerecord"}
    {"type":"entity_identity","fqn":"Foo#bar","kind":"method","scope":"instance","name":"bar","parent_fqn":"Foo","framework_slug":"activerecord"}
    {"type":"entity_version","fqn":"Foo","kind":"class","scope":null,"framework_slug":"activerecord","visibility":"public","doc_markdown":"A class.","doc_summary":"A class."}
    {"type":"entity_version","fqn":"FooMod","kind":"module","scope":null,"framework_slug":"activerecord","visibility":"public"}
    {"type":"entity_version","fqn":"Foo#bar","kind":"method","scope":"instance","framework_slug":"activerecord","visibility":"public","doc_markdown":"Returns bar.","signature_text":"bar(x)"}
    {"type":"class_version","fqn":"Foo","superclass_fqn":null}
    {"type":"method_version","fqn":"Foo#bar","scope":"instance","ghost":false}
    {"type":"method_param","method_fqn":"Foo#bar","method_scope":"instance","position":0,"name":"x","kind":"req"}
    {"type":"inheritance_edge","child_fqn":"Foo","child_kind":"class","ancestor_fqn":"FooMod","ancestor_kind":"module","relation":"include","position":0}
  JSONL

  test "imports a complete JSONL stream" do
    Loader.new(StringIO.new(COMPLETE_JSONL)).import!

    pv = PackageVersion.find_by!(channel: "99.0.0")
    assert pv.ok?
    assert_equal 99000000, pv.ord
    assert_equal 3, pv.entity_versions.count

    foo = EntityIdentity.find_by!(fqn: "Foo", kind: "class")
    assert_equal "activerecord", foo.framework.slug
    assert_equal pv, foo.first_seen_version
    assert_equal pv, foo.last_seen_version

    bar = EntityIdentity.find_by!(fqn: "Foo#bar", kind: "method")
    bar_version = bar.entity_versions.first
    assert_equal "Returns bar.", bar_version.doc_markdown
    assert_equal "bar(x)", bar_version.signature_text
    assert_equal 1, bar_version.method_params.count
    assert_equal "x", bar_version.method_params.first.name
    assert bar_version.method_version
    assert_not bar_version.method_version.ghost?

    foo_class_version = foo.entity_versions.first.class_version
    assert foo_class_version
    assert_nil foo_class_version.superclass_identity

    assert_equal 1, pv.inheritance_edges.count
    assert_equal 1, pv.inheritance_closures.count
    closure = pv.inheritance_closures.first
    assert_equal foo, closure.descendant_identity
    assert_equal EntityIdentity.find_by(fqn: "FooMod"), closure.ancestor_identity
    assert_equal 1, closure.depth
  end

  test "is idempotent on re-run" do
    Loader.new(StringIO.new(COMPLETE_JSONL)).import!
    Loader.new(StringIO.new(COMPLETE_JSONL)).import!

    pv = PackageVersion.find_by!(channel: "99.0.0")
    assert_equal 3, pv.entity_versions.count
    assert_equal 1, pv.inheritance_edges.count
    assert_equal 1, pv.inheritance_closures.count
  end

  test "removes entity_versions absent from a later run" do
    Loader.new(StringIO.new(COMPLETE_JSONL)).import!

    smaller = <<~JSONL
      {"type":"header","source_slug":"rails","schema_version":1}
      {"type":"package_version","channel":"99.0.0","git_ref":"v99.0.0","git_sha":"d","ord":99000000}
      {"type":"framework","slug":"activerecord","display_name":"Active Record"}
      {"type":"entity_identity","fqn":"Foo","kind":"class","scope":null,"name":"Foo","framework_slug":"activerecord"}
      {"type":"entity_version","fqn":"Foo","kind":"class","scope":null,"framework_slug":"activerecord","visibility":"public"}
    JSONL
    Loader.new(StringIO.new(smaller)).import!

    pv = PackageVersion.find_by!(channel: "99.0.0")
    assert_equal 1, pv.entity_versions.count
    assert EntityIdentity.exists?(fqn: "Foo#bar"),
           "identity rows persist across runs (only entity_versions are reaped)"
  end

  test "raises when first record is not a header" do
    bad = <<~JSONL
      {"type":"package_version","channel":"99.0.0","git_ref":"x","git_sha":"y","ord":1}
    JSONL
    assert_raises(Loader::HeaderRequired) { Loader.new(StringIO.new(bad)).import! }
  end

  test "raises on unknown record type" do
    bad = <<~JSONL
      {"type":"header","source_slug":"rails","schema_version":1}
      {"type":"package_version","channel":"99.0.0","git_ref":"x","git_sha":"y","ord":1}
      {"type":"alien"}
    JSONL
    assert_raises(Loader::UnknownRecordType) { Loader.new(StringIO.new(bad)).import! }
  end

  test "raises on unsupported schema version" do
    bad = <<~JSONL
      {"type":"header","source_slug":"rails","schema_version":99}
    JSONL
    assert_raises(Loader::UnsupportedSchemaVersion) { Loader.new(StringIO.new(bad)).import! }
  end

  test "raises when entity records appear before package_version" do
    bad = <<~JSONL
      {"type":"header","source_slug":"rails","schema_version":1}
      {"type":"entity_identity","fqn":"Foo","kind":"class","scope":null,"name":"Foo"}
    JSONL
    assert_raises(Loader::PackageVersionRequired) { Loader.new(StringIO.new(bad)).import! }
  end
end
