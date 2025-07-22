#!/usr/bin/env bash
set -Eeuo pipefail

project_domain=iam-demo.test
check_hostnames_on_port=(
  'Kubernetes-Control-Plane iam-control-plane 6443'
  'Forgejo git 443'
  'Grafana grafana 443'
  'Loki loki 443'
  'Prometheus prometheus 443'
  'Alertmanager alertmanager 443'
  'Consul consul 443'
  'Keycloak keycloak 443'
  'Keycloak-Admin keycloak-admin 443'
  'Hashicorp-Vault vault 443'
  'MinIO-S3-API s3 443'
  'Minio-Web-Console minio 443'
  'Mailpit mail 443'
  'midPoint midpoint 443'
  'Terrakube-API terrakube-api 443'
  'Terrakube-Registry terrakube-reg 443'
  'Terrakube-UI terrakube-ui 443'
)

bold_text=$(tput bold)
bad_result_text=$(tput setaf 1)
good_result_text=$(tput setaf 2)
highlight_text=$(tput setaf 3)
info_text=$(tput setaf 4)
reset_text=$(tput sgr0)
echo "Check DNS entries and Certificates for ${bold_text}${highlight_text}${project_domain}${reset_text}"
for name_hostname_port in "${check_hostnames_on_port[@]}"; do
  tmp_splitted_line=($name_hostname_port)
  service_name=${tmp_splitted_line[0]}
  fqdn_to_check=${tmp_splitted_line[1]}.${project_domain}
  port_to_check=${tmp_splitted_line[2]}

  echo "Check ${info_text}${service_name}${reset_text} DNS resolution"
  _cmd_output=$(host -t a iam-control-plane.iam-demo.test | grep -F "has address" 2>&1) &&
    exit_status=$? || exit_status=$?
  if [ "${exit_status}" -ne "0" ]; then
    echo " ${bold_text}${bad_result_text}[Error]${reset_text}"
    echo "   ${highlight_text}Can not resolve DNS for${reset_text} '${bold_text}${fqdn_to_check}${reset_text}'"
    echo "   '${bad_result_text}${_cmd_output}${reset_text}'"
  else
    echo " ${bold_text}${good_result_text}[DNS OK]${reset_text}"
    echo "   '${good_result_text}${_cmd_output}${reset_text}'"
  fi

  echo "Check ${info_text}${service_name}${reset_text} on ${info_text}${bold_text}${fqdn_to_check}:${port_to_check}${reset_text}"
  openssl_connect_output=$(echo | openssl s_client -showcerts -servername ${fqdn_to_check} \
    -connect "${fqdn_to_check}:${port_to_check}" 2>&1) &&
    exit_status=$? || exit_status=$?
  if [ "${exit_status}" -ne "0" ]; then
    echo " ${bold_text}${bad_result_text}[Error]${reset_text}"
    echo "   ${highlight_text}Can not check certificate for${reset_text} '${bold_text}${fqdn_to_check}:${port_to_check}${reset_text}'"
    if [[ $openssl_connect_output =~ "No client certificate CA names sent" ]]; then
      echo "   ${bad_result_text}Most likely reason: ${bold_text}no TLS setup on the endpoint${reset_text}"
    elif [[ $openssl_connect_output =~ "Name or service not known" ]]; then
      echo "   ${bad_result_text}Most likely reason: ${bold_text}DNS resolution error${reset_text}"
    elif [[ $openssl_connect_output =~ "Connection refused" ]]; then
      echo "   ${bad_result_text}Most likely reason: ${bold_text}wrong port number${reset_text}"
    else
      echo "   ${bad_result_text}${bold_text}Unknown error${reset_text}'"
    fi
    echo "   ${bold_text}------> Begin output result for ${reset_text}'${highlight_text}${service_name}${reset_text}'"
    echo "${openssl_connect_output}"
    echo "   ${bold_text}<------ End output result for ${reset_text}'${highlight_text}${service_name}${reset_text}'"
  else
    openssl_check_output=$(echo "${openssl_connect_output}" |
      openssl x509 -inform pem -noout -nocert -checkhost ${fqdn_to_check} 2>/dev/null) &&
      exit_status=$? || exit_status=$?
    if [[ $openssl_check_output =~ "does match certificate" ]]; then
      echo " ${bold_text}${good_result_text}[OK]${reset_text}"
      echo "   Valid certificate for '${good_result_text}${fqdn_to_check}${reset_text}' on port '${good_result_text}${port_to_check}${reset_text}'"
    else
      echo " ${bold_text}${bad_result_text}[Error]${reset_text}"
      echo " ${highlight_text}Certificate for${reset_text} '${bold_text}${fqdn_to_check}:${port_to_check}${reset_text}' ${highlight_text}not valid${reset_text}"
      echo "   '${bad_result_text}${openssl_check_output}${reset_text}'"
    fi
  fi
done
