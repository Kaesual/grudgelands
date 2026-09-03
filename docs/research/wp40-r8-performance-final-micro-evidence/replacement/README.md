# Corrected replacement pair

This is the accepted replacement interpreter pair for corrected frozen
candidate `cb7467e4294faece8d0823f6d769dddfc51972b7`. It supersedes the
root-level pair after the focused review's constructor-selector finding.

The one replacement invocation ran one LuaJIT process and one PUC 5.1 process
concurrently at idle priority. Both exited with status zero and produced
byte-identical output over 111 immutable inputs while executing all 15 changed
production modules. The fixture additionally removes the R5 and planner
runtime constructors in turn and requires each missing seam to fail closed.

- Receipt SHA-256: `d3d9de965c52ddb5e437bbd499923e44b688e64dfad8b2237a4d863b988a7d61`
- Canonical-output SHA-256: `a7c8be813d0bcf54038b8d19a6149c53a8ab185de98f983555aa3db6b452b7de`
- Internal canonical digest: `14f686f8c7a3deedd812c2877540df205b6dbcfb64d798d6fd6a652cd8c5e18d`
- LuaJIT log SHA-256: `c8f02613cf6410efca555f1ebd67699815c862f0983fa4c2b686480e83f0ada1`
- PUC 5.1 log SHA-256: `b8146a4172852a6ec3f2ad8a6bc9c5b7fabc2f82941cec597d6684cbc47bf8e2`
