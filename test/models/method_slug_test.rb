require "test_helper"

class MethodSlugTest < ActiveSupport::TestCase
  test "encodes and decodes plain names unchanged" do
    %w[save find_by belongs_to attribute_names].each do |name|
      assert_equal name, MethodSlug.encode(name)
      assert_equal name, MethodSlug.decode(name)
    end
  end

  test "encodes punctuation suffixes" do
    assert_equal "save-p", MethodSlug.encode("save?")
    assert_equal "save-bang", MethodSlug.encode("save!")
    assert_equal "name-eq", MethodSlug.encode("name=")
  end

  test "decodes punctuation suffixes" do
    assert_equal "save?", MethodSlug.decode("save-p")
    assert_equal "save!", MethodSlug.decode("save-bang")
    assert_equal "name=", MethodSlug.decode("name-eq")
  end

  test "encodes operator methods" do
    assert_equal "bracket", MethodSlug.encode("[]")
    assert_equal "bracket-eq", MethodSlug.encode("[]=")
    assert_equal "lshift", MethodSlug.encode("<<")
    assert_equal "cmp", MethodSlug.encode("<=>")
    assert_equal "case-eq", MethodSlug.encode("===")
    assert_equal "uminus", MethodSlug.encode("-@")
  end

  test "decodes operator slugs" do
    assert_equal "[]", MethodSlug.decode("bracket")
    assert_equal "[]=", MethodSlug.decode("bracket-eq")
    assert_equal "<<", MethodSlug.decode("lshift")
    assert_equal "<=>", MethodSlug.decode("cmp")
    assert_equal "-@", MethodSlug.decode("uminus")
  end

  test "encode and decode round-trip for representative method names" do
    %w[save save? save! name= [] []= << + - * / ** == != +@ -@].each do |name|
      assert_equal name, MethodSlug.decode(MethodSlug.encode(name)),
                   "round-trip failed for #{name.inspect}"
    end
  end
end
