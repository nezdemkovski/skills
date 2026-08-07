#!/usr/bin/env bash
set -euo pipefail

if (( $# < 1 )); then
  echo "usage: $0 <gitops-repo> [application ...]" >&2
  exit 64
fi

gitops_repo=$1
shift

kubeconfig_file=${KUBECONFIG:-"${gitops_repo}/kubeconfig"}
if [[ ! -f "$kubeconfig_file" ]]; then
  echo "kubeconfig not found: $kubeconfig_file" >&2
  exit 66
fi

applications=("$@")
if (( ${#applications[@]} == 0 )); then
  applications=(homelab-root)
fi

for dependency in ruby jq curl mktemp; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "missing dependency: $dependency" >&2
    exit 69
  fi
done
ruby_bin=$(command -v ruby)
jq_bin=$(command -v jq)
curl_bin=$(command -v curl)
mktemp_bin=$(command -v mktemp)

credential_dir=$("$mktemp_bin" -d "${TMPDIR:-/tmp}/homelab-argo-status.XXXXXX")
cleanup() {
  /bin/rm -rf -- "$credential_dir"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
/bin/chmod 700 "$credential_dir"

kube_server=$(
  "$ruby_bin" -ryaml -rbase64 -e '
    config = YAML.load_file(ARGV[0])
    context_name = config.fetch("current-context")
    context = config.fetch("contexts").find { |entry| entry.fetch("name") == context_name }.fetch("context")
    cluster = config.fetch("clusters").find { |entry| entry.fetch("name") == context.fetch("cluster") }.fetch("cluster")
    user = config.fetch("users").find { |entry| entry.fetch("name") == context.fetch("user") }.fetch("user")

    required = {
      "certificate-authority-data" => ARGV[1],
      "client-certificate-data" => ARGV[2],
      "client-key-data" => ARGV[3]
    }
    required.each do |field, destination|
      value = field.start_with?("client-") ? user[field] : cluster[field]
      abort "kubeconfig field missing: #{field}" unless value
      File.binwrite(destination, Base64.decode64(value))
    end
    STDOUT.write(cluster.fetch("server"))
  ' "$kubeconfig_file" \
    "$credential_dir/ca.crt" \
    "$credential_dir/client.crt" \
    "$credential_dir/client.key"
)
/bin/chmod 600 "$credential_dir/ca.crt" "$credential_dir/client.crt" "$credential_dir/client.key"

for application_name in "${applications[@]}"; do
  "$curl_bin" -sS -f \
    --cacert "$credential_dir/ca.crt" \
    --cert "$credential_dir/client.crt" \
    --key "$credential_dir/client.key" \
    "${kube_server}/apis/argoproj.io/v1alpha1/namespaces/argocd/applications/${application_name}" |
    "$jq_bin" -r --arg application "$application_name" \
      '[$application, .status.sync.status, .status.health.status, .status.sync.revision] | @tsv'
done
