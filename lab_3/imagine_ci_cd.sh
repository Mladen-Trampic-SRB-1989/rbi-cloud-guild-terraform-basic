#/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd ${DIR}/..

echo "Initializing Terraform"
docker run --rm -it -v ${PWD}/.creds:/terraform/.creds -v ${PWD}/lab_3:/terraform -w=/terraform --user "$(id -u):$(id -g)" hashicorp/terraform:0.12.28 init -backend-config /terraform/root_module_state.tfvars.json

echo "Calculating Terraform Plan"
docker run --rm -it -v ${PWD}/.creds:/terraform/.creds -v ${PWD}/lab_3:/terraform -w=/terraform --user "$(id -u):$(id -g)" hashicorp/terraform:0.12.28 plan -var-file /terraform/root_module.tfvars.json -out /terraform/plan_output/tfplan.binary
docker run --rm -it -v ${PWD}/.creds:/terraform/.creds -v ${PWD}/lab_3:/terraform -w=/terraform  --user "$(id -u):$(id -g)" hashicorp/terraform:0.12.28 show -json /terraform/plan_output/tfplan.binary | jq . | jq .  > lab_3/plan_output/tfplan.json

echo "Trying to compare with OPA policy and execute auto deployment"
OPA_STATUS="$(docker run --rm -it -v ${PWD}/lab_3:/open_policy_agent -w=/open_policy_agent openpolicyagent/opa eval --format pretty --data opa_rules/terraform.rego --input plan_output/tfplan.json 'data.terraform.analysis.authz')"
if [[ "$OPA_STATUS" = *"true"* ]]
then
echo "Compliant with rules, proceeding with Deploy"
docker run --rm -it -v ${PWD}/.creds:/terraform/.creds -v ${PWD}/lab_3:/terraform -w=/terraform --user "$(id -u):$(id -g)" hashicorp/terraform:0.12.28 apply -var-file /terraform/root_module.tfvars.json -auto-approve
else
echo "Non Compliant with rules, aborting Deploy"
fi