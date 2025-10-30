extract_app_go_version() {
  local cmd="$1"
  local src src_dir mod_dir go_version

  echo "Command => $cmd"

  # Extract the last argument (could be .go file or dir)
  src=$(echo "$cmd" | awk '{print $NF}')

  if [[ "$src" == *.go ]]; then
    src_dir=$(dirname "$src")
  else
    src_dir="$src"
  fi

  # Normalize path
  src_dir="$(cd "$src_dir" 2>/dev/null && pwd -P || echo "$src_dir")"

  echo "Source Directory => $src_dir"

  # Find nearest go.mod upwards
  mod_dir=$(cd "$src_dir" && \
    while [[ "$PWD" != "/" ]]; do
      if [[ -f go.mod ]]; then
        echo "$PWD"
        exit 0
      fi
      cd ..
    done)

  if [[ -z "$mod_dir" ]]; then
    return 1
  fi

  go_version=$((grep '^toolchain ' "$mod_dir/go.mod" || grep '^go ' "$mod_dir/go.mod") | awk '{print $2}' | sed 's/go//')
   
  echo "$go_version"
}