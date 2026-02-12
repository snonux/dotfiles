# Increment version and push

Increment the version of the project, tag it in git, commit, and push. For Go-based projects, look for the internal/version.go file. For bug fixes, increment only the minor version. We are using semantic versioning, e.g., x.y.z, where z is the minor version. For new features, increment y. Never increment x (the major version) unless specified.
