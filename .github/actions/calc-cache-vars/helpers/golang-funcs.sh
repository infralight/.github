# // Find the nearest go.mod directory from the given app name
#
find_nearest_go_mod_dir() {
  local app_name="$1"
  local app_make_command=$(make --dry-run ci-build-$app_name 2>/dev/null | grep "go build" | sed 's/[()]//g' | tail -n 1 || echo)
  local src src_dir mod_dir go_version

  # Extract the last argument (could be .go file or dir)
  src=$(echo "$app_make_command" | awk '{print $NF}')
  if [[ "$src" == *.go ]]; then
    src_dir=$(dirname "$src")
  else
    src_dir="$src"
  fi

  # Normalize path
  src_dir="$(cd "$src_dir" 2>/dev/null && pwd -P || echo "$src_dir")"

  # Find nearest go.mod upwards
  mod_dir=$(cd "$src_dir" && \
    while [[ "$PWD" != "/" ]]; do
      if [[ -f go.mod ]]; then
        echo "$PWD"
        exit 0
      fi
      cd ..
    done)

  echo "$mod_dir"
}

extract_app_go_version() {
  local app_name="$1"
  local mod_dir=$(find_nearest_go_mod_dir "$app_name" 2>/dev/null)

  if [[ -z "$mod_dir" ]]; then
    echo "Error: Could not find go.mod for app '$app_name'" >&2
    exit 1
  fi
  
  go_version=$((grep '^toolchain ' "$mod_dir/go.mod" || grep '^go ' "$mod_dir/go.mod") | awk '{print $2}' | sed 's/go//')
  echo "$go_version"
}