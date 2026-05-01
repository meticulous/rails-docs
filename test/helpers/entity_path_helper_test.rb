require "test_helper"

class EntityPathHelperTest < ActionView::TestCase
  # ghost_method? identifies RDoc placeholders for dynamically-generated
  # method families (e.g. `*_changed?`, `*=`, `*_was`). These have no real
  # URL and their `*` characters bust the entity_path route constraints,
  # so they're rendered as plain <code> instead of links.

  test "treats names with `*` as part of an RDoc dynamic-method pattern as ghost" do
    %w[*_changed? *_was *= *_will_change! restore_*! clear_*_change with_attached_*].each do |name|
      identity = build_method_identity(name: name, fqn: "Foo##{name}")
      assert ghost_method?(identity), "expected #{name.inspect} to be flagged as ghost"
    end
  end

  test "does NOT flag the bare `*` (multiplication) operator as ghost" do
    identity = build_method_identity(name: "*", fqn: "Foo#*")
    assert_not ghost_method?(identity),
      "expected `*` (Numeric#*, Array#*, Duration#*, SafeBuffer#*) to be a real method, not a ghost"
  end

  test "does NOT flag the bare `**` (exponentiation/double-splat) operator as ghost" do
    identity = build_method_identity(name: "**", fqn: "Foo#**")
    assert_not ghost_method?(identity),
      "expected `**` to be a real method, not a ghost"
  end

  test "guard clause: non-method identities are never ghosts" do
    identity = build_identity(kind: "constant", name: "FOO", fqn: "Foo::FOO")
    assert_not ghost_method?(identity)
  end

  test "does not flag normal method names" do
    identity = build_method_identity(name: "save", fqn: "Foo#save")
    assert_not ghost_method?(identity)
  end

  private

  def build_method_identity(name:, fqn:, scope: "instance")
    build_identity(kind: "method", name: name, fqn: fqn, scope: scope)
  end

  def build_identity(kind:, name:, fqn:, scope: nil)
    EntityIdentity.new(kind: kind, name: name, fqn: fqn, scope: scope)
  end
end
