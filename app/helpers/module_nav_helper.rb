module ModuleNavHelper
  # Builds a namespace forest from a flat list of FQNs. Returns an
  # ordered array of nodes: { name:, fqn:, real:, children: [...] }.
  # Intermediate namespace segments that aren't themselves documented
  # entities get real: false (rendered as plain labels, not links) —
  # rare in Rails, but possible.
  def fqn_forest(fqns)
    real = fqns.to_set
    root = {}
    fqns.each do |fqn|
      children = root
      parts = fqn.split("::")
      parts.each_with_index do |part, i|
        full = parts[0..i].join("::")
        node = (children[part] ||= { name: part, fqn: full, real: real.include?(full), children: {} })
        children = node[:children]
      end
    end
    sort_forest(root)
  end

  # Recursively render a forest (array of nodes) as nested <li>s. Built
  # in a helper rather than a per-node partial so a cache miss doesn't
  # pay 1,500 partial renders; the whole nav is fragment-cached anyway.
  def module_nav_tree(nodes, version_segment, depth: 0)
    return "".html_safe if nodes.empty?

    safe_join(nodes.map { |node| module_nav_node(node, version_segment, depth) })
  end

  private

  def sort_forest(hash)
    hash.values.sort_by { |n| n[:name] }.map do |node|
      node.merge(children: sort_forest(node[:children]))
    end
  end

  def module_nav_node(node, version_segment, depth)
    has_children = node[:children].any?

    label =
      if node[:real]
        link_to node[:name],
                entity_path(version: version_segment, path: EntityIdentity.fqn_to_url_path(node[:fqn])),
                class: "module-nav__link", title: node[:fqn]
      else
        tag.span(node[:name], class: "module-nav__link module-nav__link--namespace", title: node[:fqn])
      end

    toggle =
      if has_children
        tag.button("",
                   type: "button",
                   class: "module-nav__toggle",
                   "data-action": "module-nav#toggleNode",
                   "aria-expanded": "false",
                   "aria-label": "Toggle #{node[:name]}")
      else
        tag.span("", class: "module-nav__toggle-spacer")
      end

    row = tag.div(toggle + label, class: "module-nav__row", style: "--depth:#{depth}")

    children =
      if has_children
        tag.ul(module_nav_tree(node[:children], version_segment, depth: depth + 1),
               class: "module-nav__children", hidden: true)
      else
        "".html_safe
      end

    tag.li(row + children, class: "module-nav__node", "data-fqn": node[:fqn].downcase)
  end
end
