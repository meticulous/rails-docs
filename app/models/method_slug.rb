# Maps Ruby method names to URL-safe slugs and back. Used for per-method
# URLs like /v8.1.2/active_record/persistence/save and /v8.1.2/some/place/[]
# becoming /v8.1.2/some/place/bracket.
#
# The encoding is one-way for operators (no `bracket` collision with a real
# method named `bracket`, since Ruby method names can't contain `-`). For
# names with punctuation suffixes, the suffix is replaced: `save?` -> `save-p`.
module MethodSlug
  OPERATOR_ENCODINGS = {
    "[]" => "bracket",
    "[]=" => "bracket-eq",
    "<<" => "lshift",
    ">>" => "rshift",
    "<=>" => "cmp",
    "<=" => "lte",
    ">=" => "gte",
    "<" => "lt",
    ">" => "gt",
    "==" => "eq-eq",
    "===" => "case-eq",
    "=~" => "match",
    "!=" => "not-eq",
    "!~" => "not-match",
    "+" => "plus",
    "-" => "minus",
    "*" => "mul",
    "**" => "pow",
    "/" => "div",
    "%" => "mod",
    "&" => "and",
    "|" => "or",
    "^" => "xor",
    "~" => "tilde",
    "+@" => "uplus",
    "-@" => "uminus",
    "!" => "not",
    "`" => "backtick"
  }.freeze

  OPERATOR_DECODINGS = OPERATOR_ENCODINGS.invert.freeze

  SUFFIX_ENCODINGS = { "?" => "-p", "!" => "-bang", "=" => "-eq" }.freeze
  SUFFIX_DECODINGS = SUFFIX_ENCODINGS.invert.freeze

  module_function

  def encode(name)
    return OPERATOR_ENCODINGS[name] if OPERATOR_ENCODINGS.key?(name)
    if (match = name.match(/\A(\w+)(\?|!|=)\z/))
      "#{match[1]}#{SUFFIX_ENCODINGS[match[2]]}"
    else
      name
    end
  end

  def decode(slug)
    return OPERATOR_DECODINGS[slug] if OPERATOR_DECODINGS.key?(slug)
    if (match = slug.match(/\A(\w+?)(-p|-bang|-eq)\z/))
      "#{match[1]}#{SUFFIX_DECODINGS[match[2]]}"
    else
      slug
    end
  end
end
