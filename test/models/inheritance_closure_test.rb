require "test_helper"

class InheritanceClosureTest < ActiveSupport::TestCase
  test "persists an entry" do
    closure = InheritanceClosure.new(
      package_version: package_versions(:v8_1_3),
      descendant_identity: entity_identities(:ar_base),
      ancestor_identity: entity_identities(:ar_persistence),
      depth: 1,
      via_relation: "include"
    )
    assert closure.save
  end
end
