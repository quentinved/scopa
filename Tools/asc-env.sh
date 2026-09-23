# Sourced by the store tools: the App Store Connect key from the repo's .env, which
# `whisper-secrets pull` writes. Read line by line rather than sourced, since the key's
# path has spaces in it. Anything already exported wins.
if [ -f "$root/.env" ]; then
    while IFS='=' read -r name value; do
        case $name in
            ASC_*) eval "[ -n \"\${$name:-}\" ]" || export "$name=$value" ;;
        esac
    done < "$root/.env"
fi
