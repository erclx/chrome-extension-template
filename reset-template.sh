#!/bin/bash

# Template reset script for CRXJS Chrome extension projects
# Usage: bun reset <project-name>

if [ -z "$1" ]; then
  echo "Error: No project name specified."
  echo "Usage: bun reset <project-name>"
  exit 1
fi

PROJECT_NAME=$1
PROJECT_TITLE=$(echo "$PROJECT_NAME" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')

echo "Resetting template for project: $PROJECT_NAME"

# Clean build artifacts and dependencies
echo "Cleaning build artifacts..."
rm -rf dist dist-ssr node_modules release .continue
rm -f bun.lock *.log

# Clean editor configurations (preserve VSCode settings)
rm -rf .idea
rm -f .DS_Store
if [ -d ".vscode" ]; then
  find .vscode -type f ! -name 'extensions.json' ! -name 'settings.json' -delete
fi

# Reset version control
echo "Resetting Git repository..."
rm -rf .git .github
git init -b main > /dev/null 2>&1

# Reset project documentation
echo "Resetting README..."
cat > README.md << EOF
# $PROJECT_TITLE

A Chrome extension built with React, TypeScript, and CRXJS.
EOF

# Update package.json metadata
if [ -f "package.json" ]; then
  echo "Updating package.json..."
  TMP_FILE=$(mktemp)
  sed "s/\"name\": \"[^\"]*\"/\"name\": \"$PROJECT_NAME\"/" package.json > "$TMP_FILE"
  sed "s/\"version\": \"[^\"]*\"/\"version\": \"0.1.0\"/" "$TMP_FILE" > package.json
  rm "$TMP_FILE"
fi

# Update manifest configuration
if [ -f "manifest.config.ts" ]; then
  echo "Updating manifest.config.ts..."
  TMP_FILE=$(mktemp)
  sed "s/name: pkg\.name,/name: '$PROJECT_TITLE',/" manifest.config.ts > "$TMP_FILE"
  mv "$TMP_FILE" manifest.config.ts
fi

# Install dependencies
echo "Installing dependencies..."
bun install

# Create initial commit
echo "Creating initial commit..."
git add .
git commit -m "chore: initial commit" --no-verify > /dev/null 2>&1

echo ""
echo "Done! Project $PROJECT_NAME is ready."
echo "Run 'bun dev' to start development."