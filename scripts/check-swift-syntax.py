"""Grammar check only; does not typecheck Swift or substitute for Xcode."""
from pathlib import Path
from tree_sitter import Language, Parser
import tree_sitter_swift
root = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))
paths = sorted(p for folder in ['BAR','BARCore','Tests','BARUITests'] for p in (root/folder).rglob('*.swift'))
errors = []
for path in paths:
    tree = parser.parse(path.read_bytes())
    if tree.root_node.has_error:
        def walk(node):
            if node.type == 'ERROR' or node.is_missing:
                errors.append(f'{path.relative_to(root)}:{node.start_point.row+1}: {node.type}')
            for child in node.children:
                walk(child)
        walk(tree.root_node)
print(f'{len(paths)} Swift files parsed; {len(errors)} grammar errors. Not compilation or test execution.')
for error in errors:
    print(error)
raise SystemExit(bool(errors))
