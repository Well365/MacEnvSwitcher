#!/bin/bash

echo "=== Environment Diagnosis ==="
echo "Date: $(date)"
echo

echo "=== Shell Information ==="
echo "Current Shell: $SHELL"
echo "ZDOTDIR: $ZDOTDIR"
echo

echo "=== Ruby Environment ==="
echo "Ruby Version: $(ruby -v 2>/dev/null || echo 'Ruby not found')"
echo "Ruby Path: $(which ruby 2>/dev/null || echo 'Ruby not found')"
echo

echo "=== Version Managers ==="
echo "asdf installed: $(which asdf 2>/dev/null || echo 'Not found')"
echo "asdf version: $(asdf version 2>/dev/null || echo 'Not available')"
echo "rbenv installed: $(which rbenv 2>/dev/null || echo 'Not found')"
echo "rbenv version: $(rbenv version 2>/dev/null || echo 'Not available')"
echo

echo "=== PATH Analysis ==="
echo "PATH: $PATH"
echo
echo "PATH components containing ruby/asdf/rbenv:"
echo "$PATH" | tr ':' '\n' | grep -E '(ruby|asdf|rbenv|\.gem)' | sort -u
echo

echo "=== ASDF Configuration ==="
echo "ASDF_DIR: ${ASDF_DIR:-'Not set'}"
echo "ASDF plugins:"
asdf plugin list 2>/dev/null || echo "asdf not working properly"
echo
echo "ASDF current versions:"
asdf current 2>/dev/null || echo "asdf current command failed"
echo

echo "=== Shell Configuration ==="
echo "Checking .zshrc for version managers..."
if [ -f ~/.zshrc ]; then
    echo "Ruby-related lines in .zshrc:"
    grep -n -E '(asdf|rbenv|ruby)' ~/.zshrc 2>/dev/null || echo "No ruby-related configuration found"
else
    echo ".zshrc not found"
fi
echo

echo "=== MacEnvSwitcher Environment ==="
echo "MacEnvSwitcher active profile:"
echo "Check your app for current profile settings"
echo